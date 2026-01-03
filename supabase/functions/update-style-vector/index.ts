// Supabase Edge Function: update-style-vector
//
// Active Learning Engine - Updates the User Style Vector
// Called after every meaningful interaction:
// - "Wear This Today" tap (+1.0)
// - Like/Save (+0.5)
// - Reject outfit (-0.5)
// - Tag edit (+2.0 - highest signal)
// - Vibe confirm (+1.5)
// - Vibe reject (-1.0)
//
// The magic: over time, the system learns YOUR definition of style

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface InteractionRequest {
  user_id: string;
  item_id?: string;
  outfit_id?: string;
  interaction_type: 
    | "wear" 
    | "like" 
    | "save" 
    | "reject" 
    | "skip" 
    | "tag_edit" 
    | "vibe_confirm" 
    | "vibe_reject";
  context?: {
    occasion?: string;
    weather?: string;
    old_value?: string;
    new_value?: string;
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { 
      user_id, 
      item_id, 
      outfit_id, 
      interaction_type, 
      context 
    } = await req.json() as InteractionRequest;

    if (!user_id || !interaction_type) {
      return new Response(
        JSON.stringify({ error: "user_id and interaction_type required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!item_id && !outfit_id) {
      return new Response(
        JSON.stringify({ error: "Either item_id or outfit_id required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get item embedding(s)
    let embeddings: number[][] = [];
    let itemIds: string[] = [];

    if (item_id) {
      // Single item interaction
      const { data: item, error } = await supabase
        .from("wardrobe_items")
        .select("id, embedding")
        .eq("id", item_id)
        .single();

      if (error || !item?.embedding) {
        return new Response(
          JSON.stringify({ error: "Item not found or has no embedding" }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      embeddings.push(item.embedding);
      itemIds.push(item.id);
    } else if (outfit_id) {
      // Outfit interaction - get all items in the outfit
      // Outfit ID format: "topId_bottomId_shoesId_timestamp"
      const parts = outfit_id.split("_");
      if (parts.length >= 3) {
        const ids = parts.slice(0, 3);
        
        const { data: items, error } = await supabase
          .from("wardrobe_items")
          .select("id, embedding")
          .in("id", ids);

        if (error || !items?.length) {
          return new Response(
            JSON.stringify({ error: "Outfit items not found" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        for (const item of items) {
          if (item.embedding) {
            embeddings.push(item.embedding);
            itemIds.push(item.id);
          }
        }
      }
    }

    if (embeddings.length === 0) {
      return new Response(
        JSON.stringify({ error: "No valid embeddings found" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Calculate weight based on interaction type
    const baseWeights: Record<string, number> = {
      wear: 1.0,
      like: 0.5,
      save: 0.5,
      reject: -0.5,
      skip: -0.1,
      tag_edit: 2.0,
      vibe_confirm: 1.5,
      vibe_reject: -1.0,
    };

    const weight = baseWeights[interaction_type] || 0.5;

    // Update style vector for each item
    for (const embedding of embeddings) {
      const { error: updateError } = await supabase.rpc("update_user_style_vector", {
        p_user_id: user_id,
        p_item_embedding: embedding,
        p_interaction_type: interaction_type,
        p_weight: weight,
      });

      if (updateError) {
        console.error("Style vector update error:", updateError);
      }
    }

    // Log the interaction
    for (const id of itemIds) {
      await supabase.from("style_interactions").insert({
        user_id,
        item_id: id,
        outfit_id,
        interaction_type,
        item_embedding: embeddings[itemIds.indexOf(id)],
        context: context || {},
        old_value: context?.old_value,
        new_value: context?.new_value,
        weight: Math.abs(weight),
      });
    }

    // If this was a tag edit, also log to tag_corrections for fine-tuning data
    if (interaction_type === "tag_edit" && context?.old_value && context?.new_value && item_id) {
      const { data: item } = await supabase
        .from("wardrobe_items")
        .select("embedding, dense_caption")
        .eq("id", item_id)
        .single();

      await supabase.from("tag_corrections").insert({
        user_id,
        item_id,
        field_corrected: "vibe", // Could be more specific based on context
        ai_value: context.old_value,
        user_value: context.new_value,
        item_embedding: item?.embedding,
        dense_caption: item?.dense_caption,
      });
    }

    // Get updated style vector summary
    const { data: styleVector } = await supabase
      .from("user_style_vectors")
      .select("total_interactions, dominant_vibes, last_interaction_at")
      .eq("user_id", user_id)
      .single();

    return new Response(
      JSON.stringify({
        success: true,
        interaction_type,
        items_affected: itemIds.length,
        weight_applied: weight,
        total_interactions: styleVector?.total_interactions || 0,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Interaction error:", error);
    return new Response(
      JSON.stringify({ error: "Failed to process interaction", message: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
