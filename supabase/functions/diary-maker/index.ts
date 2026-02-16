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
  journey_confidence: "high" | "medium" | "low";
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
// GPS Smoothing (moving median on Cartesian offsets)
// ---------------------------------------------------------------------------

/** Return the median of a numeric array. */
function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 !== 0 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

/** Apply a moving-median filter over a window of 3 pings to reduce GPS noise.
 *  Only smooths Cartesian offsets (x_m, y_m); pings without Cartesian data pass through.
 *  Returns new array — does not mutate originals. */
function smoothPings(pings: RawPing[]): RawPing[] {
  if (pings.length < 3) return pings;
  const WINDOW = 3;
  return pings.map((ping, i) => {
    // Only smooth pings that have Cartesian coordinates
    if (ping.position_from_home.x_m == null || ping.position_from_home.y_m == null) return ping;

    const start = Math.max(0, i - Math.floor(WINDOW / 2));
    const end = Math.min(pings.length, start + WINDOW);
    const windowPings = pings.slice(start, end)
      .filter(p => p.position_from_home.x_m != null && p.position_from_home.y_m != null);

    if (windowPings.length < 2) return ping;

    const medianX = median(windowPings.map(p => p.position_from_home.x_m!));
    const medianY = median(windowPings.map(p => p.position_from_home.y_m!));

    // Return a new ping with smoothed position; preserve all other fields
    return {
      ...ping,
      position_from_home: {
        ...ping.position_from_home,
        x_m: medianX,
        y_m: medianY,
      },
    };
  });
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
// Journey segmentation: split pings between medium+ confidence visits by transport
// ---------------------------------------------------------------------------

/** Active transport modes (exclude "still" and "unknown" which get absorbed). */
const ACTIVE_MODES = new Set(["walking", "running", "cycling", "automotive"]);

/** Normalise motion string to lowercase for consistent comparison. */
function normaliseMotion(m: string): string {
  return m.toLowerCase();
}

/** Expected ping interval in seconds per transport mode (matches iOS throttle intervals). */
const EXPECTED_INTERVAL: Record<string, number> = {
  walking: 120,
  running: 120,
  cycling: 420,
  automotive: 600,
};

/** Map visit confidence labels to numeric scores for anchor quality calculation. */
function visitConfidenceScore(conf: "high" | "medium" | "low"): number {
  if (conf === "high") return 1.0;
  if (conf === "medium") return 0.66;
  return 0.33;
}

/** Plausible speed ranges in km/h per transport mode. */
const SPEED_RANGES: Record<string, { min: number; max: number }> = {
  walking:    { min: 0, max: 15 },
  running:    { min: 0, max: 25 },
  cycling:    { min: 0, max: 60 },
  automotive: { min: 3, max: 200 },
};

/**
 * Compute a journey confidence score from four signals:
 *   1. Mode dominance (40%): consistency of the primary transport mode
 *   2. Ping density  (35%): how well-sampled the journey is relative to expectations
 *   3. Anchor quality (25%): confidence of the bounding visits
 *   4. Plausibility (multiplicative): average speed must be reasonable for the mode
 */
function computeJourneyConfidence(
  segmentPings: RawPing[],
  primaryTransport: string,
  transportProportions: Record<string, number>,
  durationS: number,
  fromVisit: ClusterResult,
  toVisit: ClusterResult,
): "high" | "medium" | "low" {
  // --- Signal 1: Mode dominance (40%) ---
  const dominance = transportProportions[primaryTransport] ?? 0;
  let modeScore: number;
  if (dominance >= 0.8) modeScore = 1.0;
  else if (dominance >= 0.6) modeScore = 0.75;
  else modeScore = 0.5;

  // --- Signal 2: Ping density (35%) ---
  const expectedInterval = EXPECTED_INTERVAL[primaryTransport] ?? 300;
  const expectedPings = durationS > 0 ? durationS / expectedInterval : 1;
  const densityScore = Math.min(1.0, segmentPings.length / Math.max(1, expectedPings));

  // --- Signal 3: Anchor quality (25%) ---
  const anchorScore =
    (visitConfidenceScore(fromVisit.visit_confidence) +
     visitConfidenceScore(toVisit.visit_confidence)) / 2;

  // --- Base composite ---
  const baseComposite =
    modeScore     * 0.40 +
    densityScore  * 0.35 +
    anchorScore   * 0.25;

  // --- Signal 4: Plausibility check (multiplicative) ---
  let plausibilityMultiplier = 1.0;
  if (durationS > 0 && segmentPings.length >= 2) {
    const first = segmentPings[0];
    const last = segmentPings[segmentPings.length - 1];
    const displacementM = distanceBetween(
      first.position_from_home,
      last.position_from_home,
    );
    const speedKmH = (displacementM / 1000) / (durationS / 3600);
    const range = SPEED_RANGES[primaryTransport];
    if (range && (speedKmH > range.max || speedKmH < range.min)) {
      plausibilityMultiplier = 0.5;
    }
  }

  const finalScore = Math.min(1.0, baseComposite * plausibilityMultiplier);

  if (finalScore >= 0.75) return "high";
  if (finalScore >= 0.50) return "medium";
  return "low";
}

/**
 * Segment pings between consecutive medium-or-higher confidence visits into journeys.
 * Each journey is a contiguous run of pings sharing the same active transport mode.
 * "still"/"unknown" pings are absorbed into the preceding active segment.
 */
function segmentJourneys(
  allPings: RawPing[],
  selectedVisits: ClusterResult[],
): JourneyResult[] {
  // 1. Identify medium+ confidence visits in chronological order as journey anchors
  const anchorVisits = selectedVisits
    .filter(v => v.visit_confidence === "high" || v.visit_confidence === "medium")
    .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());

  if (anchorVisits.length < 2) return []; // need at least two anchors

  const journeys: JourneyResult[] = [];

  // 2. For each consecutive pair of anchor visits, extract gap pings
  for (let vi = 0; vi < anchorVisits.length - 1; vi++) {
    const vA = anchorVisits[vi];
    const vB = anchorVisits[vi + 1];

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
      const segDuration = durationSeconds(first.created_at, last.created_at);

      const journey_confidence = computeJourneyConfidence(
        seg,
        primaryTransport,
        proportions,
        segDuration,
        vA,
        vB,
      );

      journeys.push({
        journey_id: first.entryid,
        entry_ids: seg.map(p => p.entryid),
        from_visit_id: vA.entryid,
        to_visit_id: vB.entryid,
        primary_transport: primaryTransport,
        transport_proportions: proportions,
        started_at: first.created_at,
        ended_at: last.created_at,
        journey_duration_s: segDuration,
        ping_count: seg.length,
        journey_confidence,
      });
    }
  }

  return journeys;
}

