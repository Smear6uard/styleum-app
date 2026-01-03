// Supabase Edge Function: generate-outfits
//
// Generates outfit recommendations using:
// 1. Candidate generation (anchor-based, O(N) not O(N^3))
// 2. Rules-based pre-filtering
// 3. Claude Haiku scoring via OpenRouter
//
// Cost: ~$0.002 per generation
// Latency: 500-900ms

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ============================================
// TYPES
// ============================================

interface GenerationRequest {
  user_id: string;
  weather?: {
    temp_f: number;
    condition: string;
    humidity?: number;
    wind_mph?: number;
    description?: string;
  };
  preferences?: {
    style_goal?: string;
    avoid_colors?: string[];
    preferred_styles?: string[];
    boldness_level?: number;
    occasion?: string;
    time_of_day?: string;
  };
  recently_worn_ids?: string[];
  target_count?: number;
}

interface WardrobeItem {
  id: string;
  category: string;
  photo_url: string;
  primary_color: string;
  item_name?: string;
  material?: string;
  style_bucket?: string;
  formality?: string;
  seasonality?: string;
  times_worn?: number;
  dense_caption?: string;
  vibe_scores?: Record<string, number>;
}

interface OutfitCandidate {
  top: WardrobeItem;
  bottom: WardrobeItem;
  shoes: WardrobeItem;
  outerwear?: WardrobeItem;
}

// ============================================
// CANDIDATE GENERATION
// ============================================

function generateCandidates(
  wardrobe: WardrobeItem[],
  weather: GenerationRequest['weather'],
  recentlyWornIds: Set<string>,
  maxCandidates: number = 30
): OutfitCandidate[] {
  const tops = wardrobe.filter(i => i.category === 'top');
  const bottoms = wardrobe.filter(i => i.category === 'bottom');
  const shoes = wardrobe.filter(i => i.category === 'shoes');
  const outerwear = wardrobe.filter(i => i.category === 'outerwear');

  if (tops.length === 0 || bottoms.length === 0 || shoes.length === 0) {
    return [];
  }

  // Select anchors (tops not recently worn, weather-appropriate)
  const anchorTops = tops
    .filter(t => !recentlyWornIds.has(t.id))
    .filter(t => isWeatherAppropriate(t, weather))
    .slice(0, 5);

  // Fallback if all were recently worn
  if (anchorTops.length === 0) {
    anchorTops.push(...tops.slice(0, 3));
  }

  const candidates: OutfitCandidate[] = [];
  const seen = new Set<string>();

  for (const top of anchorTops) {
    const compatibleBottoms = bottoms
      .filter(b => !colorsClash(top.primary_color, b.primary_color))
      .filter(b => formalitiesCompatible(top.formality, b.formality))
      .filter(b => isWeatherAppropriate(b, weather));

    for (const bottom of compatibleBottoms.slice(0, 6)) {
      const compatibleShoes = shoes
        .filter(s => isWeatherAppropriate(s, weather));

      for (const shoe of compatibleShoes.slice(0, 3)) {
        const key = `${top.id}_${bottom.id}_${shoe.id}`;
        if (seen.has(key)) continue;
        seen.add(key);

        const candidate: OutfitCandidate = { top, bottom, shoes: shoe };

        // Add outerwear if needed
        if (weather && needsJacket(weather) && outerwear.length > 0) {
          const jacket = outerwear.find(o =>
            formalitiesCompatible(top.formality, o.formality) &&
            isWeatherAppropriate(o, weather)
          );
          if (jacket) {
            candidate.outerwear = jacket;
          }
        }

        candidates.push(candidate);

        if (candidates.length >= maxCandidates) {
          return candidates;
        }
      }
    }
  }

  return candidates;
}

// ============================================
// RULES HELPERS
// ============================================

const HARD_CLASHES: Record<string, string[]> = {
  'neon_green': ['neon_pink', 'neon_orange'],
  'neon_pink': ['neon_green', 'neon_yellow'],
  'neon_orange': ['neon_green', 'neon_purple'],
};

