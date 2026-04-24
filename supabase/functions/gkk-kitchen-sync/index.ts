import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const USER_DB_URL = Deno.env.get("USER_DB_URL")!;
const USER_SERVICE_ROLE_KEY = Deno.env.get("USER_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  try {
    const payload = await req.json();
    const { record, type, table } = payload;

    const userClient = createClient(USER_DB_URL, USER_SERVICE_ROLE_KEY);

    if (table === "orders" && type === "UPDATE") {
      // Sync status and driver info back to User DB
      const { error } = await userClient
        .from("orders")
        .update({
          status: record.status,
          driver_id: record.driver_id,
          estimated_delivery_time: record.estimated_delivery_time,
          kitchen_notes: record.kitchen_notes,
        })
        .eq("id", record.id);

      if (error) console.error(`Error syncing back to User DB: ${error.message}`);
      else console.log(`Synced status for order ${record.id} back to User DB`);
    }

    return new Response(JSON.stringify({ success: true }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    console.error("Sync Back Error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
