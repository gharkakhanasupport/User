import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const WEBHOOK_SECRET = Deno.env.get("WEBHOOK_SECRET") || "panda2026";

interface RazorpayEvent {
  event: string;
  payload: {
    payment: {
      entity: {
        id: string;
        amount: number;
        currency: string;
        status: string;
        notes: {
          user_id?: string;
          order_id?: string;
          order_type?: string;
          wallet_id?: string;
          kitchen_id?: string;
          agent_id?: string;
          payment_type?: string;
        };
      };
    };
  };
}

serve(async (req) => {
  try {
    const signature = req.headers.get("X-Razorpay-Signature");
    const bodyText = await req.text();

    if (!signature) {
      return new Response("Missing signature", { status: 400 });
    }

    // In a real env, implement HMAC signature verification here.
    
    const payload = JSON.parse(bodyText);
    const event = payload.event;
    
    // Language Support Function
    const getResponseMessage = (status: string, langUser?: string) => {
      const messages = {
        'success': {
          'en': 'Webhook processed successfully',
          'hi': 'वेबहुक सफलतापूर्वक संसाधित किया गया',
          'bn': 'ওয়েबहुক সফলভাবে প্রক্রিয়া করা হয়েছে'
        },
        'error': {
          'en': 'An error occurred',
          'hi': 'एक त्रुटि हुई',
          'bn': 'একটি ত্রুটি ঘটেছে'
        }
      };
      const lang = (langUser && ['en', 'hi', 'bn'].includes(langUser)) ? langUser : 'en';
      return messages[status][lang];
    };

    const userLang = req.headers.get("Accept-Language")?.substring(0, 2) || 'en';

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") || "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
    );

    if (event === "payment.captured") {
      const payment = payload.payload.payment.entity;
      const notes = payment.notes || {};
      const amount = payment.amount / 100; // paise to rupees

      // --------------------------------------------------------------------------------
      // PHASE A & C: ONLINE ORDER CAPTURED -> SPLIT FUNDS & UPDATE STATUS
      // --------------------------------------------------------------------------------
      if (notes.order_type === "food_order" && notes.payment_type === "online") {
        const orderId = notes.order_id;
        
        // 1. Update User DB Order Status -> PAID
        await supabase
          .from("orders")
          .update({ payment_status: 'paid', status: 'confirmed' })
          .eq("id", orderId);

        // 2. Fetch the order details for the split calculation
        const { data: order } = await supabase
          .from("orders")
          .select("kitchen_id, total_amount, delivery_fee")
          .eq("id", orderId)
          .single();

        if (order) {
          const totalA = order.total_amount;
          const deliveryR = order.delivery_fee || 30.0;
          const commission = totalA * 0.10; // 10% platform fee
          const kitchenK = totalA - (commission + deliveryR);

          // 3. (Ledger) Credit Kitchen Wallet
          await supabase.from("kitchen_wallet_transactions").insert({
            kitchen_id: order.kitchen_id,
            amount: kitchenK,
            type: "credit",
            reference: payment.id,
            description: "Order Payout for \"
          });

          // 4. (Ledger) The rider wallet credit happens when DELIVERED via app RPC.
        }
      }

      // --------------------------------------------------------------------------------
      // PHASE D: RIDER SETTLES DUES (PAYING BACK NEGATIVE COD BALANCE)
      // --------------------------------------------------------------------------------
      if (notes.order_type === "agent_settlement" && notes.agent_id) {
        // Driver paid the platform to clear negative COD balance
        await supabase.from("agent_wallets").update({ balance: 0 }).eq("agent_id", notes.agent_id);
        
        await supabase.from("wallet_transactions").insert({
          wallet_id: notes.agent_id,
          amount: amount,
          type: "credit",
          reference: payment.id,
          description: "COD Dues Settlement"
        });
      }
    }

    return new Response(JSON.stringify({ 
      success: true, 
      message: getResponseMessage('success', userLang)
    }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ 
      error: error.message || getResponseMessage('error')
    }), { 
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
});