const NEUTRALS = new Set([
  'black', 'white', 'gray', 'grey', 'navy', 'beige',
  'cream', 'tan', 'brown', 'charcoal', 'ivory', 'khaki'
]);

function colorsClash(c1?: string, c2?: string): boolean {
  if (!c1 || !c2) return false;
  const color1 = c1.toLowerCase().replace(' ', '_');
  const color2 = c2.toLowerCase().replace(' ', '_');

  if (NEUTRALS.has(color1) || NEUTRALS.has(color2)) {
    return false;
  }

  return HARD_CLASHES[color1]?.includes(color2) ||
         HARD_CLASHES[color2]?.includes(color1) ||
         false;
}

function formalitiesCompatible(f1?: string, f2?: string): boolean {
  if (!f1 || !f2) return true;

  const levels: Record<string, number> = {
    'very_casual': 1, 'casual': 2, 'smart_casual': 3, 'business': 4, 'formal': 5
  };

  const l1 = levels[f1] || 2;
  const l2 = levels[f2] || 2;

  return Math.abs(l1 - l2) <= 2;
}

function isWeatherAppropriate(item: WardrobeItem, weather?: GenerationRequest['weather']): boolean {
  if (!weather) return true;

  const temp = weather.temp_f;
  const seasonality = item.seasonality;
  const material = item.material;

  // Summer items in cold weather
  if (seasonality === 'summer' && temp < 50) return false;

  // Winter items in hot weather
  if (seasonality === 'winter' && temp > 85) return false;

  // Heavy materials in hot weather
  if (material && ['wool', 'fleece', 'cashmere'].includes(material) && temp > 80) {
    return false;
  }

  // Linen in cold weather
  if (material === 'linen' && temp < 45) return false;

  return true;
}

function needsJacket(weather: NonNullable<GenerationRequest['weather']>): boolean {
  return weather.temp_f < 65 || weather.condition === 'rainy';
}

// ============================================
// CLAUDE HAIKU SCORING
// ============================================

