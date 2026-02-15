// Diary builder: clusters location pings into visits with confidence classification

import { serve } from "std/http/server.ts"
import { createClient } from "supabase"

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface PositionFromHome {
  distance: number; // metres from home
  bearing: number;  // degrees (0-360)
  x_m?: number;     // east-west offset from home in metres (flat-earth)
  y_m?: number;     // north-south offset from home in metres (flat-earth)
}

interface MotionType {
  motion: string;     // walking | cycling | automotive | still | unknown
  confidence: string; // low | medium | high | unknown
}

interface RawPing {
  entryid: string;
  created_at: string;
  primary_type: string;
  other_types: string[];
  motion_type: MotionType;
  position_from_home: PositionFromHome;
  horizontal_accuracy: number | null;
}

type VisitType = "confirmed_visit" | "visit" | "brief_stop" | "traffic_stop";

interface ClusterResult {
  entryid: string;
  entry_ids: string[];
  created_at: string;
  ended_at: string;
  cluster_duration_s: number;
  primary_type: string;
  other_types: string[];
  motion_type: MotionType;
  visit_confidence: "high" | "medium" | "low";
  visit_type: VisitType;
  ping_count: number;
}

interface JourneyResult {
  journey_id: string;       // first ping's entryid
  entry_ids: string[];
  from_visit_id: string | null;
  to_visit_id: string | null;
  primary_transport: string;
  transport_proportions: Record<string, number>;
  started_at: string;
  ended_at: string;
  journey_duration_s: number;
  ping_count: number;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Distance between two points given as offsets from a shared origin (home).
 *  Prefers numerically stable Euclidean distance on Cartesian (x_m, y_m) offsets.
 *  Falls back to the law of cosines on polar coords for legacy pings. */
function distanceBetween(a: PositionFromHome, b: PositionFromHome): number {
  // Prefer Cartesian when both points have offsets
  if (a.x_m != null && a.y_m != null && b.x_m != null && b.y_m != null) {
    const dx = a.x_m - b.x_m;
    const dy = a.y_m - b.y_m;
    return Math.sqrt(dx * dx + dy * dy);
  }
  // Fallback: law of cosines on polar coordinates
  const dθ = (b.bearing - a.bearing) * Math.PI / 180;
  const d2 = a.distance ** 2 + b.distance ** 2 -
             2 * a.distance * b.distance * Math.cos(dθ);
  return Math.sqrt(Math.max(0, d2)); // guard against tiny negatives from fp
}

/** True when motion confidence is at least "medium". */
function isMediumPlusConfidence(confidence: string): boolean {
  return confidence === "medium" || confidence === "high";
}

/** Classify one consecutive-ping pair into a confidence level. */
function pairConfidence(dist: number, prevMotion: MotionType, currMotion: MotionType): "high" | "medium" | "low" {
  const sameMotion = currMotion.motion === prevMotion.motion;
  const isStillOrWalking = currMotion.motion === "still" || currMotion.motion === "walking";
  const favorablePath = sameMotion || (isStillOrWalking && isMediumPlusConfidence(currMotion.confidence));

  if (favorablePath) {
    if (dist <= 25) return "high";
    if (dist <= 50) return "medium";
    return "low";
  } else {
    // Different motion type
    if (dist <= 50) return "medium";
    return "low";
  }
}

/** Return the most common element in an array (mode). Falls back to first element. */
function mode<T>(arr: T[]): T {
  const counts = new Map<string, number>();
  for (const v of arr) {
    const key = String(v);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  let best = arr[0];
  let bestCount = 0;
  for (const v of arr) {
    const c = counts.get(String(v))!;
    if (c > bestCount) { bestCount = c; best = v; }
  }
  return best;
}

/** Compute cluster-level confidence and visit type using a weighted multi-signal score.
 *
 *  Signals:
 *    1. Pair-wise spatial confidence (weighted average of high/medium/low pairs)
 *    2. GPS accuracy quality (average horizontal_accuracy of pings)
 *    3. Ping count (more data points = more trustworthy)
 *    4. Motion type distribution (still/walking boost, automotive penalty)
 *
 *  The first three signals are combined additively into a base composite.
 *  The motion distribution acts as a multiplicative modifier and determines visit_type.
 */
function computeClusterConfidence(pingsInCluster: RawPing[]): {
  visit_confidence: "high" | "medium" | "low";
  visit_type: VisitType;
} {
  // ----- Signal 1: Pair-wise spatial confidence (weighted average) -----
  let pairScore: number;

  if (pingsInCluster.length < 2) {
    // Single ping — no consecutive pairs to evaluate, pessimistic default
    pairScore = 0.33;
  } else {
    let highCount = 0, medCount = 0, lowCount = 0;
    for (let i = 1; i < pingsInCluster.length; i++) {
      const dist = distanceBetween(
        pingsInCluster[i - 1].position_from_home,
        pingsInCluster[i].position_from_home,
      );
      const pc = pairConfidence(
        dist,
        pingsInCluster[i - 1].motion_type,
        pingsInCluster[i].motion_type,
      );
      if (pc === "high") highCount++;
      else if (pc === "medium") medCount++;
      else lowCount++;
    }
    const totalPairs = highCount + medCount + lowCount;
    // Weighted average: high=3, medium=2, low=1, normalised to [0,1]
    pairScore = (3 * highCount + 2 * medCount + lowCount) / (3 * totalPairs);
  }

  // ----- Signal 2: GPS accuracy quality (lower metres = better) -----
  const accuracies = pingsInCluster
    .map(p => p.horizontal_accuracy)
    .filter((a): a is number => a != null);

  let accuracyFactor: number;
  if (accuracies.length === 0) {
    accuracyFactor = 0.7; // no accuracy data — neutral-conservative
  } else {
    const avgAccuracy = accuracies.reduce((s, a) => s + a, 0) / accuracies.length;
    if (avgAccuracy <= 10) accuracyFactor = 1.0;
    else if (avgAccuracy <= 30) accuracyFactor = 0.9;
    else if (avgAccuracy <= 65) accuracyFactor = 0.75;
    else accuracyFactor = 0.5;
  }

  // ----- Signal 3: Ping count (more data = more trustworthy) -----
  const count = pingsInCluster.length;
  let pingCountFactor: number;
  if (count === 1) pingCountFactor = 0.3;
  else if (count <= 3) pingCountFactor = 0.65;
  else if (count <= 6) pingCountFactor = 0.85;
  else pingCountFactor = 1.0;

  // ----- Signal 4: Motion type distribution -----
  const motionCounts: Record<string, number> = {};
  for (const p of pingsInCluster) {
    const m = p.motion_type.motion.toLowerCase();
    motionCounts[m] = (motionCounts[m] ?? 0) + 1;
  }
  const total = pingsInCluster.length;
  const stillWalkingProp =
    ((motionCounts["still"] ?? 0) + (motionCounts["walking"] ?? 0)) / total;
  const automotiveProp = (motionCounts["automotive"] ?? 0) / total;

  let motionMultiplier = 1.0;
  let visitType: VisitType = "visit";

  if (stillWalkingProp >= 0.7) {
    // Stationary-dominant cluster — strong indicator of a real visit
    motionMultiplier = 1.15;
    visitType = "confirmed_visit";
  } else if (automotiveProp >= 0.5) {
    // Automotive-dominant — likely a traffic stop, not a genuine visit
    motionMultiplier = 0.6;
    visitType = "traffic_stop";
  }

  // ----- Composite score -----
  // Pair confidence is the primary signal (55%); accuracy (25%) and ping count (20%) modulate
  const baseComposite =
    pairScore       * 0.55 +
    accuracyFactor  * 0.25 +
    pingCountFactor * 0.20;

  // Motion distribution acts as a multiplicative modifier
  const finalScore = Math.min(1.0, baseComposite * motionMultiplier);

  // Threshold into confidence bands
  let visit_confidence: "high" | "medium" | "low";
  if (finalScore >= 0.80) visit_confidence = "high";
  else if (finalScore >= 0.55) visit_confidence = "medium";
  else visit_confidence = "low";

  return { visit_confidence, visit_type: visitType };
}

/** Duration in whole seconds between two ISO timestamps. */
function durationSeconds(startISO: string, endISO: string): number {
  return Math.max(0, Math.round((new Date(endISO).getTime() - new Date(startISO).getTime()) / 1000));
}

// ---------------------------------------------------------------------------
// Clustering (centroid-anchored)
// ---------------------------------------------------------------------------

const CLUSTER_RADIUS_M = 75; // max distance from centroid to remain in cluster

/** Compute the centroid of a set of pings' positions as an average PositionFromHome.
 *  Averages Cartesian offsets (x_m, y_m) when available; falls back to polar averaging. */
function clusterCentroid(pings: RawPing[]): PositionFromHome {
  // Prefer Cartesian offsets for numerically stable averaging
  if (pings[0].position_from_home.x_m != null && pings[0].position_from_home.y_m != null) {
    let sx = 0, sy = 0;
    for (const p of pings) {
      sx += p.position_from_home.x_m!;
      sy += p.position_from_home.y_m!;
    }
    const cx = sx / pings.length;
    const cy = sy / pings.length;
    const dist = Math.sqrt(cx * cx + cy * cy);
    const bear = (Math.atan2(cx, cy) * 180 / Math.PI + 360) % 360;
    return { distance: dist, bearing: bear, x_m: cx, y_m: cy };
  }
  // Fallback: convert polar to local Cartesian, average, convert back
  let sx = 0, sy = 0;
  for (const p of pings) {
    const b = p.position_from_home.bearing * Math.PI / 180;
    sx += p.position_from_home.distance * Math.sin(b);
    sy += p.position_from_home.distance * Math.cos(b);
  }
  const cx = sx / pings.length;
  const cy = sy / pings.length;
  const dist = Math.sqrt(cx * cx + cy * cy);
  const bear = (Math.atan2(cx, cy) * 180 / Math.PI + 360) % 360;
  return { distance: dist, bearing: bear };
}

function clusterPings(pings: RawPing[]): ClusterResult[] {
  if (pings.length === 0) return [];

  const clusters: RawPing[][] = [];
  let current: RawPing[] = [pings[0]];
  let centroid: PositionFromHome = pings[0].position_from_home;

  for (let i = 1; i < pings.length; i++) {
    const curr = pings[i];
    const dist = distanceBetween(centroid, curr.position_from_home);

    if (dist <= CLUSTER_RADIUS_M) {
      current.push(curr);
      // Update running centroid to include the new ping
      centroid = clusterCentroid(current);
    } else {
      clusters.push(current);
      current = [curr];
      centroid = curr.position_from_home;
    }
  }
  clusters.push(current); // finalise last cluster

  // Build representative entries
  return clusters.map((pingsInCluster) => {
    // Multi-signal confidence scoring (replaces old min-based approach)
    const { visit_confidence, visit_type } = computeClusterConfidence(pingsInCluster);

    // Representative fields
    const firstPing = pingsInCluster[0];
    const lastPing = pingsInCluster[pingsInCluster.length - 1];

    const primaryTypes = pingsInCluster.map(p => p.primary_type);
    const motionTypes = pingsInCluster.map(p => p.motion_type);

    // Union of all other_types (deduplicated)
    const allOtherTypes = [...new Set(pingsInCluster.flatMap(p => p.other_types))];

    // Most common motion_type (compare by serialised JSON key)
    const motionMode = mode(motionTypes.map(m => JSON.stringify(m)));

    return {
      entryid: firstPing.entryid,
      entry_ids: pingsInCluster.map(p => p.entryid),
      created_at: firstPing.created_at,
      ended_at: lastPing.created_at,
      cluster_duration_s: durationSeconds(firstPing.created_at, lastPing.created_at),
      primary_type: mode(primaryTypes),
      other_types: allOtherTypes,
      motion_type: JSON.parse(motionMode) as MotionType,
      visit_confidence,
      visit_type,
      ping_count: pingsInCluster.length,
    };
  });
}

// ---------------------------------------------------------------------------
// Selection: enforce minimum dwell time, then all high + up to 10 medium/low
// ---------------------------------------------------------------------------

/** Minimum seconds a cluster must span to qualify as a full visit.
 *  Clusters shorter than this are capped at "low" confidence (transient stops). */
const MIN_DWELL_SECONDS = 300; // 5 minutes

function selectClusters(clusters: ClusterResult[]): ClusterResult[] {
  // Downgrade clusters that are too brief to be real visits
  for (const c of clusters) {
    if (c.cluster_duration_s < MIN_DWELL_SECONDS) {
      c.visit_confidence = "low";
      c.visit_type = "brief_stop";
    }
  }

  const high   = clusters.filter(c => c.visit_confidence === "high");
  const medium = clusters.filter(c => c.visit_confidence === "medium");
  const low    = clusters.filter(c => c.visit_confidence === "low");

  const MAX_NON_HIGH = 10;
  let selectedNonHigh: ClusterResult[] = [];

  if (medium.length + low.length <= MAX_NON_HIGH) {
    // Everything fits
    selectedNonHigh = [...medium, ...low];
  } else {
    // Guarantee at least 1 low if it exists
    const reservedLow  = low.length > 0 ? 1 : 0;
    // Guarantee at least 1 medium if it exists
    const reservedMed  = medium.length > 0 ? 1 : 0;

    const slotsForMedium = Math.min(medium.length, MAX_NON_HIGH - reservedLow);
    const slotsForLow    = MAX_NON_HIGH - slotsForMedium;

    const pickedMedium = medium.slice(0, Math.max(slotsForMedium, reservedMed));
    const pickedLow    = low.slice(0, Math.max(slotsForLow, reservedLow));

    // If we overshot, trim from the lower-priority tier (low first)
    selectedNonHigh = [...pickedMedium, ...pickedLow];
    if (selectedNonHigh.length > MAX_NON_HIGH) {
      // Trim excess low entries
      const excess = selectedNonHigh.length - MAX_NON_HIGH;
      selectedNonHigh = [...pickedMedium, ...pickedLow.slice(0, pickedLow.length - excess)];
    }
  }

  // Merge and sort chronologically
  const result = [...high, ...selectedNonHigh];
  result.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
  return result;
}

// ---------------------------------------------------------------------------
// Journey segmentation: split pings between high-confidence visits by transport
// ---------------------------------------------------------------------------

/** Active transport modes (exclude "still" and "unknown" which get absorbed). */
const ACTIVE_MODES = new Set(["walking", "running", "cycling", "automotive"]);

/** Normalise motion string to lowercase for consistent comparison. */
function normaliseMotion(m: string): string {
  return m.toLowerCase();
}

/**
 * Segment pings between consecutive high-confidence visits into journeys.
 * Each journey is a contiguous run of pings sharing the same active transport mode.
 * "still"/"unknown" pings are absorbed into the preceding active segment.
 */
function segmentJourneys(
  allPings: RawPing[],
  selectedVisits: ClusterResult[],
): JourneyResult[] {
  // 1. Identify high-confidence visits in chronological order
  const highVisits = selectedVisits
    .filter(v => v.visit_confidence === "high")
    .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());

  if (highVisits.length < 2) return []; // need at least two anchors

  const journeys: JourneyResult[] = [];

  // 2. For each consecutive pair of high-confidence visits, extract gap pings
  for (let vi = 0; vi < highVisits.length - 1; vi++) {
    const vA = highVisits[vi];
    const vB = highVisits[vi + 1];

    const gapStart = new Date(vA.ended_at).getTime();
    const gapEnd   = new Date(vB.created_at).getTime();

    if (gapEnd <= gapStart) continue; // overlapping or zero-width gap

    // Collect pings strictly between the two visits
    const gapPings = allPings.filter(p => {
      const t = new Date(p.created_at).getTime();
      return t >= gapStart && t <= gapEnd;
    });

    if (gapPings.length === 0) continue;

    // 3. Segment by active transport mode changes
    const segments: RawPing[][] = [];
    let currentSegment: RawPing[] = [];
    let currentMode: string | null = null;

    for (const ping of gapPings) {
      const motion = normaliseMotion(ping.motion_type.motion);

      if (ACTIVE_MODES.has(motion)) {
        if (motion === currentMode) {
          // Same active mode — extend segment
          currentSegment.push(ping);
        } else {
          // Different active mode — start new segment
          if (currentSegment.length > 0) {
            segments.push(currentSegment);
          }
          currentSegment = [ping];
          currentMode = motion;
        }
      } else {
        // "still" or "unknown" — absorb into current segment if one exists
        if (currentSegment.length > 0) {
          currentSegment.push(ping);
        }
        // If no active segment started yet, skip this ping
      }
    }
    // Flush last segment
    if (currentSegment.length > 0) {
      segments.push(currentSegment);
    }

    // 4. Build JourneyResult for each segment
    for (const seg of segments) {
      // Count motion types for proportions
      const motionCounts: Record<string, number> = {};
      for (const p of seg) {
        const m = normaliseMotion(p.motion_type.motion);
        motionCounts[m] = (motionCounts[m] ?? 0) + 1;
      }

      // Compute proportions (rounded to 2 decimals)
      const total = seg.length;
      const proportions: Record<string, number> = {};
      for (const [m, count] of Object.entries(motionCounts)) {
        proportions[m] = Math.round((count / total) * 100) / 100;
      }

      // Primary transport = active mode with highest count
      let primaryTransport = "unknown";
      let bestCount = 0;
      for (const [m, count] of Object.entries(motionCounts)) {
        if (ACTIVE_MODES.has(m) && count > bestCount) {
          bestCount = count;
          primaryTransport = m;
        }
      }

      const first = seg[0];
      const last  = seg[seg.length - 1];

      journeys.push({
        journey_id: first.entryid,
        entry_ids: seg.map(p => p.entryid),
        from_visit_id: vA.entryid,
        to_visit_id: vB.entryid,
        primary_transport: primaryTransport,
        transport_proportions: proportions,
        started_at: first.created_at,
        ended_at: last.created_at,
        journey_duration_s: durationSeconds(first.created_at, last.created_at),
        ping_count: seg.length,
      });
    }
  }

  return journeys;
}

// ---------------------------------------------------------------------------
// Edge Function
// ---------------------------------------------------------------------------

serve(async (req) => {
  // 1. Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  try {
    // 2. Validate Request Body
    const body = await req.json().catch(() => null);
    if (!body) {
      return new Response(JSON.stringify({ error: "Missing JSON body" }), { status: 400 });
    }

    const { deviceId, date } = body;
    if (!deviceId || !date) {
      return new Response(JSON.stringify({ error: "Missing deviceId or date" }), { status: 400 });
    }

    // 3. Initialize Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseKey) {
      console.error("Missing Environment Variables");
      return new Response(JSON.stringify({ error: "Server configuration error" }), { status: 500 });
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    console.info(`Fetching diary for: ${deviceId} on ${date}`);

    // 3b. Check if diary already exists and has been submitted
    const { data: existingDiary } = await supabase
      .from('diaries')
      .select('id, submitted_at')
      .eq('deviceid', deviceId)
      .eq('diary_date', date)
      .maybeSingle();

    if (existingDiary?.submitted_at) {
      // Diary already submitted – return existing visits and journeys
      const { data: existingVisits } = await supabase
        .from('diary_visits')
        .select('*')
        .eq('diary_id', existingDiary.id)
        .order('started_at', { ascending: true });

      const { data: existingJourneys } = await supabase
        .from('diary_journeys')
        .select('*')
        .eq('diary_id', existingDiary.id)
        .order('started_at', { ascending: true });

      console.info(`Diary already submitted at ${existingDiary.submitted_at}, returning ${(existingVisits ?? []).length} existing visits and ${(existingJourneys ?? []).length} existing journeys`);

      return new Response(JSON.stringify({
        already_submitted: true,
        submitted_at: existingDiary.submitted_at,
        visits: existingVisits ?? [],
        journeys: existingJourneys ?? [],
      }), {
        status: 200,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }

    // 4. Query all pings for the day (need position_from_home for clustering)
    const { data, error } = await supabase
      .from('locationsvisitednew')
      .select(`
        entryid,
        created_at,
        primary_type,
        position_from_home,
        other_types,
        motion_type,
        horizontal_accuracy
      `)
      .eq('deviceid', deviceId)
      .gte('created_at', `${date}T00:00:00Z`)
      .lte('created_at', `${date}T23:59:59Z`)
      .order('created_at', { ascending: true });

    if (error) {
      console.error("Supabase Error:", error);
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }

    // 5. Filter out inaccurate pings, then cluster, classify, and select
    const MAX_ACCURACY_M = 100; // reject pings with GPS accuracy worse than 100 metres
    const allPings = (data as RawPing[]).filter(p =>
      p.horizontal_accuracy == null || p.horizontal_accuracy <= MAX_ACCURACY_M
    );
    const allClusters = clusterPings(allPings);
    const selected = selectClusters(allClusters);

    // 5b. Segment journeys between high-confidence visits
    const journeys = segmentJourneys(allPings, selected);

    console.info(`Clustered ${allPings.length} pings into ${allClusters.length} visits (returning ${selected.length}) and ${journeys.length} journeys`);

    // 6. Pre-populate normalized diary tables (diaries -> diary_visits -> diary_visit_entries)

    // 6a. Upsert the diary row for this device+date
    const { data: diaryRow, error: diaryError } = await supabase
      .from('diaries')
      .upsert(
        { deviceid: deviceId, diary_date: date },
        { onConflict: 'deviceid,diary_date' }
      )
      .select('id')
      .single();

    if (diaryError || !diaryRow) {
      console.error("Diary upsert error:", diaryError);
      // Non-fatal: still return clusters to iOS even if DB write fails
    }

    if (diaryRow) {
      const diaryId = diaryRow.id;

      // 6b. Check which visits already exist for this diary
      const { data: existingVisits } = await supabase
        .from('diary_visits')
        .select('visit_id')
        .eq('diary_id', diaryId);

      const existingVisitIds = new Set(
        (existingVisits ?? []).map((r: { visit_id: string }) => r.visit_id)
      );

      // 6c. Insert new visit rows
      const newClusters = selected.filter(c => !existingVisitIds.has(c.entryid));

      if (newClusters.length > 0) {
        const visitRows = newClusters.map(c => ({
          diary_id: diaryId,
          visit_id: c.entryid,
          primary_type: c.primary_type,
          other_types: c.other_types,
          motion_type: c.motion_type,
          visit_confidence: c.visit_confidence,
          visit_type: c.visit_type,
          ping_count: c.ping_count,
          cluster_duration_s: c.cluster_duration_s,
          started_at: c.created_at,
          ended_at: c.ended_at,
          activity_label: null,
          confirmed_place: null,
          confirmed_activity: null,
          user_context: null,
        }));

        const { data: insertedVisits, error: visitInsertError } = await supabase
          .from('diary_visits')
          .insert(visitRows)
          .select('id, visit_id');

        if (visitInsertError) {
          console.error("Visit insert error:", visitInsertError);
        } else {
          console.info(`Pre-populated ${insertedVisits.length} new visit rows`);

          // 6d. Insert diary_visit_entries linking visits to their constituent pings
          const entryRows: { diary_visit_id: string; entry_id: string; position_in_cluster: number }[] = [];

          for (const iv of insertedVisits) {
            const cluster = newClusters.find(c => c.entryid === iv.visit_id);
            if (cluster) {
              cluster.entry_ids.forEach((eid, idx) => {
                entryRows.push({
                  diary_visit_id: iv.id,
                  entry_id: eid,
                  position_in_cluster: idx,
                });
              });
            }
          }

          if (entryRows.length > 0) {
            const { error: entryInsertError } = await supabase
              .from('diary_visit_entries')
              .insert(entryRows);
            if (entryInsertError) {
              console.error("Visit-entries insert error:", entryInsertError);
            } else {
              console.info(`Linked ${entryRows.length} pings to visits`);
            }
          }
        }
      }

      // 6e. Insert journey rows
      if (journeys.length > 0) {
        const { data: existingJourneys } = await supabase
          .from('diary_journeys')
          .select('journey_id')
          .eq('diary_id', diaryId);

        const existingJourneyIds = new Set(
          (existingJourneys ?? []).map((r: { journey_id: string }) => r.journey_id)
        );

        const newJourneys = journeys.filter(j => !existingJourneyIds.has(j.journey_id));

        if (newJourneys.length > 0) {
          const journeyRows = newJourneys.map(j => ({
            diary_id: diaryId,
            journey_id: j.journey_id,
            from_visit_id: j.from_visit_id,
            to_visit_id: j.to_visit_id,
            primary_transport: j.primary_transport,
            transport_proportions: j.transport_proportions,
            ping_count: j.ping_count,
            journey_duration_s: j.journey_duration_s,
            started_at: j.started_at,
            ended_at: j.ended_at,
            confirmed_transport: null,
            travel_reason: null,
          }));

          const { data: insertedJourneys, error: journeyInsertError } = await supabase
            .from('diary_journeys')
            .insert(journeyRows)
            .select('id, journey_id');

          if (journeyInsertError) {
            console.error("Journey insert error:", journeyInsertError);
          } else {
            console.info(`Pre-populated ${insertedJourneys.length} new journey rows`);

            // 6f. Insert diary_journey_entries linking journeys to their pings
            const journeyEntryRows: { diary_journey_id: string; entry_id: string; position_in_journey: number }[] = [];

            for (const ij of insertedJourneys) {
              const journey = newJourneys.find(j => j.journey_id === ij.journey_id);
              if (journey) {
                journey.entry_ids.forEach((eid, idx) => {
                  journeyEntryRows.push({
                    diary_journey_id: ij.id,
                    entry_id: eid,
                    position_in_journey: idx,
                  });
                });
              }
            }

            if (journeyEntryRows.length > 0) {
              const { error: journeyEntryInsertError } = await supabase
                .from('diary_journey_entries')
                .insert(journeyEntryRows);
              if (journeyEntryInsertError) {
                console.error("Journey-entries insert error:", journeyEntryInsertError);
              } else {
                console.info(`Linked ${journeyEntryRows.length} pings to journeys`);
              }
            }
          }
        }
      }
    }

    // 7. Return selected visits and journeys to iOS
    return new Response(JSON.stringify({ visits: selected, journeys }), {
      status: 200,
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*" 
      },
    });

  } catch (err) {
    console.error("Unexpected Error:", err.message);
    return new Response(JSON.stringify({ error: "Internal Server Error", details: err.message }), { 
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
})