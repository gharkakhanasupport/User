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
          app_origin?: string;
          order_type?: string;
          wallet_id?: string;
          kitchen_id?: string;
          agent_id?: string;
        };
      };
    };
  };
}

async function verifySignature(signature: string, bodyText: string, secret: string) {
  const encoder = new TextEncoder();
  const keyInfo = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"]
  );
  
  const signatureBuffer = await crypto.subtle.sign(
    "HMAC",
    keyInfo,
    encoder.encode(bodyText)
  );

  const hashArray = Array.from(new Uint8Array(signatureBuffer));
  const expectedSignature = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  
  return expectedSignature === signature;
}

serve(async (req) => {
  try {
    const signature = req.headers.get("X-Razorpay-Signature");
    const bodyText = await req.text();

    if (!signature) {
      return new Response("Missing signature", { status: 400 });
    }

    // Verify Signature
    const isValid = await verifySignature(signature, bodyText, WEBHOOK_SECRET);

    if (!isValid) {
      return new Response("Invalid signature", { status: 400 });
    }

    const payload: RazorpayEvent = JSON.parse(bodyText);
    const event = payload.event;

    if (event === "payment.captured") {
      const payment = payload.payload.payment.entity;
      const notes = payment.notes || {};
      const amount = payment.amount / 100; // Razorpay sends amount in paise

      // USER DB: Standard Top Up
      if (notes.order_type === "top_up" && notes.wallet_id) {
        const supabase = createClient(
          Deno.env.get("USER_DB_URL") || "",
          Deno.env.get("USER_DB_SERVICE_KEY") || ""
        );

        // Fetch wallet balance
        const { data: wallet, error: walletError } = await supabase
          .from("wallet")
          .select("balance, total_credit_received")
          .eq("id", notes.wallet_id)
          .single();

        if (!walletError && wallet) {
          // Update Wallet Balance
          await supabase
            .from("wallet")
            .update({
              balance: wallet.balance + amount,
              total_credit_received: wallet.total_credit_received + amount,
              updated_at: new Date().toISOString()
            })
            .eq("id", notes.wallet_id);

          // Insert Transaction record
          await supabase
            .from("wallet_transactions")
            .insert({
              wallet_id: notes.wallet_id,
              type: "credit",
              amount: amount,
              description: `Top-up via Razorpay (Ref: ${payment.id})`,
              reference_id: payment.id,
              status: "completed"
            });
        }
      } 
      // KITCHEN / AGENT DB Orchestration
      else if (notes.order_type === "order_payout") {
        if (notes.kitchen_id) {
          const kitchenDb = createClient(
            Deno.env.get("KITCHEN_DB_URL") || "",
            Deno.env.get("KITCHEN_DB_SERVICE_KEY") || ""
          );
          // RPC invocation to update kitchen earnings safely
          await kitchenDb.rpc("increment_kitchen_earnings", {
            p_kitchen_id: notes.kitchen_id,
            p_amount: amount
          });
        }
        
        if (notes.agent_id) {
           const agentDb = createClient(
             Deno.env.get("ADMIN_DB_URL") || "", // Assuming agent DB shares admin or has distinct URL
             Deno.env.get("ADMIN_DB_SERVICE_KEY") || ""
           );
           // Credit agent delivery fee
           await agentDb.rpc("increment_agent_earnings", {
             p_agent_id: notes.agent_id,
             p_amount: 40.00 // Example hardcoded fixed fee from spec
           });
        }
      }
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("Webhook Error", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
