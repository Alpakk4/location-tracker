// Function to handle diary entries
Deno.serve(async (req) => {
  const { uid, entry, mood, last_location_id } = await req.json();

  const db_body = {
    deviceid: uid,
    entry_text: entry,
    mood: mood,
    location_ref: last_location_id // This links the diary to a specific location ping
  };

  // Push to Supabase...
  return new Response(JSON.stringify({ status: "Diary entry cached" }), { status: 201 });
});
