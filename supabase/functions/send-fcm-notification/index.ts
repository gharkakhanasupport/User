import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY") || ""; // Or use Firebase Admin SDK JSON

serve(async (req) => {
  try {
    const payload = await req.json();
    const { record, old_record, type, table } = payload;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // E.g. trigger on orders table update
    if (table === "orders" && type === "UPDATE") {
      const oldStatus = old_record?.status;
      const newStatus = record?.status;

      if (oldStatus !== newStatus) {
         // Figure out who to notify
         let targetUserId = null;
         let title = "Order Update";
         let body = "Your order is now \";

         // if it's the customer:
         targetUserId = record.customer_id || record.user_id;

         if (targetUserId) {
            // Get tokens
            const { data: tokens } = await supabase
              .from("unified_fcm_tokens")
              .select("token")
              .eq("user_id", targetUserId);

            if (tokens && tokens.length > 0) {
               // Send to all device tokens of that user
               for (const t of tokens) {
                  await fetch("https://fcm.googleapis.com/fcm/send", {
                    method: "POST",
                    headers: {
                      "Content-Type": "application/json",
                      "Authorization": "key=" + FCM_SERVER_KEY
                    },
                    body: JSON.stringify({
                      to: t.token,
                      notification: { title, body }
                    })
                  });
               }
            }
         }
      }
    }

    return new Response(JSON.stringify({ success: true }), { status: 200, headers: { "Content-Type": "application/json" }});
  } catch (error: any) {
    console.error("Error sending push:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" }});
  }
});
