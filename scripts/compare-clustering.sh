#!/usr/bin/env bash
# ============================================================================
# Compare diary-maker (current) vs diary-maker-stdbscan (ST-DBSCAN) output
#
# Prerequisites:
#   1. Local Supabase running:  supabase start
#   2. Sample pings loaded into local DB (see scripts/seed-sample-data.sql)
#   3. jq installed:  brew install jq
#
# Usage:
#   bash scripts/compare-clustering.sh                   # uses defaults
#   DATE=2026-03-09 bash scripts/compare-clustering.sh   # override date
# ============================================================================
set -euo pipefail

API_URL="http://127.0.0.1:54321"

# Fetch keys from local Supabase (requires supabase CLI)
ANON_KEY=$(supabase status --output json 2>/dev/null | jq -r '.ANON_KEY // .anon_key // empty')
if [ -z "$ANON_KEY" ]; then
  echo "ERROR: Could not get ANON_KEY from 'supabase status'."
  echo "       Is local Supabase running? Try: supabase start"
  exit 1
fi

DEVICE_ID="${DEVICE_ID:-I-R1-26-0001}"
DATE="${DATE:-2026-03-24}"
BODY='{"deviceId":"'"$DEVICE_ID"'","date":"'"$DATE"'"}'

mkdir -p scripts/output

echo "============================================"
echo "  Clustering comparison: $DEVICE_ID on $DATE"
echo "============================================"
echo ""

# --- Call diary-maker (current algorithm) ---
echo ">>> Calling diary-maker (current)..."
HTTP_CODE=$(curl -s -o scripts/output/centroid.json -w "%{http_code}" \
  -X POST "$API_URL/functions/v1/diary-maker" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ANON_KEY" \
  -d "$BODY")

if [ "$HTTP_CODE" != "200" ]; then
  echo "    FAILED (HTTP $HTTP_CODE):"
  cat scripts/output/centroid.json
  echo ""
else
  # Pretty-print
  jq '.' scripts/output/centroid.json > scripts/output/centroid_pretty.json && \
    mv scripts/output/centroid_pretty.json scripts/output/centroid.json
  echo "    -> scripts/output/centroid.json (HTTP $HTTP_CODE)"
fi

# --- Call diary-maker-stdbscan ---
echo ">>> Calling diary-maker-stdbscan..."
HTTP_CODE=$(curl -s -o scripts/output/stdbscan.json -w "%{http_code}" \
  -X POST "$API_URL/functions/v1/diary-maker-stdbscan" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ANON_KEY" \
  -d "$BODY")

if [ "$HTTP_CODE" != "200" ]; then
  echo "    FAILED (HTTP $HTTP_CODE):"
  cat scripts/output/stdbscan.json
  echo ""
else
  jq '.' scripts/output/stdbscan.json > scripts/output/stdbscan_pretty.json && \
    mv scripts/output/stdbscan_pretty.json scripts/output/stdbscan.json
  echo "    -> scripts/output/stdbscan.json (HTTP $HTTP_CODE)"
fi

echo ""
echo "============================================"
echo "  Results summary"
echo "============================================"

# --- Visit counts ---
echo ""
echo "--- Visit counts ---"
C_VISITS=$(jq '.visits | length' scripts/output/centroid.json 2>/dev/null || echo "N/A")
S_VISITS=$(jq '.visits | length' scripts/output/stdbscan.json 2>/dev/null || echo "N/A")
echo "  Current:   $C_VISITS visits"
echo "  ST-DBSCAN: $S_VISITS visits"

# --- Confidence distribution ---
echo ""
echo "--- Visit confidence distribution ---"
echo "  Current:"
jq -r '[.visits[].visit_confidence] | group_by(.) | map("    " + .[0] + ": " + (length | tostring)) | .[]' scripts/output/centroid.json 2>/dev/null || echo "    N/A"
echo "  ST-DBSCAN:"
jq -r '[.visits[].visit_confidence] | group_by(.) | map("    " + .[0] + ": " + (length | tostring)) | .[]' scripts/output/stdbscan.json 2>/dev/null || echo "    N/A"

# --- Visit type distribution ---
echo ""
echo "--- Visit type distribution ---"
echo "  Current:"
jq -r '[.visits[].visit_type] | group_by(.) | map("    " + .[0] + ": " + (length | tostring)) | .[]' scripts/output/centroid.json 2>/dev/null || echo "    N/A"
echo "  ST-DBSCAN:"
jq -r '[.visits[].visit_type] | group_by(.) | map("    " + .[0] + ": " + (length | tostring)) | .[]' scripts/output/stdbscan.json 2>/dev/null || echo "    N/A"

# --- Journey counts ---
echo ""
echo "--- Journey counts ---"
C_JOURNEYS=$(jq '.journeys | length' scripts/output/centroid.json 2>/dev/null || echo "N/A")
S_JOURNEYS=$(jq '.journeys | length' scripts/output/stdbscan.json 2>/dev/null || echo "N/A")
echo "  Current:   $C_JOURNEYS journeys"
echo "  ST-DBSCAN: $S_JOURNEYS journeys"

# --- Ping coverage (total pings assigned to visits) ---
echo ""
echo "--- Total pings in visits ---"
C_PINGS=$(jq '[.visits[].ping_count] | add // 0' scripts/output/centroid.json 2>/dev/null || echo "N/A")
S_PINGS=$(jq '[.visits[].ping_count] | add // 0' scripts/output/stdbscan.json 2>/dev/null || echo "N/A")
echo "  Current:   $C_PINGS"
echo "  ST-DBSCAN: $S_PINGS"

# --- Average cluster duration ---
echo ""
echo "--- Average cluster duration (seconds) ---"
C_AVG=$(jq '[.visits[].cluster_duration_s] | if length > 0 then (add / length | floor) else 0 end' scripts/output/centroid.json 2>/dev/null || echo "N/A")
S_AVG=$(jq '[.visits[].cluster_duration_s] | if length > 0 then (add / length | floor) else 0 end' scripts/output/stdbscan.json 2>/dev/null || echo "N/A")
echo "  Current:   ${C_AVG}s"
echo "  ST-DBSCAN: ${S_AVG}s"

echo ""
echo "============================================"
echo "  Full JSON files saved to scripts/output/"
echo "  For detailed diff: diff scripts/output/centroid.json scripts/output/stdbscan.json"
echo "============================================"
