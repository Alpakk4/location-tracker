
// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
// define values
// radius of earth in haversine calculations
const R = 6371e3;
// Define Helper functions
// Degrees to radian helper function to be called in haversine calculations
function calculateDisplacement(lat1:number, lon1:number, lat2:number, lon2:number) {
  const toRad = (deg:number) => (deg * Math.PI) / 180;

  const φ1 = toRad(lat1);
  const φ2 = toRad(lat2);
  const Δφ = toRad(lat2 - lat1);
  const Δλ = toRad(lon2 - lon1);

  // Haversine Distance
  const a = Math.sin(Δφ / 2) ** 2 +
            Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) ** 2;
  const distance = R * (2 * Math.atan2(Math.sqrt(Math.min(1, a)), Math.sqrt(Math.max(0, 1 - a))));

  // Bearing
  const y = Math.sin(Δλ) * Math.cos(φ2);
  const x = Math.cos(φ1) * Math.sin(φ2) -
            Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);
  const bearing = (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;

  // Cartesian offsets from home (flat-earth projection, valid within ~50km)
  const x_m = parseFloat((distance * Math.sin(bearing * Math.PI / 180)).toFixed(2)); // east-west offset in metres
  const y_m = parseFloat((distance * Math.cos(bearing * Math.PI / 180)).toFixed(2)); // north-south offset in metres

  return { 
    distance: parseFloat(distance.toFixed(2)), 
    bearing: parseFloat(bearing.toFixed(4)),
    x_m,
    y_m
  };
};

//SHA256 hasher
async function idHasher(text:string) {
  // 1. Encode the string into bytes (Uint8Array)
  const msgUint8 = new TextEncoder().encode(text);
  // 2. Compute the hash (returns an ArrayBuffer)
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgUint8);
  // 3. Convert buffer to a hex string
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
    
  return hashHex;
};


//INFORM ON STARTUP
console.info('server started');
//DEFINE PING LOCATION FUNCTION
Deno.serve(async (req) => {
  const { uid, lat, long, home_lat, home_long, motion, horizontal_accuracy } = await req.json();
  const MAPS_API = Deno.env.get("MAPS_API")!;
  console.info("ping request received", { uidPresent: Boolean(uid), hasHome: home_lat != null && home_long != null });
  const maps_base = "https://places.googleapis.com/v1/places:searchNearby";
  const maps_body = {
    maxResultCount: 5, //max number of places to return
    rankPreference: "DISTANCE",
    locationRestriction: {
      circle: { //circle search
        center: {
          latitude: lat, // centred on lat and long
          longitude: long
        },
        radius: 50.0 //search radius in metres
      }
    }
  };
  // Calculate the displacement and bearing
  const displacement = (home_lat != null && home_long != null)
    ? calculateDisplacement(home_lat, home_long, lat, long)
    : null;
  // Check if the ping is at home location, or within 30 metres
  const isAtHome = displacement != null && displacement.distance <= 30; // 30 metres

  console.info("Fetching nearby places");
  const maps_res = await fetch(maps_base, {
    body: JSON.stringify(maps_body),
    headers: {
      "X-Goog-Api-Key": MAPS_API,
      // Requesting displayName, primaryType, types, the unique ID, and location
      "X-Goog-FieldMask": "places.displayName,places.primaryType,places.types,places.id,places.location",
      "Content-Type": "application/json"
    },
    method: "POST"
  });

  console.info("Places API response", maps_res.status);
  if (maps_res.status != 200) {
    console.warn(maps_res);
    return new Response(null, {
      status: 502
    });
  };
  const maps_data = await maps_res.json();
  // Write location to database
  // 1. Grab the first place object safely
  const firstPlace = maps_data.places?.[0];
  
  // Calculate distance to primary place
  let primary_place_distance: number | null = null;
  if (firstPlace?.location?.latitude != null && firstPlace?.location?.longitude != null) {
    const displacement = calculateDisplacement(
      lat,
      long,
      firstPlace.location.latitude,
      firstPlace.location.longitude
    );
    primary_place_distance = displacement.distance;
  }
  
  // 2. Grab the other primary type places objects safely and calculate distances
  const possible_places = maps_data.places?.slice(1) ?? []; // Skips the first element (index 0)
  const possible_primary_types = possible_places.map(place => place.primaryType);
  const possible_places_distances = possible_places
    .map(place => {
      if (place.location?.latitude != null && place.location?.longitude != null) {
        const displacement = calculateDisplacement(
          lat,
          long,
          place.location.latitude,
          place.location.longitude
        );
        return displacement.distance;
      }
      return null;
    })
    .filter((distance): distance is number => distance !== null);

    // 2. Build the body using the array directly
  const db_body = {
    // These variables were outputted in the original function but won't be written to database
    latitude: lat,
    longitude: long,
    deviceid: uid,
    motion_type: motion,
    closest_place: firstPlace?.displayName?.text ?? "Unknown",
    primary_type: isAtHome ? "home" : (firstPlace?.primaryType ?? "Unknown"),
    // Pass the array directly. If it doesn't exist, send an empty array []
    other_types: firstPlace?.types ?? [], 
    possible_primary_types: possible_primary_types,
    // pass the placeid if it doesn't exist say unknown
    placeid: firstPlace?.id ? await idHasher(firstPlace.id) : "Unknown",
    position_from_home: displacement,
    horizontal_accuracy: horizontal_accuracy ?? null,
    distance_user_to_place: primary_place_distance,
    possible_places_distances: possible_places_distances
  };
  console.info("Saving resolved ping record");
  const db_res = await fetch(Deno.env.get("SUPABASE_URL") + "/rest/v1/locationsvisitednew", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": Deno.env.get("SUPABASE_ANON_KEY")!
    },
    body: JSON.stringify(db_body)
  });
  if (db_res.status != 201) {
    console.info("upstream insert failed", db_res.status);
    return new Response(JSON.stringify({
      "upstream_status": db_res.status,
      "upstream_response": await db_res.json()
    }), {
      status: 502
    });
  }
  console.info("ping stored");
  return db_res;
});

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/ping' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
