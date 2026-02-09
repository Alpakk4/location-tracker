// mock data
/*

[
  {
    "entryid": "775c11c2-11cf-47a5-9ef7-1a653b42ed29",
    "created_at": "2026-02-06T13:25:12.434339+00:00",
    "primary_type": "park",
    "other_types": ["park", "point_of_interest", "establishment"],
    "motion_type": {
      "motion": "walking",
      "confidence": "high"
    }
  },
  {
    "entryid": "c70aefc3-7651-4d6e-810b-66fb4be5054f",
    "created_at": "2026-02-06T13:25:57.99983+00:00",
    "primary_type": "primary_school",
    "other_types": ["primary_school", "school", "point_of_interest", "establishment"],
    "motion_type": {
      "motion": "walking",
      "confidence": "high"
    }
  },
  {
    "entryid": "8e62831e-315f-42e7-a08c-5e9c102f0de2",
    "created_at": "2026-02-06T13:30:11.360599+00:00",
    "primary_type": "cultural_landmark",
    "other_types": ["cultural_landmark", "tourist_attraction", "point_of_interest", "establishment"],
    "motion_type": {
      "motion": "walking",
      "confidence": "high"
    }
  },
  {
    "entryid": "fe868c39-7d7f-4df0-81da-9a06ba720963",
    "created_at": "2026-02-06T13:30:17.187394+00:00",
    "primary_type": "cultural_landmark",
    "other_types": ["cultural_landmark", "tourist_attraction", "point_of_interest", "establishment"],
    "motion_type": {
      "motion": "walking",
      "confidence": "high"
    }
  },
  {
    "entryid": "77048b2a-592b-4863-930d-9523f3b58087",
    "created_at": "2026-02-06T13:30:25.838777+00:00",
    "primary_type": "cultural_landmark",
    "other_types": ["cultural_landmark", "tourist_attraction", "point_of_interest", "establishment"],
    "motion_type": {
      "motion": "walking",
      "confidence": "high"
    }
  },
  {
    "entryid": "08dbacb4-926d-47be-960f-4a7f94b85840",
    "created_at": "2026-02-06T13:32:23.923443+00:00",
    "primary_type": "Unknown",
    "other_types": ["point_of_interest", "establishment"],
    "motion_type": {
      "motion": "cycling",
      "confidence": "medium"
    }
  },
  {
    "entryid": "4f7f5e98-8414-4d1b-b87b-cd933fb09aa9",
    "created_at": "2026-02-06T13:32:30.385424+00:00",
    "primary_type": "Unknown",
    "other_types": ["point_of_interest", "establishment"],
    "motion_type": {
      "motion": "cycling",
      "confidence": "medium"
    }
  },
  {
    "entryid": "aeb0adc0-ed30-45f7-9d46-2cd4e3da2f63",
    "created_at": "2026-02-06T13:32:36.40137+00:00",
    "primary_type": "Unknown",
    "other_types": ["point_of_interest", "establishment"],
    "motion_type": {
      "motion": "cycling",
      "confidence": "medium"
    }
  },
  {
    "entryid": "8b085e63-d10f-40be-a27b-1156fab70c28",
    "created_at": "2026-02-06T13:32:43.661549+00:00",
    "primary_type": "Unknown",
    "other_types": ["point_of_interest", "establishment"],
    "motion_type": {
      "motion": "cycling",
      "confidence": "medium"
    }
  },
  {
    "entryid": "10a95590-e518-41ba-a544-c7594b8167aa",
    "created_at": "2026-02-06T13:33:08.132168+00:00",
    "primary_type": "Unknown",
    "other_types": ["point_of_interest", "establishment"],
    "motion_type": {
      "motion": "cycling",
      "confidence": "high"
    }
  },
  {
    "entryid": "74418800-f3f2-4a3a-81e3-f8daa08100da",
    "created_at": "2026-02-06T13:34:28.76573+00:00",
    "primary_type": "Unknown",
    "other_types": ["point_of_interest", "establishment"],
    "motion_type": {
      "motion": "cycling",
      "confidence": "high"
    }
  },
  {
    "entryid": "3a2932c6-18d0-4f5e-afe5-c41ff2f00e2c",
    "created_at": "2026-02-06T13:36:37.760741+00:00",
    "primary_type": "Unknown",
    "other_types": ["point_of_interest", "establishment"],
    "motion_type": {
      "motion": "cycling",
      "confidence": "high"
    }
  },
  {
    "entryid": "acc6d74d-0a71-4315-a982-e20701da20be",
    "created_at": "2026-02-06T13:39:45.871436+00:00",
    "primary_type": "Unknown",
    "other_types": ["point_of_interest", "establishment"],
    "motion_type": {
      "motion": "cycling",
      "confidence": "high"
    }
  },
  {
    "entryid": "2bbd920e-acce-4553-a73e-e39e499ddd58",
    "created_at": "2026-02-06T13:47:29.403305+00:00",
    "primary_type": "Unknown",
    "other_types": [],
    "motion_type": {
      "motion": "cycling",
      "confidence": "high"
    }
  },
  {
    "entryid": "df1101f2-e5b3-4a70-a1af-b9c285807022",
    "created_at": "2026-02-06T13:52:36.131288+00:00",
    "primary_type": "subway_station",
    "other_types": ["subway_station", "transit_station", "point_of_interest", "establishment"],
    "motion_type": {
      "motion": "still",
      "confidence": "high"
    }
  }
]
  */
// Diary builderf logic for diary construction

import { serve } from "std/http/server.ts"
import { createClient } from "supabase"

serve(async (req) => {
  // 1. Handle CORS (if calling from a browser/mobile app later)
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

    // 3. Initialize Supabase with safety checks
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseKey) {
      console.error("Missing Environment Variables");
      return new Response(JSON.stringify({ error: "Server configuration error" }), { status: 500 });
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    console.info(`Fetching diary for: ${deviceId} on ${date}`);

    // 4. Query the database
    const { data, error } = await supabase
      .from('locationsvisitednew')
      .select(`
        entryid,
        created_at,
        primary_type,
        position_from_home,
        other_types,
        motion_type
      `)
      .eq('deviceid', deviceId)
      .gte('created_at', `${date}T00:00:00Z`)
      .lte('created_at', `${date}T23:59:59Z`)
      .order('created_at', { ascending: true });

    if (error) {
      console.error("Supabase Error:", error);
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }

    // 5. Return Data
    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*" 
      },
    });

  } catch (err) {
    console.error("Unexpected Error:", err.message);
    return new Response(JSON.stringify({ error: "Internal Server Error", details: err.message }), { 
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
})