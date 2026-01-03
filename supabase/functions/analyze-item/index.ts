// Supabase Edge Function: analyze-item
// 
// The "Eye + Brain" of Styleum's AI tagging system
// 
// Pipeline:
// 1. Florence-2 (via Replicate) → Dense caption + OCR
// 2. Marqo-FashionSigLIP (via Replicate) → 512-dim embedding  
// 3. Gemini 1.5 Flash → Chain-of-thought reasoning for era/vibe
// 4. pgvector → Match to vibe clusters
//
// Cost: ~$0.01-0.02 per item (one-time at upload)
// Latency: 2-3 seconds

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ============================================
// TYPES
// ============================================

interface AnalysisRequest {
  item_id: string;
  image_url: string;
  user_context?: string; // "thrifted in Tokyo", "my grandma's"
}

interface Florence2Output {
  dense_caption: string;
  ocr_text: string | null;
  detected_objects: string[];
}

interface GeminiAnalysis {
  era: {
    detected: string;
    confidence: number;
    reasoning: string;
  };
  vibes: Array<{
    name: string;
    confidence: number;
  }>;
  construction: {
    material_guess: string;
    quality_signals: string[];
    notable_details: string[];
  };
  is_unorthodox: boolean;
  unorthodox_description?: string;
  tags: string[];
  style_bucket: string;
  formality: string;
  seasonality: string;
}

// ============================================
// FLORENCE-2: Dense Captioning + OCR
// ============================================

async function runFlorence2(imageUrl: string): Promise<Florence2Output> {
  const REPLICATE_API_KEY = Deno.env.get("REPLICATE_API_KEY");
  
  if (!REPLICATE_API_KEY) {
    throw new Error("REPLICATE_API_KEY not configured");
  }

  // Florence-2-large on Replicate
  const response = await fetch("https://api.replicate.com/v1/predictions", {
    method: "POST",
    headers: {
      "Authorization": `Token ${REPLICATE_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      version: "da53547e17d45b9cfb48174b2f18af8b83ca020fa76db62136bf9c6616762595",
      input: {
        image: imageUrl,
        task: "<MORE_DETAILED_CAPTION>",
      },
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    console.error("Florence-2 error:", error);
    throw new Error(`Florence-2 failed: ${response.status}`);
  }

  const prediction = await response.json();
  
  // Poll for completion
  let result = prediction;
  while (result.status !== "succeeded" && result.status !== "failed") {
    await new Promise(resolve => setTimeout(resolve, 1000));
    const pollResponse = await fetch(result.urls.get, {
      headers: { "Authorization": `Token ${REPLICATE_API_KEY}` },
    });
    result = await pollResponse.json();
  }

  if (result.status === "failed") {
    throw new Error(`Florence-2 prediction failed: ${result.error}`);
  }

  const rawOutput = result.output;
  const denseCaption = typeof rawOutput === 'string'
    ? rawOutput
    : (rawOutput?.["<MORE_DETAILED_CAPTION>"] || String(rawOutput) || "");

  // Run OCR task separately
  let ocrText: string | null = null;
  try {
    const ocrResponse = await fetch("https://api.replicate.com/v1/predictions", {
      method: "POST",
      headers: {
        "Authorization": `Token ${REPLICATE_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        version: "da53547e17d45b9cfb48174b2f18af8b83ca020fa76db62136bf9c6616762595",
        input: {
          image: imageUrl,
          task: "<OCR>",
        },
      }),
    });

    if (ocrResponse.ok) {
      let ocrResult = await ocrResponse.json();
      while (ocrResult.status !== "succeeded" && ocrResult.status !== "failed") {
        await new Promise(resolve => setTimeout(resolve, 500));
        const pollResponse = await fetch(ocrResult.urls.get, {
          headers: { "Authorization": `Token ${REPLICATE_API_KEY}` },
        });
        ocrResult = await pollResponse.json();
      }
      if (ocrResult.status === "succeeded" && ocrResult.output) {
        const rawOcr = ocrResult.output;
        ocrText = typeof rawOcr === 'string'
          ? rawOcr
          : (rawOcr?.["<OCR>"] || null);
      }
    }
  } catch (e) {
    // OCR failed, continuing without
  }

  return {
    dense_caption: denseCaption,
    ocr_text: ocrText,
    detected_objects: [], // Florence-2 detailed caption includes this
  };
}

