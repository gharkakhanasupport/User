import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const USER_DB_URL = Deno.env.get("USER_DB_URL")!;
const USER_SERVICE_ROLE_KEY = Deno.env.get("USER_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  try {
    const payload = await req.json();
    const { record, type, table } = payload;

    const userClient = createClient(USER_DB_URL, USER_SERVICE_ROLE_KEY);

    if (table === "delivery_orders" && type === "UPDATE") {
      // Map delivery status back to the main order status
      // Mapping example: 'picked_up' -> 'OUT_FOR_DELIVERY', 'delivered' -> 'DELIVERED'
      let mainStatus = record.status;
      if (record.status === "picked_up") mainStatus = "OUT_FOR_DELIVERY";
      if (record.status === "delivered") mainStatus = "DELIVERED";

      const { error } = await userClient
        .from("orders")
        .update({
          status: mainStatus,
          delivery_status: record.status, // Store the detailed delivery status too
          delivered_at: record.delivered_at,
        })
        .eq("id", record.source_order_id);

      if (error) console.error(`Error syncing delivery status back to User DB: ${error.message}`);
      else console.log(`Synced delivery status for order ${record.source_order_id} back to User DB`);
    }

    return new Response(JSON.stringify({ success: true }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    console.error("Delivery Sync Back Error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
