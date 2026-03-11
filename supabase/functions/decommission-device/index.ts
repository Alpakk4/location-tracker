// decommission-device: Admin-only. Deletes a device from device_registry
// so the device_id can no longer submit data.
// Call with X-Admin-Secret header set to ADMIN_SECRET env. No JWT required.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "supabase";

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const adminSecret = req.headers.get("x-admin-secret");
  const expectedSecret = Deno.env.get("ADMIN_SECRET");
  if (!expectedSecret || adminSecret !== expectedSecret) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  let body: { deviceId?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const deviceId = body?.deviceId;
  if (typeof deviceId !== "string" || !deviceId.trim()) {
    return jsonResponse({ error: "deviceId is required and must be a non-empty string" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseKey) {
    console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return jsonResponse({ error: "Server configuration error" }, 500);
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  const { data: row, error: fetchError } = await supabase
    .from("device_registry")
    .select("device_id")
    .eq("device_id", deviceId.trim())
    .maybeSingle();

  if (fetchError) {
    console.error("device_registry select error:", fetchError);
    return jsonResponse({ error: "Failed to look up device" }, 500);
  }

  if (!row) {
    return jsonResponse({ error: "Device not found in registry", deviceId: deviceId.trim() }, 404);
  }

  const { error: deleteError } = await supabase
    .from("device_registry")
    .delete()
    .eq("device_id", deviceId.trim());

  if (deleteError) {
    console.error("device_registry delete error:", deleteError);
    return jsonResponse({ error: "Failed to delete device row" }, 500);
  }

  console.info("Decommissioned device", { deviceId: deviceId.trim() });
  return jsonResponse({ ok: true, deviceId: deviceId.trim() }, 200);
});
