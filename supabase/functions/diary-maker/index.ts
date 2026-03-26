// Diary builder: clusters location pings into visits with confidence classification.
// Uses ST-DBSCAN (Spatio-Temporal DBSCAN) for density-based clustering.

import { serve } from "std/http/server.ts"
import { createClient } from "supabase"
import { TABLE_A_PLACE_TYPES, getCategory } from "../_shared/place-types.ts"
import { getActivityForCategory } from "../_shared/category-activity-map.ts"

// ---------------------------------------------------------------------------
// Types & interfaces
// ---------------------------------------------------------------------------

interface PositionFromHome {
  distance: number;
  bearing: number;
  x_m?: number;
  y_m?: number;
}

interface MotionType {
  motion: string;
  confidence: string;
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
  place_category: string;
  activity_label: string;
  other_types: string[];
  motion_type: MotionType;
  visit_confidence: "high" | "medium" | "low";
  visit_type: VisitType;
  ping_count: number;
}

interface JourneyResult {
  journey_id: string;
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

function distanceBetween(a: PositionFromHome, b: PositionFromHome): number {
  if (a.x_m != null && a.y_m != null && b.x_m != null && b.y_m != null) {
    const dx = a.x_m - b.x_m;
    const dy = a.y_m - b.y_m;
    return Math.sqrt((dx * dx) + (dy * dy));
  }
  const dθ = (b.bearing - a.bearing) * Math.PI / 180;
  const d2 = a.distance ** 2 + b.distance ** 2 -
             2 * a.distance * b.distance * Math.cos(dθ);
  return Math.sqrt(Math.max(0, d2));
}

function isMediumPlusConfidence(confidence: string): boolean {
  return confidence === "medium" || confidence === "high";
}

function pairConfidence(dist: number, prevMotion: MotionType, currMotion: MotionType): "high" | "medium" | "low" {
  const sameMotion = currMotion.motion === prevMotion.motion;
  const isStillOrWalking = currMotion.motion === "still" || currMotion.motion === "walking";
  const favorablePath = sameMotion || (isStillOrWalking && isMediumPlusConfidence(currMotion.confidence));

  if (favorablePath) {
    if (dist <= 25) return "high";
    if (dist <= 50) return "medium";
    return "low";
  } else {
    if (dist <= 50) return "medium";
    return "low";
  }
}

function mode<T>(arr: T[]): T {
  if (arr.length === 0) {
    throw new Error("mode() called with empty array");
  }

  const counts = new Map<string, number>();
  let best: T = arr[0];
  let bestCount = 0;

  for (const v of arr) {
    const key = String(v);
    const count = (counts.get(key) ?? 0) + 1;
    counts.set(key, count);

    if (count > bestCount) {
      bestCount = count;
      best = v;
    }
  }

  return best;
}

function computeClusterConfidence(pingsInCluster: RawPing[]): {
  visit_confidence: "high" | "medium" | "low";
  visit_type: VisitType;
} {
  let pairScore: number;

  if (pingsInCluster.length < 2) {
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
    pairScore = (3 * highCount + 2 * medCount + lowCount) / (3 * totalPairs);
  }

  const accuracies = pingsInCluster
    .map(p => p.horizontal_accuracy)
    .filter((a): a is number => a != null);

  let accuracyFactor: number;
  if (accuracies.length === 0) {
    accuracyFactor = 0.7;
  } else {
    const avgAccuracy = accuracies.reduce((s, a) => s + a, 0) / accuracies.length;
    if (avgAccuracy <= 10) accuracyFactor = 1.0;
    else if (avgAccuracy <= 30) accuracyFactor = 0.9;
    else if (avgAccuracy <= 65) accuracyFactor = 0.75;
    else accuracyFactor = 0.5;
  }

  const count = pingsInCluster.length;
  let pingCountFactor: number;
  if (count === 1) pingCountFactor = 0.3;
  else if (count <= 3) pingCountFactor = 0.65;
  else if (count <= 6) pingCountFactor = 0.85;
  else pingCountFactor = 1.0;

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
    motionMultiplier = 1.15;
    visitType = "confirmed_visit";
  } else if (automotiveProp >= 0.5) {
    motionMultiplier = 0.6;
    visitType = "traffic_stop";
  }

  const baseComposite =
    pairScore       * 0.55 +
    accuracyFactor  * 0.25 +
    pingCountFactor * 0.20;

  const finalScore = Math.min(1.0, baseComposite * motionMultiplier);