// ---------------------------------------------------------------------------
// Synthetic (red herring) visit/journey injection for sensitivity/specificity
// ---------------------------------------------------------------------------

/** Representative subset of Google Places Table A types across all 19 categories.
 *  Used to generate synthetic visits with random place types. */
const TABLE_A_PLACE_TYPES: string[] = [
  // Automotive
  "car_repair", "gas_station", "parking", "car_wash",
  // Business
  "corporate_office", "farm",
  // Culture
  "art_gallery", "museum", "performing_arts_theater", "monument",
  // Education
  "library", "school", "university", "primary_school",
  // Entertainment and Recreation
  "amusement_park", "bowling_alley", "community_center", "movie_theater",
  "national_park", "park", "zoo", "night_club", "casino", "concert_hall",
  // Facilities
  "public_bathroom",
  // Finance
  "bank", "atm",
  // Food and Drink
  "restaurant", "cafe", "bakery", "bar", "coffee_shop", "fast_food_restaurant",
  "ice_cream_shop", "pizza_restaurant", "sushi_restaurant", "steak_house",
  "italian_restaurant", "chinese_restaurant", "mexican_restaurant",
  // Geographical Areas
  "locality",
  // Government
  "post_office", "courthouse", "city_hall", "police",
  // Health and Wellness
  "hospital", "pharmacy", "dentist", "doctor", "gym", "spa",
  // Housing
  "apartment_building", "apartment_complex",
  // Lodging
  "hotel", "hostel", "campground", "motel",
  // Natural Features
  "beach",
  // Places of Worship
  "church", "mosque", "synagogue",
  // Services
  "hair_salon", "laundry", "veterinary_care", "barber_shop", "beauty_salon",
  // Shopping
  "supermarket", "grocery_store", "clothing_store", "shopping_mall",
  "convenience_store", "book_store", "electronics_store", "shoe_store",
  // Sports
  "fitness_center", "stadium", "swimming_pool", "golf_course",
  // Transportation
  "train_station", "bus_station", "airport", "subway_station",
];

