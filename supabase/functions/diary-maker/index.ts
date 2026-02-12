// Diary builder: clusters location pings into visits with confidence classification

import { serve } from "std/http/server.ts"
import { createClient } from "supabase"

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface PositionFromHome {
  distance: number; // metres from home
  bearing: number;  // degrees (0-360)
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
}

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
  ping_count: number;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Distance between two points given as polar coords from a shared origin (home).
 *  Uses the law of cosines: d = sqrt(d1² + d2² - 2·d1·d2·cos(θ2-θ1))           */
function distanceBetween(a: PositionFromHome, b: PositionFromHome): number {
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

/** Numeric confidence rank for ordering (lower = worse). */
function confidenceRank(c: "high" | "medium" | "low"): number {
  if (c === "high") return 3;
  if (c === "medium") return 2;
  return 1;
}

/** Minimum confidence of two levels. */
function minConfidence(a: "high" | "medium" | "low", b: "high" | "medium" | "low"): "high" | "medium" | "low" {
  return confidenceRank(a) <= confidenceRank(b) ? a : b;
}

/** Duration in whole seconds between two ISO timestamps. */
function durationSeconds(startISO: string, endISO: string): number {
  return Math.max(0, Math.round((new Date(endISO).getTime() - new Date(startISO).getTime()) / 1000));
}

// ---------------------------------------------------------------------------
// Clustering
// ---------------------------------------------------------------------------

function clusterPings(pings: RawPing[]): ClusterResult[] {
  if (pings.length === 0) return [];

  const clusters: RawPing[][] = [];
  let current: RawPing[] = [pings[0]];

  for (let i = 1; i < pings.length; i++) {
    const prev = pings[i - 1];
    const curr = pings[i];
    const dist = distanceBetween(prev.position_from_home, curr.position_from_home);

    if (dist <= 75) {
      current.push(curr);
    } else {
      clusters.push(current);
      current = [curr];
    }
  }
  clusters.push(current); // finalise last cluster

  // Build representative entries
  return clusters.map((pingsInCluster) => {
    // Confidence: evaluate every consecutive pair, take the minimum
    let clusterConfidence: "high" | "medium" | "low" = "high"; // start optimistic
    for (let i = 1; i < pingsInCluster.length; i++) {
      const dist = distanceBetween(
        pingsInCluster[i - 1].position_from_home,
        pingsInCluster[i].position_from_home,
      );
      const pc = pairConfidence(dist, pingsInCluster[i - 1].motion_type, pingsInCluster[i].motion_type);
      clusterConfidence = minConfidence(clusterConfidence, pc);
    }

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
      visit_confidence: clusterConfidence,
      ping_count: pingsInCluster.length,
    };
  });
}

// ---------------------------------------------------------------------------
// Selection: all high + up to 10 medium/low (guarantee ≥1 of each if available)
// ---------------------------------------------------------------------------

function selectClusters(clusters: ClusterResult[]): ClusterResult[] {
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
      // Diary already submitted – return existing visits
      const { data: existingVisits } = await supabase
        .from('diary_visits')
        .select('*')
        .eq('diary_id', existingDiary.id)
        .order('started_at', { ascending: true });

      console.info(`Diary already submitted at ${existingDiary.submitted_at}, returning ${(existingVisits ?? []).length} existing visits`);

      return new Response(JSON.stringify({
        already_submitted: true,
        submitted_at: existingDiary.submitted_at,
        visits: existingVisits ?? [],
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
        motion_type
      `)
      .eq('deviceid', deviceId)
      .gte('created_at', `${date}T00:00:00Z`)
      .lte('created_at', `${date}T23:59:59Z`)
      .order('created_at', { ascending: true });

    if (error) {
      console.error("Supabase Error:", error);
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }

    // 5. Cluster, classify, and select
    const allClusters = clusterPings(data as RawPing[]);
    const selected = selectClusters(allClusters);

    console.info(`Clustered ${(data as RawPing[]).length} pings into ${allClusters.length} visits, returning ${selected.length}`);

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
    }

    // 7. Return selected clusters to iOS
    return new Response(JSON.stringify(selected), {
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