import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "supabase";

type Action = "decommission" | "rename" | "purge";

interface RequestBody {
  deviceId?: string;
  action?: Action;
  newDeviceId?: string;
}

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

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const deviceId = body?.deviceId?.trim();
  if (typeof body?.deviceId !== "string" || !deviceId) {
    return jsonResponse(
      { error: "deviceId is required and must be a non-empty string" },
      400,
    );
  }

  const action: Action = body.action ?? "decommission";
  const validActions: Action[] = ["decommission", "rename", "purge"];
  if (!validActions.includes(action)) {
    return jsonResponse(
      { error: `Invalid action. Must be one of: ${validActions.join(", ")}` },
      400,
    );
  }

  if (action === "rename") {
    const newId = body.newDeviceId?.trim();
    if (typeof body.newDeviceId !== "string" || !newId) {
      return jsonResponse(
        { error: "newDeviceId is required for the rename action" },
        400,
      );
    }
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseKey) {
    console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return jsonResponse({ error: "Server configuration error" }, 500);
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  // Verify the device exists
  const { data: row, error: fetchError } = await supabase
    .from("device_registry")
    .select("device_id")
    .eq("device_id", deviceId)
    .maybeSingle();

  if (fetchError) {
    console.error("device_registry select error:", fetchError);
    return jsonResponse({ error: "Failed to look up device" }, 500);
  }
  if (!row) {
    return jsonResponse({ error: "Device not found in registry", deviceId }, 404);
  }

  if (action === "decommission") {
    const { error } = await supabase
      .from("device_registry")
      .delete()
      .eq("device_id", deviceId);

    if (error) {
      console.error("device_registry delete error:", error);
      return jsonResponse({ error: "Failed to delete device row" }, 500);
    }

    console.info("Decommissioned device", { deviceId });
    return jsonResponse({ ok: true, action, deviceId }, 200);
  }

  if (action === "rename") {
    const newDeviceId = body.newDeviceId!.trim();

    // Verify the new device_id isn't already taken
    const { data: existing, error: checkError } = await supabase
      .from("device_registry")
      .select("device_id")
      .eq("device_id", newDeviceId)
      .maybeSingle();

    if (checkError) {
      console.error("device_registry check error:", checkError);
      return jsonResponse({ error: "Failed to check new device id" }, 500);
    }
    if (existing) {
      return jsonResponse(
        { error: "newDeviceId already exists in registry", newDeviceId },
        409,
      );
    }

    const { error } = await supabase.rpc("rename_device", {
      p_old_id: deviceId,
      p_new_id: newDeviceId,
    });

    if (error) {
      console.error("rename_device RPC error:", error);
      return jsonResponse({ error: "Failed to rename device" }, 500);
    }

    console.info("Renamed device", { from: deviceId, to: newDeviceId });
    return jsonResponse({ ok: true, action, deviceId, newDeviceId }, 200);
  }

  // action === "purge"
  const { error } = await supabase.rpc("purge_device", {
    p_device_id: deviceId,
  });

  if (error) {
    console.error("purge_device RPC error:", error);
    return jsonResponse({ error: "Failed to purge device" }, 500);
  }

  console.info("Purged device", { deviceId });
  return jsonResponse({ ok: true, action, deviceId }, 200);
});
