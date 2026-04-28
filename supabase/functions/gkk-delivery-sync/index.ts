import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const USER_DB_URL = Deno.env.get("USER_DB_URL")!;
const USER_SERVICE_ROLE_KEY = Deno.env.get("USER_SERVICE_ROLE_KEY")!;
const KITCHEN_DB_URL = Deno.env.get("KITCHEN_DB_URL")!;
const KITCHEN_SERVICE_ROLE_KEY = Deno.env.get("KITCHEN_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  try {
    const payload = await req.json();
    const { record, type, table } = payload;

    const userClient = createClient(USER_DB_URL, USER_SERVICE_ROLE_KEY);
    const kitchenClient = createClient(KITCHEN_DB_URL, KITCHEN_SERVICE_ROLE_KEY);

    if (table === "delivery_orders" && type === "UPDATE") {
      // Map delivery status back to the main order status
      // Mapping example: 'picked_up' -> 'OUT_FOR_DELIVERY', 'delivered' -> 'DELIVERED'
      let mainStatus = record.status;
      if (record.status === "picked_up") mainStatus = "OUT_FOR_DELIVERY";
      if (record.status === "delivered") mainStatus = "DELIVERED";

      const updateData: Record<string, unknown> = {
        status: mainStatus,
        delivery_status: record.status, // Store the detailed delivery status too
        updated_at: new Date().toISOString(),
      };

      if (record.delivered_at) updateData.delivered_at = record.delivered_at;
      if (record.completed_at) updateData.completed_at = record.completed_at;
      if (record.delivery_partner_id) updateData.delivery_partner_id = record.delivery_partner_id;
      if (record.current_location) updateData.current_location = record.current_location;

      // 1. Sync to User DB (so customer tracking screen updates)
      const { error: userError } = await userClient
        .from("orders")
        .update(updateData)
        .eq("id", record.source_order_id);

      if (userError) console.error(`Error syncing delivery status to User DB: ${userError.message}`);
      else console.log(`Synced delivery status "${record.status}" for order ${record.source_order_id} to User DB`);

      // 2. Sync to Kitchen DB (so cook sees delivery progress)
      const { error: kitchenError } = await kitchenClient
        .from("orders")
        .update({ status: mainStatus, updated_at: new Date().toISOString() })
        .eq("id", record.source_order_id);

      if (kitchenError) console.error(`Error syncing delivery status to Kitchen DB: ${kitchenError.message}`);
      else console.log(`Synced delivery status "${mainStatus}" for order ${record.source_order_id} to Kitchen DB`);
    }

    return new Response(JSON.stringify({ success: true }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    console.error("Delivery Sync Back Error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
