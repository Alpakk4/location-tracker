
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "supabase"
import { getCategory } from "../_shared/place-types.ts";
import { calculateDisplacement } from "../_shared/displacement.ts";

async function idHasher(text:string) {
  const msgUint8 = new TextEncoder().encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgUint8);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return hashHex;
}

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

console.info('server started');

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

  const { uid, lat, long, home_lat, home_long, motion, horizontal_accuracy, capturedAt } = body;

  if (typeof uid !== "string" || !uid) {
    return jsonResponse({ error: "uid must be a non-empty string" }, 400);
  }
  if (typeof lat !== "number" || !isFinite(lat) || lat < -90 || lat > 90) {
    return jsonResponse({ error: "lat must be a number between -90 and 90" }, 400);
  }
  if (typeof long !== "number" || !isFinite(long) || long < -180 || long > 180) {
    return jsonResponse({ error: "long must be a number between -180 and 180" }, 400);
  }
  if (home_lat != null && (typeof home_lat !== "number" || !isFinite(home_lat) || home_lat < -90 || home_lat > 90)) {
    return jsonResponse({ error: "home_lat must be a number between -90 and 90" }, 400);
  }
  if (home_long != null && (typeof home_long !== "number" || !isFinite(home_long) || home_long < -180 || home_long > 180)) {
    return jsonResponse({ error: "home_long must be a number between -180 and 180" }, 400);
  }
  if (motion == null) {
    return jsonResponse({ error: "motion is required" }, 400);
  }
  if (horizontal_accuracy != null && (typeof horizontal_accuracy !== "number" || !isFinite(horizontal_accuracy))) {
    return jsonResponse({ error: "horizontal_accuracy must be a number" }, 400);
  }
  if (capturedAt != null && typeof capturedAt !== "string") {
    return jsonResponse({ error: "capturedAt must be an ISO 8601 string" }, 400);
  }

  const MAPS_API = Deno.env.get("MAPS_API");
  if (!MAPS_API) {
    return jsonResponse({ error: "Maps API key not configured" }, 503);
  }

  console.info("ping request received", { uidPresent: Boolean(uid), hasHome: home_lat != null && home_long != null });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: device, error: deviceError } = await supabase
    .from("device_registry")
    .select("device_id")
    .eq("device_id", uid)
    .maybeSingle();

  if (deviceError) {
    console.error("device_registry lookup failed:", deviceError.message);
    return jsonResponse({ error: "Unknown device" }, 403);
  }
  if (!device) {
    return jsonResponse({ error: "Unknown device" }, 403);
  }

  const maps_base = "https://places.googleapis.com/v1/places:searchNearby";
  const maps_body = {
    maxResultCount: 5,
    rankPreference: "DISTANCE",
    locationRestriction: {
      circle: {
        center: {
          latitude: lat,
          longitude: long
        },
        radius: 200.0
      }
    }
  };

  // Default home (e.g. London) when client doesn't send home; override via env.
  const DEFAULT_HOME_LAT_FALLBACK = 51.503349370657986;
  const DEFAULT_HOME_LONG_FALLBACK = -0.0868719398915672;
  const defaultHomeLat = (() => {
    const v = Deno.env.get("DEFAULT_HOME_LAT");
    if (v == null || v === "") return DEFAULT_HOME_LAT_FALLBACK;
    const n = parseFloat(v);
    return isFinite(n) ? n : DEFAULT_HOME_LAT_FALLBACK;
  })();
  const defaultHomeLong = (() => {
    const v = Deno.env.get("DEFAULT_HOME_LONG");
    if (v == null || v === "") return DEFAULT_HOME_LONG_FALLBACK;
    const n = parseFloat(v);
    return isFinite(n) ? n : DEFAULT_HOME_LONG_FALLBACK;
  })();

  const hasUserHome = home_lat != null && home_long != null;
  const effectiveHomeLat = hasUserHome ? home_lat : (isFinite(defaultHomeLat) ? defaultHomeLat : null);
  const effectiveHomeLong = hasUserHome ? home_long : (isFinite(defaultHomeLong) ? defaultHomeLong : null);

  const displacement = (effectiveHomeLat != null && effectiveHomeLong != null)
    ? calculateDisplacement(effectiveHomeLat, effectiveHomeLong, lat, long)
    : null;
  const isAtHome = hasUserHome && displacement != null && displacement.distance <= 30;

  console.info("Fetching nearby places");
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 10_000);

  let maps_res: Response;
  try {
    maps_res = await fetch(maps_base, {
      body: JSON.stringify(maps_body),
      headers: {
        "X-Goog-Api-Key": MAPS_API,
        "X-Goog-FieldMask": "places.displayName,places.primaryType,places.types,places.id,places.location",
        "Content-Type": "application/json"
      },
      method: "POST",
      signal: controller.signal
    });
  } catch (err: unknown) {
    if (err instanceof DOMException && err.name === "AbortError") {
      return jsonResponse({ error: "Places API timeout" }, 504);
    }
    return jsonResponse({ error: "Places API request failed" }, 502);
  } finally {
    clearTimeout(timeoutId);
  }

  console.info("Places API response", maps_res.status);
  if (maps_res.status !== 200) {
    console.warn("Places API non-200:", maps_res.status);
    return jsonResponse({ error: "Places API error" }, 502);
  }

  const maps_data = await maps_res.json();
  const firstPlace = maps_data.places?.[0];
  
  let primary_place_distance: number | null = null;
  if (firstPlace?.location?.latitude != null && firstPlace?.location?.longitude != null) {
    const placeDisp = calculateDisplacement(
      lat,
      long,
      firstPlace.location.latitude,
      firstPlace.location.longitude
    );
    primary_place_distance = placeDisp.distance;
  }
  
  const possible_places = maps_data.places?.slice(1) ?? [];
  const possible_primary_types = possible_places.map((place: any) => place.primaryType);
  const possible_places_distances = possible_places
    .map((place: any) => {
      if (place.location?.latitude != null && place.location?.longitude != null) {
        const placeDisp = calculateDisplacement(
          lat,
          long,
          place.location.latitude,
          place.location.longitude
        );
        return placeDisp.distance;
      }
      return null;
    })
    .filter((distance: number | null): distance is number => distance !== null);

  const primary_type = isAtHome ? "home" : (firstPlace?.primaryType ?? "Unknown");
  const place_category = primary_type === "home" ? "Home" : getCategory(primary_type);

  const hashedPlaceId = firstPlace?.id ? await idHasher(firstPlace.id) : "Unknown";

  if (firstPlace?.id) {
    const { error: placeError } = await supabase
      .from("places")
      .upsert({
        hashed_google_id: hashedPlaceId,
        place_name: firstPlace.displayName?.text ?? null,
        primary_type: firstPlace.primaryType ?? null,
        other_types: firstPlace.types ?? [],
      }, { onConflict: "hashed_google_id" });
    if (placeError) {
      console.warn("places upsert failed:", placeError.message);
    }
  }

  const db_body: Record<string, unknown> = {
    deviceid: uid,
    motion_type: motion,
    primary_type,
    place_category,
    other_types: firstPlace?.types ?? [],
    possible_primary_types,
    placeid: hashedPlaceId,
    position_from_home: displacement,
    horizontal_accuracy: horizontal_accuracy ?? null,
    distance_user_to_place: primary_place_distance,
    possible_places_distances,
  };

  if (capturedAt) {
    db_body.created_at = capturedAt;
  }

  console.info("Saving resolved ping record");

  const { error: insertError } = await supabase
    .from("locationsvisitednew")
    .insert([db_body]);

  if (insertError) {
    console.error("insert failed:", insertError.message);
    return jsonResponse({ error: "insert failed" }, 502);
  }

  console.info("ping stored");
  return jsonResponse({ status: "ok" }, 201);
});
