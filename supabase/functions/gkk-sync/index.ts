import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Config for all three databases
const USER_DB_URL = Deno.env.get("USER_DB_URL")!;
const USER_SERVICE_ROLE_KEY = Deno.env.get("USER_SERVICE_ROLE_KEY")!;
const KITCHEN_DB_URL = Deno.env.get("KITCHEN_DB_URL")!;
const KITCHEN_SERVICE_ROLE_KEY = Deno.env.get("KITCHEN_SERVICE_ROLE_KEY")!;
const DELIVERY_DB_URL = Deno.env.get("DELIVERY_DB_URL")!;
const DELIVERY_SERVICE_ROLE_KEY = Deno.env.get("DELIVERY_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  try {
    // Basic Security: Check if the request has the correct Service Role Key
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.includes(USER_SERVICE_ROLE_KEY)) {
      console.error("Unauthorized sync attempt");
      return new Response("Unauthorized", { status: 401 });
    }

    const payload = await req.json();
    const { record, old_record, type, table, schema } = payload;

    // Detect which project this came from by looking at the payload or environment
    // But since we use one function for all, we can use the 'table' and 'schema' to decide logic.
    
    const userClient = createClient(USER_DB_URL, USER_SERVICE_ROLE_KEY);
    const kitchenClient = createClient(KITCHEN_DB_URL, KITCHEN_SERVICE_ROLE_KEY);
    const deliveryClient = createClient(DELIVERY_DB_URL, DELIVERY_SERVICE_ROLE_KEY);

    console.log(`Sync event: ${type} on ${table}`);

    // --- LOGIC 1: OUTGOING FROM USER DB ---
    // If the table is 'orders' and it has a 'user_id', it's likely from the User DB
    if (table === "orders" && record.user_id) {
      // Sync to Kitchen
      if (type === "INSERT" || type === "UPDATE") {
        await kitchenClient.from("orders").upsert(record);
        console.log(`Synced order ${record.id} to Kitchen DB`);
      }

      // Sync OTP to Delivery
      if (type === "UPDATE" && record.delivery_otp && record.delivery_otp !== old_record?.delivery_otp) {
        await deliveryClient
          .from("delivery_orders")
          .update({ delivery_otp: record.delivery_otp })
          .eq("source_order_id", record.id);
        console.log(`Synced OTP for order ${record.id} to Delivery DB`);
      }
    }

    // --- LOGIC 2: INCOMING FROM KITCHEN DB ---
    // If the table is 'orders' but it came from the Kitchen DB (Kitchen app updates status)
    // We detect this if the payload is triggered by the Kitchen Webhook
    if (table === "orders" && !record.user_id && record.kitchen_id) {
       await userClient
        .from("orders")
        .update({
          status: record.status,
          driver_id: record.driver_id,
          estimated_delivery_time: record.estimated_delivery_time,
        })
        .eq("id", record.id);
      console.log(`Synced Kitchen update for order ${record.id} back to User DB`);
    }

    // --- LOGIC 3: INCOMING FROM DELIVERY DB ---
    if (table === "delivery_orders") {
      let mainStatus = record.status;
      if (record.status === "picked_up") mainStatus = "OUT_FOR_DELIVERY";
      if (record.status === "delivered") mainStatus = "DELIVERED";

      await userClient
        .from("orders")
        .update({
          status: mainStatus,
          delivery_status: record.status,
          delivered_at: record.delivered_at,
        })
        .eq("id", record.source_order_id);
      console.log(`Synced Delivery update for order ${record.source_order_id} back to User DB`);
    }

    // --- LOGIC 4: SUBSCRIPTION → SUBSCRIBER BRIDGE ---
    // When a user subscribes in User DB, create a corresponding subscriber
    // record in Kitchen DB so the cook sees the new subscriber immediately.
    if (table === "subscriptions") {
      if (type === "INSERT") {
        // Fetch user profile from User DB for name/phone
        let userName = "Subscriber";
        let userPhone = "";
        let userProfileImage = "";

        if (record.user_id) {
          const { data: userData } = await userClient
            .from("users")
            .select("name, phone, profile_image_url")
            .eq("id", record.user_id)
            .maybeSingle();

          if (userData) {
            userName = userData.name || "Subscriber";
            userPhone = userData.phone || "";
            userProfileImage = userData.profile_image_url || "";
          }
        }

        // Resolve cook_id from kitchen_id via Kitchen DB's kitchens table
        let cookId = "";
        if (record.kitchen_id) {
          const { data: kitchenData } = await kitchenClient
            .from("kitchens")
            .select("cook_id")
            .eq("id", record.kitchen_id)
            .maybeSingle();

          // Fallback: kitchen_id might BE the cook_id
          cookId = kitchenData?.cook_id || record.kitchen_id;
        }

        if (cookId) {
          const subscriberData = {
            cook_id: cookId,
            customer_id: record.user_id,
            name: userName,
            phone: userPhone,
            profile_image_url: userProfileImage,
            plan_type: record.plan_type || "monthly",
            start_date: record.start_date,
            end_date: record.end_date,
            todays_meal: "",
            meal_quantity: record.meal_count || 1,
            meal_status: "scheduled",
            status: "new",
          };

          await kitchenClient
            .from("subscribers")
            .upsert(subscriberData, { onConflict: "customer_id,cook_id" });
          console.log(`Synced subscription ${record.id} → Kitchen DB subscribers (cook: ${cookId})`);
        }
      }

      // Handle cancellation — update subscriber status to 'done'
      if (type === "UPDATE" && record.status === "cancelled") {
        if (record.kitchen_id) {
          let cookId = "";
          const { data: kitchenData } = await kitchenClient
            .from("kitchens")
            .select("cook_id")
            .eq("id", record.kitchen_id)
            .maybeSingle();
          cookId = kitchenData?.cook_id || record.kitchen_id;

          if (cookId && record.user_id) {
            await kitchenClient
              .from("subscribers")
              .update({ status: "done" })
              .eq("customer_id", record.user_id)
              .eq("cook_id", cookId);
            console.log(`Subscription cancelled → subscriber marked done for user ${record.user_id}`);
          }
        }
      }
    }

    return new Response(JSON.stringify({ success: true }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    console.error("Sync Error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
