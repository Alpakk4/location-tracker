// diary-submit: receives completed diary entries from the iOS app and updates
// the pre-populated rows in the diary_completed table. Returns 200 on success.

import { serve } from "std/http/server.ts"
import { createClient } from "supabase"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // 1. Parse and validate request body
    const body = await req.json().catch(() => null)
    if (!body) {
      return new Response(JSON.stringify({ error: "Missing JSON body" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const { deviceId, date, entries } = body
    if (!deviceId || !date || !Array.isArray(entries) || entries.length === 0) {
      return new Response(
        JSON.stringify({ error: "Missing deviceId, date, or entries array" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    // 2. Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")

    if (!supabaseUrl || !supabaseKey) {
      console.error("Missing Environment Variables")
      return new Response(
        JSON.stringify({ error: "Server configuration error" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

    const supabase = createClient(supabaseUrl, supabaseKey)

    console.info(
      `Submitting diary for device: ${deviceId}, date: ${date}, entries: ${entries.length}`
    )

    // 3. Update pre-populated rows with user answers
    for (const entry of entries as {
      source_entryid: string
      activity_label: string
      confirmed_place: boolean
      confirmed_activity: boolean
      user_context: string | null
    }[]) {
      const { error } = await supabase
        .from("diary_completed")
        .update({
          activity_label: entry.activity_label,
          confirmed_place: entry.confirmed_place,
          confirmed_activity: entry.confirmed_activity,
          user_context: entry.user_context,
        })
        .eq("visit_id", entry.source_entryid)
        .eq("deviceid", deviceId)
        .eq("diary_date", date)

      if (error) {
        console.error(`Update error for visit ${entry.source_entryid}:`, error)
        return new Response(JSON.stringify({ error: error.message }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        })
      }
    }

    // 4. Return 200 OK
    return new Response(
      JSON.stringify({ success: true, updated: entries.length }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  } catch (err) {
    console.error("Unexpected Error:", err.message)
    return new Response(
      JSON.stringify({ error: "Internal Server Error", details: err.message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})