/** Pick a random element from an array. */
function randomChoice<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

/** Pick a weighted random confidence level mimicking real visit distribution. */
function randomVisitConfidence(): "high" | "medium" | "low" {
  const r = Math.random();
  if (r < 0.50) return "high";
  if (r < 0.85) return "medium";
  return "low";
}

/** Pick a weighted random transport mode. */
function randomTransportMode(): string {
  const r = Math.random();
  if (r < 0.40) return "walking";
  if (r < 0.80) return "automotive";
  if (r < 0.95) return "cycling";
  return "running";
}

interface TimeSlot {
  startMs: number;
  endMs: number;
}

/**
 * Generate 1-3 synthetic red-herring visits placed in available time slots.
 * Each visit uses either a reused place type from the day's real visits or a
 * random Table A type. Synthetic IDs are prefixed with "syn_" for clarity.
 */
function generateSyntheticVisits(
  realVisits: ClusterResult[],
  date: string,
): ClusterResult[] {
  if (realVisits.length === 0) return [];

  // Build available time slots: gaps between visits + before first / after last
  const dayStartMs = new Date(`${date}T07:00:00Z`).getTime();
  const dayEndMs   = new Date(`${date}T22:00:00Z`).getTime();

  const sorted = [...realVisits].sort(
    (a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime(),
  );

  const slots: TimeSlot[] = [];

  // Before first visit
  const firstStart = new Date(sorted[0].created_at).getTime();
  if (firstStart - dayStartMs >= 600_000) {
    slots.push({ startMs: dayStartMs, endMs: firstStart });
  }

  // Gaps between visits
  for (let i = 0; i < sorted.length - 1; i++) {
    const gapStart = new Date(sorted[i].ended_at).getTime();
    const gapEnd   = new Date(sorted[i + 1].created_at).getTime();
    if (gapEnd - gapStart >= 600_000) {
      slots.push({ startMs: gapStart, endMs: gapEnd });
    }
  }

  // After last visit
  const lastEnd = new Date(sorted[sorted.length - 1].ended_at).getTime();
  if (dayEndMs - lastEnd >= 600_000) {
    slots.push({ startMs: lastEnd, endMs: dayEndMs });
  }

  if (slots.length === 0) return [];

  const realPlaceTypes = sorted.map(v => v.primary_type).filter(Boolean);
  const count = Math.min(1 + Math.floor(Math.random() * 3), slots.length); // 1-3, capped by slots

  // Shuffle slots to pick randomly without replacement
  const shuffledSlots = [...slots].sort(() => Math.random() - 0.5);

  const synthetics: ClusterResult[] = [];

  for (let i = 0; i < count; i++) {
    const slot = shuffledSlots[i];
    const slotDurationMs = slot.endMs - slot.startMs;

    // Visit duration: 5-60 minutes, capped at 70% of slot so there's room for travel
    const maxDurationMs = Math.min(60 * 60_000, slotDurationMs * 0.7);
    const minDurationMs = Math.min(5 * 60_000, maxDurationMs);
    const visitDurationMs = minDurationMs + Math.random() * (maxDurationMs - minDurationMs);
    const visitDurationS = Math.round(visitDurationMs / 1000);

    // Place the visit randomly within the slot (leaving margins for travel)
    const margin = (slotDurationMs - visitDurationMs) / 2;
    const visitStartMs = slot.startMs + margin * (0.3 + Math.random() * 0.4);
    const visitEndMs = visitStartMs + visitDurationMs;

    // Choose place type: 50/50 reuse vs random
    let primaryType: string;
    if (realPlaceTypes.length > 0 && Math.random() < 0.5) {
      primaryType = randomChoice(realPlaceTypes);
    } else {
      primaryType = randomChoice(TABLE_A_PLACE_TYPES);
    }

    const visitConfidence = randomVisitConfidence();

    synthetics.push({
      entryid: `syn_${crypto.randomUUID()}`,
      entry_ids: [],
      created_at: new Date(visitStartMs).toISOString(),
      ended_at: new Date(visitEndMs).toISOString(),
      cluster_duration_s: visitDurationS,
      primary_type: primaryType,
      other_types: [],
      motion_type: { motion: "still", confidence: "medium" },
      visit_confidence: visitConfidence,
      visit_type: "visit",
      ping_count: Math.max(2, Math.floor(visitDurationS / 300)),
    });
  }

  return synthetics;
}

/**
 * Generate synthetic journeys connecting synthetic visits to their chronological
 * neighbors (real or synthetic). Each synthetic visit gets up to 2 journeys:
 * one arriving from the previous visit and one departing to the next.
 */
function generateSyntheticJourneys(
  allVisitsSorted: ClusterResult[],
  syntheticVisits: ClusterResult[],
): JourneyResult[] {
  if (syntheticVisits.length === 0 || allVisitsSorted.length < 2) return [];

  const syntheticIds = new Set(syntheticVisits.map(v => v.entryid));
  const journeys: JourneyResult[] = [];

  for (let i = 0; i < allVisitsSorted.length; i++) {
    const visit = allVisitsSorted[i];
    if (!syntheticIds.has(visit.entryid)) continue;

    // Journey from previous visit to this synthetic visit
    if (i > 0) {
      const prev = allVisitsSorted[i - 1];
      const gapStartMs = new Date(prev.ended_at).getTime();
      const gapEndMs   = new Date(visit.created_at).getTime();
      const gapS = Math.round((gapEndMs - gapStartMs) / 1000);

      if (gapS > 0) {
        const transport = randomTransportMode();
        journeys.push({
          journey_id: `syn_${crypto.randomUUID()}`,
          entry_ids: [],
          from_visit_id: prev.entryid,
          to_visit_id: visit.entryid,
          primary_transport: transport,
          transport_proportions: { [transport]: 0.85, unknown: 0.15 },
          started_at: prev.ended_at,
          ended_at: visit.created_at,
          journey_duration_s: gapS,
          ping_count: Math.max(1, Math.floor(gapS / 180)),
          journey_confidence: "medium",
        });
      }
    }

    // Journey from this synthetic visit to next visit
    if (i < allVisitsSorted.length - 1) {
      const next = allVisitsSorted[i + 1];
      const gapStartMs = new Date(visit.ended_at).getTime();
      const gapEndMs   = new Date(next.created_at).getTime();
      const gapS = Math.round((gapEndMs - gapStartMs) / 1000);

      if (gapS > 0) {
        const transport = randomTransportMode();
        journeys.push({
          journey_id: `syn_${crypto.randomUUID()}`,
          entry_ids: [],
          from_visit_id: visit.entryid,
          to_visit_id: next.entryid,
          primary_transport: transport,
          transport_proportions: { [transport]: 0.85, unknown: 0.15 },
          started_at: visit.ended_at,
          ended_at: next.created_at,
          journey_duration_s: gapS,
          ping_count: Math.max(1, Math.floor(gapS / 180)),
          journey_confidence: "medium",
        });
      }
    }
  }

  // Deduplicate: if two synthetic visits are adjacent, the departing journey of
  // the first and the arriving journey of the second would cover the same gap.
  // Keep only the first one encountered for each (from_visit_id, to_visit_id) pair.
  const seen = new Set<string>();
  const deduped: JourneyResult[] = [];
  for (const j of journeys) {
    const key = `${j.from_visit_id}|${j.to_visit_id}`;
    if (!seen.has(key)) {
      seen.add(key);
      deduped.push(j);
    }
  }

  return deduped;
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

    // 5. Filter out inaccurate pings, then smooth, cluster, classify, and select
    const MAX_ACCURACY_M = 100; // reject pings with GPS accuracy worse than 100 metres
    const allPings = (data as RawPing[]).filter(p =>
      p.horizontal_accuracy == null || p.horizontal_accuracy <= MAX_ACCURACY_M
    );
    const smoothed = smoothPings(allPings);
    const allClusters = clusterPings(smoothed);
    const selected = selectClusters(allClusters);

    // 5b. Segment journeys between medium+ confidence visits
    // Note: uses original (unsmoothed) pings so journey positions reflect actual GPS data
    const journeys = segmentJourneys(allPings, selected);

    // 5c. Generate synthetic red-herring visits and journeys for sensitivity/specificity analysis
    const syntheticVisits = generateSyntheticVisits(selected, date);
    const allVisits = [...selected, ...syntheticVisits]
      .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());

    const syntheticJourneys = generateSyntheticJourneys(allVisits, syntheticVisits);
    const allJourneys = [...journeys, ...syntheticJourneys]
      .sort((a, b) => new Date(a.started_at).getTime() - new Date(b.started_at).getTime());

    // Track which IDs are synthetic for DB flagging (not exposed to iOS)
    const syntheticVisitIds = new Set(syntheticVisits.map(v => v.entryid));
    const syntheticJourneyIds = new Set(syntheticJourneys.map(j => j.journey_id));

    console.info(`Clustered ${allPings.length} pings into ${allClusters.length} visits (returning ${selected.length} real + ${syntheticVisits.length} synthetic) and ${journeys.length} real + ${syntheticJourneys.length} synthetic journeys`);

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

      // 6c. Insert new visit rows (real + synthetic)
      const newClusters = allVisits.filter(c => !existingVisitIds.has(c.entryid));

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
          is_synthetic: syntheticVisitIds.has(c.entryid),
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
          // Skip synthetic visits — they have no real pings to link.
          const entryRows: { diary_visit_id: string; entry_id: string; position_in_cluster: number }[] = [];

          for (const iv of insertedVisits) {
            if (syntheticVisitIds.has(iv.visit_id)) continue;
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

      // 6e. Insert journey rows (real + synthetic)
      if (allJourneys.length > 0) {
        const { data: existingJourneys } = await supabase
          .from('diary_journeys')
          .select('journey_id')
          .eq('diary_id', diaryId);

        const existingJourneyIds = new Set(
          (existingJourneys ?? []).map((r: { journey_id: string }) => r.journey_id)
        );

        const newJourneys = allJourneys.filter(j => !existingJourneyIds.has(j.journey_id));

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
            journey_confidence: j.journey_confidence,
            started_at: j.started_at,
            ended_at: j.ended_at,
            is_synthetic: syntheticJourneyIds.has(j.journey_id),
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
            // Skip synthetic journeys — they have no real pings to link.
            const journeyEntryRows: { diary_journey_id: string; entry_id: string; position_in_journey: number }[] = [];

            for (const ij of insertedJourneys) {
              if (syntheticJourneyIds.has(ij.journey_id)) continue;
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

    // 7. Return all visits and journeys (real + synthetic) to iOS
    // Note: is_synthetic flag is only in the DB, not in these response objects
    return new Response(JSON.stringify({ visits: allVisits, journeys: allJourneys }), {
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