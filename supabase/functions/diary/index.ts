import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'jsr:@supabase/supabase-js@2'

// --- TYPE DEFINITIONS ---
interface DiaryEntry {
  entryid: string;
  location_name: string;
  is_participatory: boolean;
  event_type: string;
  context: string;
  other_comments?: string;
  timestamp: string;
}

interface DiaryBatch {
  uid: string;
  date: string;
  entries: DiaryEntry[];
}

interface DatabaseRow {
  deviceid: string; // From the batch UID
  location_ref: string;
  activity: string;
  is_confirmed: boolean;
  context_details: string;
  user_notes: string;
  created_at: string; // Using the timestamp from the phone
}

console.info("Diary Batch Server Started");

Deno.serve(async (req) => {
  // 1. Setup Supabase Client
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? ''
  );

  try {
    // 2. Parse the incoming Batch
    const batch: DiaryBatch = await req.json();

    if (!batch.entries || !Array.isArray(batch.entries)) {
      throw new Error("Invalid batch format: 'entries' must be an array.");
    }

    // 3. Transform Batch into Database Rows
    const db_ready_rows: DatabaseRow[] = batch.entries.map((item: DiaryEntry) => {
      const hasValidComment = item.other_comments && item.other_comments.trim().length > 0;

      return {
        deviceid: batch.uid,
        location_ref: item.entryid,
        activity: item.event_type,
        is_confirmed: item.is_participatory,
        context_details: item.context,
        user_notes: hasValidComment 
          ? item.other_comments!.trim() 
          : "No additional comments provided.",
        created_at: item.timestamp
      };
    });

    console.info(`Inserting ${db_ready_rows.length} entries for user ${batch.uid}`);

    // 4. Bulk Insert to Database
    const { data, error } = await supabase
      .from('diary_entries')
      .insert(db_ready_rows)
      .select(); // Returns the inserted rows

    if (error) throw error;

    return new Response(
      JSON.stringify({ message: "Batch saved successfully", count: data.length }),
      { status: 201, headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("Batch Processing Error:", err.message);
    
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }
});