async function scoreWithHaiku(
  candidates: OutfitCandidate[],
  weather: GenerationRequest['weather'],
  preferences: GenerationRequest['preferences'],
  topN: number
): Promise<Array<{
  index: number;
  score: number;
  why_it_works: string;
  styling_tip?: string;
  vibes: string[];
}>> {
  const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY");

  if (!OPENROUTER_API_KEY) {
    // Return rule-based fallback
    return candidates.slice(0, topN).map((_, i) => ({
      index: i,
      score: 80 - i * 5,
      why_it_works: "A well-coordinated outfit.",
      vibes: []
    }));
  }

  const systemPrompt = `You are a sharp, friendly personal stylist with editorial taste. Evaluate outfit combinations and explain why they work in a warm, confident tone.

Style Guidelines:
- Be specific about WHY pieces work together (colors, textures, silhouettes)
- Keep explanations under 25 words - punchy, not preachy
- Use fashion-forward but accessible language
- Sound like a stylish friend, not a robot

${preferences?.style_goal ? `User's style goal: ${preferences.style_goal}` : ""}

Output Format (CRITICAL - respond ONLY with valid JSON array):
[
  {
    "index": 0,
    "score": 85,
    "why_it_works": "The structured blazer balances the relaxed denim perfectly.",
    "styling_tip": "Roll the sleeves for extra polish.",
    "vibes": ["effortless", "polished"]
  }
]

Rules:
- score: 0-100 (how well this outfit works)
- why_it_works: 15-25 words max
- styling_tip: optional, 10 words max
- vibes: 1-3 single-word descriptors`;

  const candidateDescriptions = candidates.slice(0, 20).map((c, i) => {
    const parts = [
      `[${i}]`,
      `Top: ${c.top.dense_caption || c.top.item_name || c.top.primary_color + ' ' + c.top.category}`,
      `Bottom: ${c.bottom.dense_caption || c.bottom.item_name || c.bottom.primary_color + ' ' + c.bottom.category}`,
      `Shoes: ${c.shoes.dense_caption || c.shoes.item_name || c.shoes.primary_color + ' ' + c.shoes.category}`,
    ];
    if (c.outerwear) {
      parts.push(`Outerwear: ${c.outerwear.dense_caption || c.outerwear.item_name || c.outerwear.primary_color}`);
    }
    return parts.join('\n');
  }).join('\n---\n');

  const userPrompt = `${weather ? `CONTEXT: ${weather.temp_f}°F, ${weather.description || weather.condition}` : ''}
${preferences?.occasion ? `OCCASION: ${preferences.occasion}` : ''}

OUTFIT OPTIONS:
${candidateDescriptions}

Select the TOP ${topN} outfits. Return ONLY a JSON array, no other text.`;

  try {
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://styleum.app",
        "X-Title": "Styleum",
      },
      body: JSON.stringify({
        model: "anthropic/claude-3-haiku-20240307",
        max_tokens: 1500,
        temperature: 0.7,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      }),
    });

    if (!response.ok) {
      console.error("OpenRouter error:", await response.text());
      throw new Error(`OpenRouter API error: ${response.status}`);
    }

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content || "[]";

    // Parse JSON from response
    let jsonStr = content.trim();

    // Extract JSON if wrapped in markdown
    const jsonMatch = jsonStr.match(/```(?:json)?\s*([\s\S]*?)\s*```/);
    if (jsonMatch) {
      jsonStr = jsonMatch[1];
    }

    // Find JSON array bounds
    const start = jsonStr.indexOf("[");
    const end = jsonStr.lastIndexOf("]");
    if (start !== -1 && end > start) {
      jsonStr = jsonStr.substring(start, end + 1);
    }

    const parsed = JSON.parse(jsonStr);
    return parsed;
  } catch (e) {
    console.error("Haiku scoring error:", e);
    // Return rule-based fallback
    return candidates.slice(0, topN).map((_, i) => ({
      index: i,
      score: 80 - i * 5,
      why_it_works: "A well-coordinated outfit.",
      vibes: []
    }));
  }
}

// ============================================
// MAIN HANDLER
// ============================================

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();

  try {
    const request = await req.json() as GenerationRequest;
    const { user_id, weather, preferences, recently_worn_ids, target_count } = request;

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: "user_id required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Initialize Supabase
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Fetch wardrobe
    const { data: wardrobe, error: wardrobeError } = await supabase
      .from("wardrobe_items")
      .select(`
        id, category, photo_url, primary_color, item_name,
        material, style_bucket, formality, seasonality, times_worn,
        dense_caption, vibe_scores
      `)
      .eq("user_id", user_id);

    if (wardrobeError) {
      throw new Error(`Failed to fetch wardrobe: ${wardrobeError.message}`);
    }

    if (!wardrobe || wardrobe.length < 5) {
      return new Response(
        JSON.stringify({
          error: "insufficient_wardrobe",
          message: `Need at least 5 items, have ${wardrobe?.length || 0}`,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Generate candidates
    const recentlyWornSet = new Set(recently_worn_ids || []);
    const candidates = generateCandidates(wardrobe, weather, recentlyWornSet);

    if (candidates.length === 0) {
      return new Response(
        JSON.stringify({
          error: "no_valid_combinations",
          message: "Could not generate valid outfit combinations. Need tops, bottoms, and shoes.",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Score with Haiku
    const targetN = target_count || 6;
    const scoredResults = await scoreWithHaiku(candidates, weather, preferences, targetN);

    // Build response
    const outfits = scoredResults.map(result => {
      const candidate = candidates[result.index];
      return {
        id: `${candidate.top.id}_${candidate.bottom.id}_${candidate.shoes.id}_${Date.now()}`,
        top: candidate.top,
        bottom: candidate.bottom,
        shoes: candidate.shoes,
        outerwear: candidate.outerwear,
        score: result.score,
        why_it_works: result.why_it_works,
        styling_tip: result.styling_tip,
        vibes: result.vibes,
      };
    });

    const latencyMs = Date.now() - startTime;

    return new Response(
      JSON.stringify({
        outfits,
        metadata: {
          candidates_generated: candidates.length,
          latency_ms: latencyMs,
          wardrobe_size: wardrobe.length,
        },
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Generation error:", error);
    return new Response(
      JSON.stringify({ error: "Generation failed", message: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
