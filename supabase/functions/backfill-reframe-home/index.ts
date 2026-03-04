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

  let allRows: { id: string; latitude: number; longitude: number }[] = [];
  let offset = 0;

  while (true) {
    const { data, error } = await supabase
      .from("locationsvisitednew")
      .select("id, latitude, longitude")
      .eq("deviceid", deviceId)
      .range(offset, offset + PAGE_SIZE - 1);

    if (error) {
      console.error("Failed to fetch rows", error.message);
      return jsonResponse(
        { error: "Failed to fetch rows", detail: error.message },
        500,
      );
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
      .filter((row) => row.latitude != null && row.longitude != null)
      .map((row) => {
        const pfh = calculateDisplacement(
          user_home_lat,
          user_home_long,
          row.latitude,
          row.longitude,
        );
        return supabase
          .from("locationsvisitednew")
          .update({ position_from_home: pfh })
          .eq("id", row.id);
      });

    const results = await Promise.all(updates);
    updated += results.filter((r) => !r.error).length;
  }

  console.info(`Backfill complete: ${updated} rows updated`);
  return jsonResponse({ updated }, 200);
});
