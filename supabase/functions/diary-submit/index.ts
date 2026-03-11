// diary-submit: thin wrapper around the submit_diary RPC that atomically
// claims the diary (submitted_at IS NULL guard), updates all visit and journey
// rows with user answers, and sets submitted_at — all in one transaction.

import { serve } from "std/http/server.ts"
import { createClient } from "supabase"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const body = await req.json().catch(() => null)
    if (!body) {
      return new Response(JSON.stringify({ error: "Missing JSON body" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const { deviceId, date, entries, journeys } = body
    if (!deviceId || !date || !Array.isArray(entries) || entries.length === 0) {
      return new Response(
        JSON.stringify({ error: "Missing deviceId, date, or entries array" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      )
    }

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

    const journeyCount = Array.isArray(journeys) ? journeys.length : 0
    console.info(
      `Submitting diary for device: ${deviceId}, date: ${date}, entries: ${entries.length}, journeys: ${journeyCount}`
    )

    const { data, error } = await supabase.rpc("submit_diary", {
      p_device_id: deviceId,
      p_date: date,
      p_visit_updates: entries,
      p_journey_updates: Array.isArray(journeys) ? journeys : [],
    })

    if (error) {
      console.error("submit_diary RPC error:", error)

      if (error.message?.includes("diary_not_available")) {
        return new Response(
          JSON.stringify({ error: "Diary not found or already submitted" }),
          {
            status: 409,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        )
      }

      return new Response(JSON.stringify({ error: "Diary submission failed" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    console.info(`Diary submitted: ${JSON.stringify(data)}`)

    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error("Unexpected error:", message)
    return new Response(
      JSON.stringify({ error: "Internal Server Error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    )
  }
})