  let visit_confidence: "high" | "medium" | "low";
  if (finalScore >= 0.80) visit_confidence = "high";
  else if (finalScore >= 0.55) visit_confidence = "medium";
  else visit_confidence = "low";

  return { visit_confidence, visit_type: visitType };
}

function durationSeconds(startISO: string, endISO: string): number {
  return Math.max(0, Math.round((new Date(endISO).getTime() - new Date(startISO).getTime()) / 1000));
}

// ---------------------------------------------------------------------------
// GPS Smoothing (moving median on Cartesian offsets)
// ---------------------------------------------------------------------------

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 !== 0 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

function smoothPings(pings: RawPing[]): RawPing[] {
  if (pings.length < 3) return pings;
  const WINDOW = 3;
  return pings.map((ping, i) => {
    if (ping.position_from_home.x_m == null || ping.position_from_home.y_m == null) return ping;

    const start = Math.max(0, i - Math.floor(WINDOW / 2));
    const end = Math.min(pings.length, start + WINDOW);
    const windowPings = pings.slice(start, end)
      .filter(p => p.position_from_home.x_m != null && p.position_from_home.y_m != null);

    if (windowPings.length < 2) return ping;

    const medianX = median(windowPings.map(p => p.position_from_home.x_m!));
    const medianY = median(windowPings.map(p => p.position_from_home.y_m!));

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
// Clustering (ST-DBSCAN)
// ---------------------------------------------------------------------------

const ST_EPS_SPATIAL_M   = 50;              // eps1: max spatial neighbour distance (metres)
const ST_EPS_TEMPORAL_MS = 30 * 60 * 1000;  // eps2: max temporal neighbour distance (ms)
const ST_MIN_PTS         = 2;               // minimum neighbours (incl. self) to be a core point

/**
 * ST-DBSCAN: density-based spatiotemporal clustering.
 *
 * Pings must be sorted by created_at ascending on entry. The temporal sort
 * order is exploited for early-exit neighbour search (scan outward from i and
 * break when |delta-t| > eps2).
 *
 * Returns an array of ping groups. Each noise ping becomes its own
 * single-element group so every ping appears in exactly one group.
 * Groups are sorted internally by created_at.
 */
function stDbscan(
  pings: RawPing[],
  eps1_m: number,
  eps2_ms: number,
  minPts: number,
): RawPing[][] {
  const n = pings.length;
  if (n === 0) return [];

  const UNCLASSIFIED = -1;
  const NOISE = 0;

  const timestamps = pings.map(p => new Date(p.created_at).getTime());
  const labels = new Int32Array(n).fill(UNCLASSIFIED);

  function regionQuery(i: number): number[] {
    const neighbours: number[] = [];
    const ti = timestamps[i];

    for (let j = i; j >= 0; j--) {
      if (ti - timestamps[j] > eps2_ms) break;
      if (distanceBetween(pings[i].position_from_home, pings[j].position_from_home) <= eps1_m) {
        neighbours.push(j);
      }
    }
    for (let j = i + 1; j < n; j++) {
      if (timestamps[j] - ti > eps2_ms) break;
      if (distanceBetween(pings[i].position_from_home, pings[j].position_from_home) <= eps1_m) {
        neighbours.push(j);
      }
    }
    return neighbours;
  }

  let clusterId = 0;

  for (let i = 0; i < n; i++) {
    if (labels[i] !== UNCLASSIFIED) continue;

    const neighbours = regionQuery(i);

    if (neighbours.length < minPts) {
      labels[i] = NOISE;
      continue;
    }

    clusterId++;
    labels[i] = clusterId;

    const queue = [...neighbours];
    const queued = new Set(neighbours);
    queued.add(i);

    while (queue.length > 0) {
      const j = queue.pop()!;

      if (labels[j] === NOISE) {
        labels[j] = clusterId;
      }
      if (labels[j] !== UNCLASSIFIED && labels[j] !== clusterId) continue;
      labels[j] = clusterId;

      const jNeighbours = regionQuery(j);
      if (jNeighbours.length >= minPts) {
        for (const k of jNeighbours) {
          if (!queued.has(k)) {
            queued.add(k);
            queue.push(k);
          }
        }
      }
    }
  }

  const groups: RawPing[][] = [];
  const clusterGroups = new Map<number, RawPing[]>();

  for (let i = 0; i < n; i++) {
    const lbl = labels[i];
    if (lbl === NOISE) {
      groups.push([pings[i]]);
    } else {
      if (!clusterGroups.has(lbl)) clusterGroups.set(lbl, []);
      clusterGroups.get(lbl)!.push(pings[i]);
    }
  }

  for (const group of clusterGroups.values()) {
    group.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
    groups.push(group);
  }

  groups.sort((a, b) => new Date(a[0].created_at).getTime() - new Date(b[0].created_at).getTime());

  return groups;
}

function buildClusterResults(groups: RawPing[][]): ClusterResult[] {
  return groups.map((pingsInCluster) => {
    const { visit_confidence, visit_type } = computeClusterConfidence(pingsInCluster);

    const firstPing = pingsInCluster[0];
    const lastPing = pingsInCluster[pingsInCluster.length - 1];

    const primaryTypes = pingsInCluster.map(p => p.primary_type);
    const categories = pingsInCluster.map(p => getCategory(p.primary_type));
    const motionTypes = pingsInCluster.map(p => p.motion_type);

    const allOtherTypes = [...new Set(pingsInCluster.flatMap(p => p.other_types))];
    const motionMode = mode(motionTypes.map(m => JSON.stringify(m)));
    const primaryMode = mode(primaryTypes);
    const pc = primaryMode === "home" ? "Home" : mode(categories);

    return {
      entryid: firstPing.entryid,
      entry_ids: pingsInCluster.map(p => p.entryid),
      created_at: firstPing.created_at,
      ended_at: lastPing.created_at,
      cluster_duration_s: durationSeconds(firstPing.created_at, lastPing.created_at),
      primary_type: primaryMode,
      place_category: pc,
      activity_label: getActivityForCategory(pc),
      other_types: allOtherTypes,
      motion_type: JSON.parse(motionMode) as MotionType,
      visit_confidence,
      visit_type,
      ping_count: pingsInCluster.length,
    };
  });
}

function clusterPings(pings: RawPing[]): ClusterResult[] {
  if (pings.length === 0) return [];
  const groups = stDbscan(pings, ST_EPS_SPATIAL_M, ST_EPS_TEMPORAL_MS, ST_MIN_PTS);
  return buildClusterResults(groups);
}

// ---------------------------------------------------------------------------
// Selection: enforce minimum dwell time, then all high + up to 15 medium/low
// ---------------------------------------------------------------------------

const MIN_DWELL_SECONDS = 180; // 3 minutes

function selectClusters(clusters: ClusterResult[]): ClusterResult[] {
  for (const c of clusters) {
    if (c.cluster_duration_s < MIN_DWELL_SECONDS) {
      c.visit_confidence = "low";
      c.visit_type = "brief_stop";
    }
  }

  const high   = clusters.filter(c => c.visit_confidence === "high");
  const medium = clusters.filter(c => c.visit_confidence === "medium");
  const low    = clusters.filter(c => c.visit_confidence === "low");

  const MAX_NON_HIGH = 20;
  let selectedNonHigh: ClusterResult[] = [];

  if (medium.length + low.length <= MAX_NON_HIGH) {
    selectedNonHigh = [...medium, ...low];
  } else {
    const reservedLow  = low.length > 0 ? 1 : 0;
    const reservedMed  = medium.length > 0 ? 1 : 0;

    const slotsForMedium = Math.min(medium.length, MAX_NON_HIGH - reservedLow);
    const slotsForLow    = MAX_NON_HIGH - slotsForMedium;

    const pickedMedium = medium.slice(0, Math.max(slotsForMedium, reservedMed));
    const pickedLow    = low.slice(0, Math.max(slotsForLow, reservedLow));

    selectedNonHigh = [...pickedMedium, ...pickedLow];
    if (selectedNonHigh.length > MAX_NON_HIGH) {
      const excess = selectedNonHigh.length - MAX_NON_HIGH;
      selectedNonHigh = [...pickedMedium, ...pickedLow.slice(0, pickedLow.length - excess)];
    }
  }

  const result = [...high, ...selectedNonHigh];
  result.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
  return result;
}

// ---------------------------------------------------------------------------
// Journey segmentation
// ---------------------------------------------------------------------------

const ACTIVE_MODES = new Set(["walking", "running", "cycling", "automotive"]);

function normaliseMotion(m: string): string {
  return m.toLowerCase();
}

const EXPECTED_INTERVAL: Record<string, number> = {
  walking: 120,
  running: 120,
  cycling: 420,
  automotive: 600,
};

function visitConfidenceScore(conf: "high" | "medium" | "low"): number {
  if (conf === "high") return 1.0;
  if (conf === "medium") return 0.66;
  return 0.33;
}

const SPEED_RANGES: Record<string, { min: number; max: number }> = {
  walking:    { min: 0, max: 15 },
  running:    { min: 0, max: 25 },
  cycling:    { min: 0, max: 60 },
  automotive: { min: 3, max: 200 },
};

function computeJourneyConfidence(
  segmentPings: RawPing[],
  primaryTransport: string,
  transportProportions: Record<string, number>,
  durationS: number,
  fromVisit: ClusterResult,
  toVisit: ClusterResult,
): "high" | "medium" | "low" {
  const dominance = transportProportions[primaryTransport] ?? 0;
  let modeScore: number;
  if (dominance >= 0.8) modeScore = 1.0;
  else if (dominance >= 0.6) modeScore = 0.75;
  else modeScore = 0.5;

  const expectedInterval = EXPECTED_INTERVAL[primaryTransport] ?? 300;
  const expectedPings = durationS > 0 ? durationS / expectedInterval : 1;
  const densityScore = Math.min(1.0, segmentPings.length / Math.max(1, expectedPings));

  const anchorScore =
    (visitConfidenceScore(fromVisit.visit_confidence) +
     visitConfidenceScore(toVisit.visit_confidence)) / 2;

  const baseComposite =
    modeScore     * 0.40 +
    densityScore  * 0.35 +
    anchorScore   * 0.25;

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

function segmentJourneys(
  allPings: RawPing[],
  selectedVisits: ClusterResult[],
): JourneyResult[] {
  const anchorVisits = selectedVisits
    .filter(v => v.visit_confidence === "high" || v.visit_confidence === "medium")
    .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());

  if (anchorVisits.length < 2) return [];

  const journeys: JourneyResult[] = [];

  for (let vi = 0; vi < anchorVisits.length - 1; vi++) {
    const vA = anchorVisits[vi];
    const vB = anchorVisits[vi + 1];

    const gapStart = new Date(vA.ended_at).getTime();
    const gapEnd   = new Date(vB.created_at).getTime();

    if (gapEnd <= gapStart) continue;

    const gapPings = allPings.filter(p => {
      const t = new Date(p.created_at).getTime();
      return t > gapStart && t < gapEnd;
    });

    if (gapPings.length === 0) continue;

    const segments: RawPing[][] = [];
    let currentSegment: RawPing[] = [];
    let currentMode: string | null = null;

    for (const ping of gapPings) {
      const motion = normaliseMotion(ping.motion_type.motion);

      if (ACTIVE_MODES.has(motion)) {
        if (motion === currentMode) {
          currentSegment.push(ping);
        } else {
          if (currentSegment.length > 0) {
            segments.push(currentSegment);
          }
          currentSegment = [ping];
          currentMode = motion;
        }
      } else {
        if (currentSegment.length > 0) {
          currentSegment.push(ping);
        }
      }
    }
    if (currentSegment.length > 0) {
      segments.push(currentSegment);
    }

    for (const seg of segments) {
      const motionCounts: Record<string, number> = {};
      for (const p of seg) {
        const m = normaliseMotion(p.motion_type.motion);
        motionCounts[m] = (motionCounts[m] ?? 0) + 1;
      }

      const segTotal = seg.length;
      const proportions: Record<string, number> = {};
      for (const [m, cnt] of Object.entries(motionCounts)) {
        proportions[m] = Math.round((cnt / segTotal) * 100) / 100;
      }

      let primaryTransport = "unknown";
      let bestCount = 0;
      for (const [m, cnt] of Object.entries(motionCounts)) {
        if (ACTIVE_MODES.has(m) && cnt > bestCount) {
          bestCount = cnt;
          primaryTransport = m;
        }
      }

      const first = seg[0];
      const last  = seg[seg.length - 1];
      const segDuration = durationSeconds(first.created_at, last.created_at);

      const journey_confidence = computeJourneyConfidence(
        seg, primaryTransport, proportions, segDuration, vA, vB,
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
// Synthetic visit/journey injection
// ---------------------------------------------------------------------------

function randomChoice<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function randomVisitConfidence(): "high" | "medium" | "low" {
  const r = Math.random();
  if (r < 0.50) return "high";
  if (r < 0.85) return "medium";
  return "low";
}

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

function generateSyntheticVisits(
  realVisits: ClusterResult[],
  date: string,
): ClusterResult[] {
  if (realVisits.length === 0) return [];

  const dayStartMs = new Date(`${date}T07:00:00Z`).getTime();
  const dayEndMs   = new Date(`${date}T22:00:00Z`).getTime();

  const sorted = [...realVisits].sort(
    (a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime(),
  );

  const slots: TimeSlot[] = [];

  const firstStart = new Date(sorted[0].created_at).getTime();
  if (firstStart - dayStartMs >= 600_000) {
    slots.push({ startMs: dayStartMs, endMs: firstStart });
  }

  for (let i = 0; i < sorted.length - 1; i++) {
    const gapStart = new Date(sorted[i].ended_at).getTime();
    const gapEnd   = new Date(sorted[i + 1].created_at).getTime();
    if (gapEnd - gapStart >= 600_000) {
      slots.push({ startMs: gapStart, endMs: gapEnd });
    }
  }

  const lastEnd = new Date(sorted[sorted.length - 1].ended_at).getTime();
  if (dayEndMs - lastEnd >= 600_000) {
    slots.push({ startMs: lastEnd, endMs: dayEndMs });
  }

  if (slots.length === 0) return [];

  const realPlaceTypes = sorted.map(v => v.primary_type).filter(Boolean);
  const count = Math.min(1 + Math.floor(Math.random() * 3), slots.length);
  const shuffledSlots = [...slots].sort(() => Math.random() - 0.5);

  const synthetics: ClusterResult[] = [];

  for (let i = 0; i < count; i++) {
    const slot = shuffledSlots[i];
    const slotDurationMs = slot.endMs - slot.startMs;

    const maxDurationMs = Math.min(60 * 60_000, slotDurationMs * 0.7);
    const minDurationMs = Math.min(5 * 60_000, maxDurationMs);
    const visitDurationMs = minDurationMs + Math.random() * (maxDurationMs - minDurationMs);
    const visitDurationS = Math.round(visitDurationMs / 1000);

    const margin = (slotDurationMs - visitDurationMs) / 2;
    const visitStartMs = slot.startMs + margin * (0.3 + Math.random() * 0.4);
    const visitEndMs = visitStartMs + visitDurationMs;

    let primaryType: string;
    if (realPlaceTypes.length > 0 && Math.random() < 0.5) {
      primaryType = randomChoice(realPlaceTypes);
    } else {
      primaryType = randomChoice(TABLE_A_PLACE_TYPES);
    }

    const visitConfidence = randomVisitConfidence();
    const synCat = primaryType === "home" ? "Home" : getCategory(primaryType);

    synthetics.push({
      entryid: `syn_${crypto.randomUUID()}`,
      entry_ids: [],
      created_at: new Date(visitStartMs).toISOString(),
      ended_at: new Date(visitEndMs).toISOString(),
      cluster_duration_s: visitDurationS,
      primary_type: primaryType,
      place_category: synCat,
      activity_label: getActivityForCategory(synCat),
      other_types: [],
      motion_type: { motion: "still", confidence: "medium" },
      visit_confidence: visitConfidence,
      visit_type: "visit",
      ping_count: Math.max(2, Math.floor(visitDurationS / 300)),
    });
  }

  return synthetics;
}

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
// Edge Function - Main Worker
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

    const nextDate = new Date(date + "T00:00:00Z");
    nextDate.setUTCDate(nextDate.getUTCDate() + 1);
    const nextDateStr = nextDate.toISOString().slice(0, 10);

    // 3b. Check if diary already exists and has been submitted
    const { data: existingDiary } = await supabase
      .from('diaries')
      .select('id, submitted_at')
      .eq('deviceid', deviceId)
      .eq('diary_date', date)
      .maybeSingle();

    if (existingDiary?.submitted_at) {
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
      .lt('created_at', `${nextDateStr}T00:00:00Z`)
      .order('created_at', { ascending: true });

    if (error) {
      console.error("Supabase query error:", error);
      return new Response(JSON.stringify({ error: "Failed to fetch location data" }), { status: 500 });
    }

    // 5. Filter out inaccurate pings, then smooth, cluster, classify, and select
    const MAX_ACCURACY_M = 100;
    const allPings = (data as RawPing[]).filter(p =>
      p.position_from_home != null &&
      (p.horizontal_accuracy != null && p.horizontal_accuracy <= MAX_ACCURACY_M)
    );
    const smoothed = smoothPings(allPings);
    const allClusters = clusterPings(smoothed);
    const selected = selectClusters(allClusters);

    // 5b. Segment journeys between medium+ confidence visits
    const journeys = segmentJourneys(allPings, selected);

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
    }

    // 5c. Conditionally generate synthetic red-herring visits and journeys.
    //     Only inject when new true visits are suspected (i.e. a real visit in
    //     this run was not present in the previous run for this diary).
    let allVisits: ClusterResult[];
    let allJourneys: JourneyResult[];
    let syntheticVisitIds: Set<string>;
    let syntheticJourneyIds: Set<string>;

    let previousRealVisitIds = new Set<string>();
    if (diaryRow) {
      const { data: prevVisits } = await supabase
        .from('diary_visits')
        .select('visit_id')
        .eq('diary_id', diaryRow.id)
        .eq('is_synthetic', false);

      if (prevVisits) {
        previousRealVisitIds = new Set(prevVisits.map((v: { visit_id: string }) => v.visit_id));
      }
    }

    const hasNewTrueVisits = selected.some(c => !previousRealVisitIds.has(c.entryid));

    if (hasNewTrueVisits) {
      const syntheticVisits = generateSyntheticVisits(selected, date);
      allVisits = [...selected, ...syntheticVisits]
        .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());

      const syntheticJourneys = generateSyntheticJourneys(allVisits, syntheticVisits);
      allJourneys = [...journeys, ...syntheticJourneys]
        .sort((a, b) => new Date(a.started_at).getTime() - new Date(b.started_at).getTime());

      syntheticVisitIds = new Set(syntheticVisits.map(v => v.entryid));
      syntheticJourneyIds = new Set(syntheticJourneys.map(j => j.journey_id));

      console.info(`Clustered ${allPings.length} pings into ${allClusters.length} visits (returning ${selected.length} real + ${syntheticVisits.length} synthetic) and ${journeys.length} real + ${syntheticJourneys.length} synthetic journeys`);
    } else {
      allVisits = [...selected]
        .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
      allJourneys = [...journeys]
        .sort((a, b) => new Date(a.started_at).getTime() - new Date(b.started_at).getTime());
      syntheticVisitIds = new Set();
      syntheticJourneyIds = new Set();

      console.info(`Clustered ${allPings.length} pings into ${allClusters.length} visits (returning ${selected.length} real, no new true visits — synthetics skipped) and ${journeys.length} journeys`);
    }

    if (diaryRow) {
      const diaryId = diaryRow.id;

      // 6b. Delete all existing visit/journey data for a clean re-insert
      const { error: clearError } = await supabase.rpc('clear_diary_data', {
        p_diary_id: diaryId,
      });
      if (clearError) {
        console.error("clear_diary_data RPC error:", clearError);
      }

      // 6c. Insert all visit rows (real + synthetic)
      const visitRows = allVisits.map(c => ({
        diary_id: diaryId,
        visit_id: c.entryid,
        primary_type: c.primary_type,
        place_category: c.place_category,
        activity_label: c.activity_label,
        other_types: c.other_types,
        motion_type: c.motion_type,
        visit_confidence: c.visit_confidence,
        visit_type: c.visit_type,
        ping_count: c.ping_count,
        cluster_duration_s: c.cluster_duration_s,
        started_at: c.created_at,
        ended_at: c.ended_at,
        is_synthetic: syntheticVisitIds.has(c.entryid),
        confirmed_category: null,
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
        console.info(`Pre-populated ${insertedVisits.length} visit rows`);

        // 6d. Link visits to their constituent pings (skip synthetics)
        const entryRows: { diary_visit_id: string; entry_id: string; position_in_cluster: number }[] = [];

        for (const iv of insertedVisits) {
          if (syntheticVisitIds.has(iv.visit_id)) continue;
          const cluster = allVisits.find(c => c.entryid === iv.visit_id);
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

      // 6e. Insert all journey rows (real + synthetic)
      if (allJourneys.length > 0) {
        const journeyRows = allJourneys.map(j => ({
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
          console.info(`Pre-populated ${insertedJourneys.length} journey rows`);

          // 6f. Link journeys to their pings (skip synthetics)
          const journeyEntryRows: { diary_journey_id: string; entry_id: string; position_in_journey: number }[] = [];

          for (const ij of insertedJourneys) {
            if (syntheticJourneyIds.has(ij.journey_id)) continue;
            const journey = allJourneys.find(j => j.journey_id === ij.journey_id);
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

    // 7. Return all visits and journeys (real + synthetic) to iOS
    return new Response(JSON.stringify({ visits: allVisits, journeys: allJourneys }), {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      },
    });

  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("Unexpected error:", message);
    return new Response(JSON.stringify({ error: "Internal Server Error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
})
