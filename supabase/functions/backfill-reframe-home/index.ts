import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "supabase";
import { calculateDisplacement } from "../_shared/displacement.ts";

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const PAGE_SIZE = 1000;
const BATCH_SIZE = 50;
const HOME_BOUNDARY_METRES = 30;

const DEFAULT_HOME_LAT_FALLBACK = 51.503349370657986;
const DEFAULT_HOME_LONG_FALLBACK = -0.0868719398915672;

interface PositionFromHome {
  distance: number;
  bearing: number;
  x_m: number;
  y_m: number;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let body;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const { deviceId, user_home_lat, user_home_long } = body;

  if (typeof deviceId !== "string" || !deviceId) {
    return jsonResponse({ error: "deviceId must be a non-empty string" }, 400);
  }
  if (
    typeof user_home_lat !== "number" ||
    !isFinite(user_home_lat) ||
    user_home_lat < -90 ||
    user_home_lat > 90
  ) {
    return jsonResponse(
      { error: "user_home_lat must be a number between -90 and 90" },
      400,
    );
  }
  if (
    typeof user_home_long !== "number" ||
    !isFinite(user_home_long) ||
    user_home_long < -180 ||
    user_home_long > 180
  ) {
    return jsonResponse(
      { error: "user_home_long must be a number between -180 and 180" },
      400,
    );
  }

  console.info("backfill-reframe-home request received", { deviceId });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: device, error: deviceError } = await supabase
    .from("device_registry")
    .select("device_id")
    .eq("device_id", deviceId)
    .maybeSingle();

  if (deviceError) {
    console.error("device_registry lookup failed:", deviceError.message);
    return jsonResponse({ error: "Unknown device" }, 403);
  }
  if (!device) {
    return jsonResponse({ error: "Unknown device" }, 403);
  }

  // Resolve the old (default) home coordinates that existing pings are relative to
  const oldHomeLat = (() => {
    const v = Deno.env.get("DEFAULT_HOME_LAT");
    if (v == null || v === "") return DEFAULT_HOME_LAT_FALLBACK;
    const n = parseFloat(v);
    return isFinite(n) ? n : DEFAULT_HOME_LAT_FALLBACK;
  })();
  const oldHomeLong = (() => {
    const v = Deno.env.get("DEFAULT_HOME_LONG");
    if (v == null || v === "") return DEFAULT_HOME_LONG_FALLBACK;
    const n = parseFloat(v);
    return isFinite(n) ? n : DEFAULT_HOME_LONG_FALLBACK;
  })();

  // Vector from new home to old home — added to each ping's old offsets
  const homeOffset = calculateDisplacement(
    user_home_lat,
    user_home_long,
    oldHomeLat,
    oldHomeLong,
  );

  let allRows: { entryid: string; position_from_home: PositionFromHome | null }[] = [];
  let offset = 0;

  while (true) {
    const { data, error } = await supabase
      .from("locationsvisitednew")
      .select("entryid, position_from_home")
      .eq("deviceid", deviceId)
      .range(offset, offset + PAGE_SIZE - 1);

    if (error) {
      console.error("Failed to fetch rows:", error.message);
      return jsonResponse({ error: "Failed to fetch rows" }, 500);
    }

    if (!data || data.length === 0) break;
    allRows.push(...data);
    if (data.length < PAGE_SIZE) break;
    offset += PAGE_SIZE;
  }

  console.info(`Fetched ${allRows.length} rows for backfill`);

  if (allRows.length === 0) {
    return jsonResponse({ updated: 0 }, 200);
  }

  let updated = 0;

  for (let i = 0; i < allRows.length; i += BATCH_SIZE) {
    const batch = allRows.slice(i, i + BATCH_SIZE);
    const updates = batch
      .filter((row) => row.position_from_home?.x_m != null && row.position_from_home?.y_m != null)
      .map((row) => {
        const old = row.position_from_home!;
        const newX = homeOffset.x_m + old.x_m;
        const newY = homeOffset.y_m + old.y_m;
        const newDistance = parseFloat(Math.sqrt(newX * newX + newY * newY).toFixed(2));
        const newBearing = parseFloat(
          ((Math.atan2(newX, newY) * 180 / Math.PI + 360) % 360).toFixed(4),
        );

        const pfh: PositionFromHome = {
          distance: newDistance,
          bearing: newBearing,
          x_m: parseFloat(newX.toFixed(2)),
          y_m: parseFloat(newY.toFixed(2)),
        };

        const payload: Record<string, unknown> = { position_from_home: pfh };
        if (pfh.distance <= HOME_BOUNDARY_METRES) {
          payload.primary_type = "home";
          payload.place_category = "Home";
        }
        return supabase
          .from("locationsvisitednew")
          .update(payload)
          .eq("entryid", row.entryid);
      });

    const results = await Promise.all(updates);
    updated += results.filter((r) => !r.error).length;
  }

  console.info(`Backfill complete: ${updated} rows updated`);
  return jsonResponse({ updated }, 200);
});
