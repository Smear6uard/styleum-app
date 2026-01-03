import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Get active users (engaged in last 7 days)
    const { data: activeUsers, error: userError } = await supabase
      .from("profiles")
      .select("id")
      .gte("updated_at", new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString());

    if (userError) throw userError;

    const results: Array<{user_id: string, status: string, reason?: string, error?: string, outfit_count?: number}> = [];
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = tomorrow.toISOString().split("T")[0];

    for (const user of activeUsers || []) {
      // Check if queue already exists for tomorrow
      const { data: existing } = await supabase
        .from("daily_queue")
        .select("id")
        .eq("user_id", user.id)
        .eq("date", tomorrowStr)
        .single();

      if (existing) {
        results.push({ user_id: user.id, status: "skipped", reason: "already_exists" });
        continue;
      }

      // Call generate-outfits for this user
      try {
        const { data: outfits, error: genError } = await supabase.functions.invoke(
          "generate-outfits",
          {
            body: {
              user_id: user.id,
              occasion: "daily",
              count: 4,
            },
          }
        );

        if (genError) {
          results.push({ user_id: user.id, status: "error", error: genError.message });
          continue;
        }

        // Store in daily_queue
        await supabase.from("daily_queue").insert({
          id: crypto.randomUUID(),
          user_id: user.id,
          date: tomorrowStr,
          outfits: outfits,
          generated_at: new Date().toISOString(),
        });

        results.push({ user_id: user.id, status: "success", outfit_count: outfits?.length || 0 });
      } catch (e) {
        results.push({ user_id: user.id, status: "error", error: (e as Error).message });
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        processed: activeUsers?.length || 0,
        results,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
