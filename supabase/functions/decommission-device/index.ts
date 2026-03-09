// decommission-device: Admin-only. Unlinks a device so device_id can be reused.
// Steps: (1) Optionally revoke JWT by deleting the Auth user. (2) Clear link (auth_uid = null) or delete the device_registry row.
// Call with X-Admin-Secret header set to ADMIN_SECRET env. No JWT required.

import { serve } from "std/http/server.ts";
import { createClient } from "supabase";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-admin-secret",
};

function jsonResponse(body: Record<string, unknown>, status: number, headers?: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", ...headers },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const adminSecret = req.headers.get("x-admin-secret");
  const expectedSecret = Deno.env.get("ADMIN_SECRET");
  if (!expectedSecret || adminSecret !== expectedSecret) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  let body: { deviceId?: string; deleteRow?: boolean; revokeJwt?: boolean };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const deviceId = body?.deviceId;
  if (typeof deviceId !== "string" || !deviceId.trim()) {
    return jsonResponse({ error: "deviceId is required and must be a non-empty string" }, 400);
  }

  const deleteRow = body.deleteRow === true;
  const revokeJwt = body.revokeJwt !== false; // default true

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseKey) {
    console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return jsonResponse({ error: "Server configuration error" }, 500);
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  const { data: row, error: fetchError } = await supabase
    .from("device_registry")
    .select("device_id, auth_uid")
    .eq("device_id", deviceId.trim())
    .maybeSingle();

  if (fetchError) {
    console.error("device_registry select error:", fetchError);
    return jsonResponse({ error: "Failed to look up device" }, 500);
  }

  if (!row) {
    return jsonResponse({ error: "Device not found in registry", deviceId: deviceId.trim() }, 404);
  }

  const authUid: string | null = row.auth_uid ?? null;
  const result: { deviceId: string; authUidRevoked: boolean; rowCleared: boolean; rowDeleted: boolean } = {
    deviceId: deviceId.trim(),
    authUidRevoked: false,
    rowCleared: false,
    rowDeleted: false,
  };

  if (revokeJwt && authUid) {
    const { error: deleteUserError } = await supabase.auth.admin.deleteUser(authUid);
    if (deleteUserError) {
      console.error("Auth admin deleteUser error:", deleteUserError);
      return jsonResponse({ error: "Failed to revoke JWT (delete Auth user)" }, 500);
    }
    result.authUidRevoked = true;
  }

  if (deleteRow) {
    const { error: deleteError } = await supabase.from("device_registry").delete().eq("device_id", deviceId.trim());
    if (deleteError) {
      console.error("device_registry delete error:", deleteError);
      return jsonResponse({ error: "Failed to delete device row" }, 500);
    }
    result.rowDeleted = true;
  } else {
    const { error: updateError } = await supabase
      .from("device_registry")
      .update({ auth_uid: null })
      .eq("device_id", deviceId.trim());
    if (updateError) {
      console.error("device_registry update error:", updateError);
      return jsonResponse({ error: "Failed to clear auth_uid" }, 500);
    }
    result.rowCleared = true;
  }

  console.info("Decommissioned device", result);
  return jsonResponse({ ok: true, result }, 200);
});
