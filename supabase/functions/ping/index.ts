// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

console.info('server started');
Deno.serve(async (req) => {
  const { uid, lat, long } = await req.json();
  const MAPS_API = Deno.env.get("MAPS_API")!;
  console.info("maps api: " + MAPS_API);
  console.info("info from request", uid, lat, long);
  const maps_base = "https://places.googleapis.com/v1/places:searchNearby";
  const maps_body = {
    maxResultCount: 1,
    rankPreference: "POPULARITY",
    locationRestriction: {
      circle: {
        center: {
          latitude: lat,
          longitude: long
        },
        radius: 50.0
      }
    }
  };
  console.info("DEBUG 1: Fetching maps");
  const maps_res = await fetch(maps_base, {
    body: JSON.stringify(maps_body),
    headers: {
      "X-Goog-Api-Key": MAPS_API,
      "X-Goog-FieldMask": "places.displayName",
      "Content-Type": "application/json"
    },
    method: "POST"
  });
  console.info("DEBUG 2: Fetched maps OK", maps_res.status);
  if (maps_res.status != 200) {
    console.warn(maps_res);
    return new Response(null, {
      status: 502
    });
  }
  const maps_data = await maps_res.json();
  console.info("DEBUG 3: Got maps data:", maps_data);
  // Write location to database
  const db_body = {
    latitude: lat,
    longitude: long,
    DeviceID: uid,
    closest_place: maps_data["places"] == undefined ? "unknown" : maps_data["places"][0]["displayName"]["text"]
  };
  console.info("DEBUG 4: SAVING to DB", db_body);
  const db_res = await fetch(Deno.env.get("SUPABASE_URL") + "/rest/v1/locationsvisited", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": Deno.env.get("SUPABASE_ANON_KEY")!
    },
    body: JSON.stringify(db_body)
  });
  if (db_res.status != 201) {
    console.info("DEBUG 5: ALERT Sending 502 because previous result not 201", db_res);
    return new Response(JSON.stringify({
      "upstream_status": db_res.status,
      "upstream_response": await db_res.json()
    }), {
      status: 502
    });
  }
  console.info("DEBUG 6: everything is dandy");
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