// ============================================
// SIGLIP: Generate Embedding
// ============================================

async function generateEmbedding(imageUrl: string): Promise<number[]> {
  const REPLICATE_API_KEY = Deno.env.get("REPLICATE_API_KEY");

  if (!REPLICATE_API_KEY) {
    throw new Error("REPLICATE_API_KEY not configured");
  }

  try {
    const response = await fetch("https://api.replicate.com/v1/predictions", {
      method: "POST",
      headers: {
        "Authorization": `Token ${REPLICATE_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        version: "9065d1d42f60c4e2b7c2aa5a68c5935c84a3ad56e946826bffae3fd0eec8f7e9",
        input: {
          image: imageUrl,
        },
      }),
    });

    if (!response.ok) {
      console.error("Embedding generation failed:", response.status);
      return [];
    }

    const prediction = await response.json();

    // Poll for completion
    let result = prediction;
    while (result.status !== "succeeded" && result.status !== "failed") {
      await new Promise(resolve => setTimeout(resolve, 500));
      const pollResponse = await fetch(result.urls.get, {
        headers: { "Authorization": `Token ${REPLICATE_API_KEY}` },
      });
      result = await pollResponse.json();
    }

    if (result.status === "failed") {
      console.error("Embedding prediction failed:", result.error);
      return [];
    }

    return result.output || [];
  } catch (e) {
    console.error("Embedding error:", e);
    return [];
  }
}

// ============================================
// GEMINI 1.5 FLASH: Chain-of-Thought Reasoning
// ============================================

async function analyzeWithGemini(
  denseCaption: string,
  ocrText: string | null,
  userContext: string | null,
  imageUrl: string,
  supabase?: any,
  userId?: string
): Promise<GeminiAnalysis> {
  const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY");

  if (!OPENROUTER_API_KEY) {
    throw new Error("OPENROUTER_API_KEY not configured");
  }

  const systemPrompt = `You are an expert fashion archivist, vintage authenticator, and subculture historian. Your task is to analyze clothing items with forensic precision.

## Your Analysis Process

### Step 1: Forensic Visual Analysis
- Silhouette: Is it boxy (80s-90s), fitted (2000s), hourglass (50s), oversized (current)?
- Construction: Single-stitch vs double-stitch hems, type of seams, hardware quality
- Fabric indicators: Sheen, texture, drape visible in description
- Hardware: Zipper type (Talon = pre-1980, YKK = post-1970), button style, closures

### Step 2: OCR Evidence (if available)
- Brand names and their era of operation
- "Made in USA" (common pre-1990s), "Made in China" (common post-1990s)
- Union labels (ILGWU, ACWA = vintage)
- Care instruction format (RN numbers, symbols vs text)

### Step 3: Cultural Correlation
- Connect visual features to specific subcultures and aesthetics
- Consider: grunge, punk, preppy, bohemian, minimalist, maximalist, quiet luxury, Y2K, cottagecore, dark academia, streetwear, avant-garde, gorpcore, ballet-core, coastal grandmother, old money, indie sleaze

### Step 4: Unorthodox Detection
- Does this item defy standard categorization?
- Is it deconstructed, upcycled, DIY, avant-garde?
- If unorthodox: describe what you see without forcing it into a category

## Output Format (JSON only, no markdown)
{
  "era": {
    "detected": "1970s" | "1980s" | "1990s" | "Y2K" | "2010s" | "modern" | "unknown",
    "confidence": 0.0-1.0,
    "reasoning": "Brief explanation of evidence"
  },
  "vibes": [
    {"name": "vibe_name", "confidence": 0.0-1.0}
  ],
  "construction": {
    "material_guess": "denim" | "cotton" | "silk" | "wool" | "synthetic" | "leather" | "linen" | "unknown",
    "quality_signals": ["list of quality indicators observed"],
    "notable_details": ["distressing", "hardware type", "unique features"]
  },
  "is_unorthodox": true | false,
  "unorthodox_description": "Only if is_unorthodox is true",
  "tags": ["searchable", "keyword", "tags"],
  "style_bucket": "casual" | "smart_casual" | "business_casual" | "formal" | "streetwear" | "athleisure" | "bohemian" | "minimalist" | "edgy" | "preppy" | "avant_garde",
  "formality": "very_casual" | "casual" | "smart_casual" | "business" | "formal",
  "seasonality": "summer" | "winter" | "spring_fall" | "all_season"
}`;

  // Few-shot personalization - query user's previous corrections
  let fewShotContext = "";
  try {
    if (supabase && userId) {
      const { data: corrections } = await supabase
        .from("tag_corrections")
        .select("field_corrected, ai_value, user_value")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(5);

      if (corrections && corrections.length > 0) {
        fewShotContext = `

## PERSONALIZATION CONTEXT
This user has previously corrected AI predictions:
`;
        for (const c of corrections) {
          fewShotContext += `- ${c.field_corrected}: AI said "${c.ai_value}" → User corrected to "${c.user_value}"\n`;
        }
        fewShotContext += `
Adjust your predictions based on this user's preferences.
`;
      }
    }
  } catch (e) {
    // Could not fetch corrections for few-shot
  }

  const userPrompt = `Analyze this clothing item:

## Visual Description (from Florence-2):
${denseCaption}

${ocrText ? `## Text Found on Item (OCR):
${ocrText}` : "## No text/labels detected"}

${userContext ? `## User Context:
"${userContext}"` : ""}

Provide your forensic analysis as JSON only.`;

  const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENROUTER_API_KEY}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://styleum.app",
      "X-Title": "Styleum",
    },
    body: JSON.stringify({
      model: "google/gemini-2.0-flash-001",
      messages: [
        { role: "user", content: systemPrompt + fewShotContext + "\n\n" + userPrompt },
      ],
      temperature: 0.3,
      max_tokens: 1500,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenRouter API error: ${response.status} - ${error}`);
  }

  const data = await response.json();
  const content = data.choices?.[0]?.message?.content;

  if (!content) {
    throw new Error("Empty response from OpenRouter");
  }

  // Parse JSON from response
  let jsonStr = content.trim();
  
  // Extract JSON if wrapped in markdown
  const jsonMatch = jsonStr.match(/```(?:json)?\s*([\s\S]*?)\s*```/);
  if (jsonMatch) {
    jsonStr = jsonMatch[1];
  }
  
  // Find JSON object bounds
  const start = jsonStr.indexOf("{");
  const end = jsonStr.lastIndexOf("}");
  if (start !== -1 && end > start) {
    jsonStr = jsonStr.substring(start, end + 1);
  }

  try {
    return JSON.parse(jsonStr) as GeminiAnalysis;
  } catch (e) {
    console.error("Failed to parse Gemini response:", content);
    // Return safe defaults
    return {
      era: { detected: "unknown", confidence: 0.3, reasoning: "Unable to determine" },
      vibes: [{ name: "casual", confidence: 0.5 }],
      construction: { material_guess: "unknown", quality_signals: [], notable_details: [] },
      is_unorthodox: false,
      tags: [],
      style_bucket: "casual",
      formality: "casual",
      seasonality: "all_season",
    };
  }
}

// ============================================
// VIBE MATCHING
// ============================================

async function matchVibes(
  supabase: any,
  embedding: number[]
): Promise<Record<string, number>> {
  const { data: vibeMatches, error } = await supabase.rpc("match_item_to_vibes", {
    item_embedding: embedding,
    match_threshold: 0.5,
    max_vibes: 5,
  });

  if (error) {
    console.error("Vibe matching error:", error);
    return {};
  }

  const vibeScores: Record<string, number> = {};
  for (const match of vibeMatches || []) {
    vibeScores[match.vibe_name] = match.similarity;
  }

  return vibeScores;
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
    const { item_id, image_url, user_context } = await req.json() as AnalysisRequest;

    if (!item_id || !image_url) {
      return new Response(
        JSON.stringify({ error: "item_id and image_url required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Initialize Supabase
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Step 1: Run Florence-2 for dense caption + OCR
    const florence2Output = await runFlorence2(image_url);

    // Step 2: Generate embedding
    const embedding = await generateEmbedding(image_url);

    // Step 3: Run Gemini for chain-of-thought analysis
    // Get user_id from the item for personalization
    let itemUserId: string | undefined;
    try {
      const { data: itemData } = await supabase
        .from("wardrobe_items")
        .select("user_id")
        .eq("id", item_id)
        .single();
      itemUserId = itemData?.user_id;
    } catch (e) {
      // Could not fetch item user_id
    }

    const geminiAnalysis = await analyzeWithGemini(
      florence2Output.dense_caption,
      florence2Output.ocr_text,
      user_context || null,
      image_url,
      supabase,
      itemUserId
    );

    // Step 4: Match to vibe clusters
    const vibeScores = await matchVibes(supabase, embedding);

    // Merge Gemini vibes with vector-based vibes
    const mergedVibeScores = { ...vibeScores };
    for (const vibe of geminiAnalysis.vibes) {
      const existing = mergedVibeScores[vibe.name] || 0;
      // Average the two signals
      mergedVibeScores[vibe.name] = (existing + vibe.confidence) / (existing ? 2 : 1);
    }

    // Step 5: Update the database
    const updateData = {
      embedding: embedding,
      ai_metadata: {
        florence2: florence2Output,
        gemini: geminiAnalysis,
        analyzed_at: new Date().toISOString(),
      },
      dense_caption: florence2Output.dense_caption,
      ocr_text: florence2Output.ocr_text,
      vibe_scores: mergedVibeScores,
      era_detected: geminiAnalysis.era.detected,
      era_confidence: geminiAnalysis.era.confidence,
      is_unorthodox: geminiAnalysis.is_unorthodox,
      unorthodox_description: geminiAnalysis.unorthodox_description,
      construction_notes: geminiAnalysis.construction.notable_details.join(", "),
      
      // Standard fields
      material: geminiAnalysis.construction.material_guess,
      style_bucket: geminiAnalysis.style_bucket,
      formality: geminiAnalysis.formality,
      seasonality: geminiAnalysis.seasonality,
      tags: geminiAnalysis.tags,
    };

    const { error: updateError } = await supabase
      .from("wardrobe_items")
      .update(updateData)
      .eq("id", item_id);

    if (updateError) {
      throw new Error(`Database update failed: ${updateError.message}`);
    }

    const latencyMs = Date.now() - startTime;

    return new Response(
      JSON.stringify({
        success: true,
        item_id,
        analysis: {
          dense_caption: florence2Output.dense_caption,
          ocr_text: florence2Output.ocr_text,
          era: geminiAnalysis.era,
          vibes: mergedVibeScores,
          construction: geminiAnalysis.construction,
          is_unorthodox: geminiAnalysis.is_unorthodox,
          unorthodox_description: geminiAnalysis.unorthodox_description,
          tags: geminiAnalysis.tags,
          style_bucket: geminiAnalysis.style_bucket,
          formality: geminiAnalysis.formality,
          seasonality: geminiAnalysis.seasonality,
        },
        metadata: {
          latency_ms: latencyMs,
        },
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Analysis error:", error);
    return new Response(
      JSON.stringify({ error: "Analysis failed", message: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
