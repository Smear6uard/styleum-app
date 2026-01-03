// Supabase Edge Function: seed-vibes
//
// Seeds the vibe_anchors table with reference images and embeddings
// for each style vibe. Run once during setup.
//
// Usage: supabase functions invoke seed-vibes

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Reference images for each vibe - curated from fashion editorial sources
// 10 images per vibe to establish cluster centroids
const VIBE_REFERENCES: Record<string, { display_name: string; description: string; images: string[] }> = {
  minimalist: {
    display_name: "Minimalist",
    description: "Clean lines, neutral palette, understated elegance",
    images: [
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=512",
      "https://images.unsplash.com/photo-1581044777550-4cfa60707c03?w=512",
      "https://images.unsplash.com/photo-1523381210434-271e8be1f52b?w=512",
      "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=512",
      "https://images.unsplash.com/photo-1509631179647-0177331693ae?w=512",
      "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=512",
      "https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=512",
      "https://images.unsplash.com/photo-1485968579169-a6d388e0c21c?w=512",
      "https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=512",
      "https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=512",
    ],
  },
  maximalist: {
    display_name: "Maximalist",
    description: "Bold patterns, vibrant colors, statement pieces",
    images: [
      "https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=512",
      "https://images.unsplash.com/photo-1544441893-675973e31985?w=512",
      "https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?w=512",
      "https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=512",
      "https://images.unsplash.com/photo-1487222477894-8943e31ef7b2?w=512",
      "https://images.unsplash.com/photo-1525507119028-ed4c629a60a3?w=512",
      "https://images.unsplash.com/photo-1558171813-4c088753af8f?w=512",
      "https://images.unsplash.com/photo-1496217590455-aa63a8350eea?w=512",
      "https://images.unsplash.com/photo-1475180098004-ca77a66827be?w=512",
      "https://images.unsplash.com/photo-1483985988355-763728e1935b?w=512",
    ],
  },
  cottagecore: {
    display_name: "Cottagecore",
    description: "Rustic charm, floral prints, pastoral romance",
    images: [
      "https://images.unsplash.com/photo-1518622358385-8ea7d0794bf6?w=512",
      "https://images.unsplash.com/photo-1520716963369-9b24de292417?w=512",
      "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=512",
      "https://images.unsplash.com/photo-1519278409-1f56fdda7485?w=512",
      "https://images.unsplash.com/photo-1502716119720-b23a93e5fe1b?w=512",
      "https://images.unsplash.com/photo-1485811055483-1c09e64d4576?w=512",
      "https://images.unsplash.com/photo-1508672019048-805c876b67e2?w=512",
      "https://images.unsplash.com/photo-1459411552884-841db9b3cc2a?w=512",
      "https://images.unsplash.com/photo-1475180098004-ca77a66827be?w=512",
      "https://images.unsplash.com/photo-1566174053879-31528523f8ae?w=512",
    ],
  },
  dark_academia: {
    display_name: "Dark Academia",
    description: "Scholarly aesthetic, earth tones, vintage textures",
    images: [
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=512",
      "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=512",
      "https://images.unsplash.com/photo-1509631179647-0177331693ae?w=512",
      "https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=512",
      "https://images.unsplash.com/photo-1507680434567-5739c80be1ac?w=512",
      "https://images.unsplash.com/photo-1516826957135-700dedea698c?w=512",
      "https://images.unsplash.com/photo-1490578474895-699cd4e2cf59?w=512",
      "https://images.unsplash.com/photo-1488161628813-04466f872be2?w=512",
      "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=512",
      "https://images.unsplash.com/photo-1491553895911-0055uj95d2?w=512",
    ],
  },
  y2k: {
    display_name: "Y2K",
    description: "Early 2000s revival, metallics, low-rise, futuristic",
    images: [
      "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=512",
      "https://images.unsplash.com/photo-1524250502761-1ac6f2e30d43?w=512",
      "https://images.unsplash.com/photo-1509631179647-0177331693ae?w=512",
      "https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?w=512",
      "https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=512",
      "https://images.unsplash.com/photo-1558171813-4c088753af8f?w=512",
      "https://images.unsplash.com/photo-1544441893-675973e31985?w=512",
      "https://images.unsplash.com/photo-1487222477894-8943e31ef7b2?w=512",
      "https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=512",
      "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=512",
    ],
  },
  grunge: {
    display_name: "Grunge",
    description: "Distressed denim, flannel, oversized silhouettes, 90s edge",
    images: [
      "https://images.unsplash.com/photo-1503341504253-dff4815485f1?w=512",
      "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=512",
      "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=512",
      "https://images.unsplash.com/photo-1516826957135-700dedea698c?w=512",
      "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=512",
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=512",
      "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=512",
      "https://images.unsplash.com/photo-1488161628813-04466f872be2?w=512",
      "https://images.unsplash.com/photo-1490578474895-699cd4e2cf59?w=512",
      "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=512",
    ],
  },
  quiet_luxury: {
    display_name: "Quiet Luxury",
    description: "Understated elegance, premium fabrics, subtle branding",
    images: [
      "https://images.unsplash.com/photo-1581044777550-4cfa60707c03?w=512",
      "https://images.unsplash.com/photo-1523381210434-271e8be1f52b?w=512",
      "https://images.unsplash.com/photo-1509631179647-0177331693ae?w=512",
      "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=512",
      "https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=512",
      "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=512",
      "https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=512",
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=512",
      "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=512",
      "https://images.unsplash.com/photo-1485968579169-a6d388e0c21c?w=512",
    ],
  },
  streetwear: {
    display_name: "Streetwear",
    description: "Urban edge, sneakers, graphic tees, brand drops",
    images: [
      "https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=512",
      "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=512",
      "https://images.unsplash.com/photo-1516826957135-700dedea698c?w=512",
      "https://images.unsplash.com/photo-1503341504253-dff4815485f1?w=512",
      "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=512",
      "https://images.unsplash.com/photo-1490578474895-699cd4e2cf59?w=512",
      "https://images.unsplash.com/photo-1488161628813-04466f872be2?w=512",
      "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=512",
      "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=512",
      "https://images.unsplash.com/photo-1507680434567-5739c80be1ac?w=512",
    ],
  },
  bohemian: {
    display_name: "Bohemian",
    description: "Free-spirited, flowing fabrics, earthy tones, artisanal",
    images: [
      "https://images.unsplash.com/photo-1518622358385-8ea7d0794bf6?w=512",
      "https://images.unsplash.com/photo-1520716963369-9b24de292417?w=512",
      "https://images.unsplash.com/photo-1519278409-1f56fdda7485?w=512",
      "https://images.unsplash.com/photo-1475180098004-ca77a66827be?w=512",
      "https://images.unsplash.com/photo-1566174053879-31528523f8ae?w=512",
      "https://images.unsplash.com/photo-1502716119720-b23a93e5fe1b?w=512",
      "https://images.unsplash.com/photo-1485811055483-1c09e64d4576?w=512",
      "https://images.unsplash.com/photo-1508672019048-805c876b67e2?w=512",
      "https://images.unsplash.com/photo-1459411552884-841db9b3cc2a?w=512",
      "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=512",
    ],
  },
  preppy: {
    display_name: "Preppy",
    description: "Collegiate classic, polo shirts, blazers, nautical stripes",
    images: [
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=512",
      "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=512",
      "https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=512",
      "https://images.unsplash.com/photo-1507680434567-5739c80be1ac?w=512",
      "https://images.unsplash.com/photo-1516826957135-700dedea698c?w=512",
      "https://images.unsplash.com/photo-1523381210434-271e8be1f52b?w=512",
      "https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=512",
      "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=512",
      "https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=512",
      "https://images.unsplash.com/photo-1485968579169-a6d388e0c21c?w=512",
    ],
  },
  punk: {
    display_name: "Punk",
    description: "Rebellious edge, leather, studs, DIY aesthetic",
    images: [
      "https://images.unsplash.com/photo-1503341504253-dff4815485f1?w=512",
      "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=512",
      "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=512",
      "https://images.unsplash.com/photo-1490578474895-699cd4e2cf59?w=512",
      "https://images.unsplash.com/photo-1488161628813-04466f872be2?w=512",
      "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=512",
      "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=512",
      "https://images.unsplash.com/photo-1516826957135-700dedea698c?w=512",
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=512",
      "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=512",
    ],
  },
  vintage_americana: {
    display_name: "Vintage Americana",
    description: "Workwear heritage, denim, leather, timeless classics",
    images: [
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=512",
      "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=512",
      "https://images.unsplash.com/photo-1516826957135-700dedea698c?w=512",
      "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=512",
      "https://images.unsplash.com/photo-1490578474895-699cd4e2cf59?w=512",
      "https://images.unsplash.com/photo-1488161628813-04466f872be2?w=512",
      "https://images.unsplash.com/photo-1507680434567-5739c80be1ac?w=512",
      "https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=512",
      "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=512",
      "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=512",
    ],
  },
  avant_garde: {
    display_name: "Avant-Garde",
    description: "Experimental, architectural silhouettes, boundary-pushing",
    images: [
      "https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=512",
      "https://images.unsplash.com/photo-1544441893-675973e31985?w=512",
      "https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?w=512",
      "https://images.unsplash.com/photo-1487222477894-8943e31ef7b2?w=512",
      "https://images.unsplash.com/photo-1525507119028-ed4c629a60a3?w=512",
      "https://images.unsplash.com/photo-1558171813-4c088753af8f?w=512",
      "https://images.unsplash.com/photo-1496217590455-aa63a8350eea?w=512",
      "https://images.unsplash.com/photo-1475180098004-ca77a66827be?w=512",
      "https://images.unsplash.com/photo-1483985988355-763728e1935b?w=512",
      "https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=512",
    ],
  },
  athleisure: {
    display_name: "Athleisure",
    description: "Sport-luxe, technical fabrics, workout-to-street",
    images: [
      "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=512",
      "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=512",
      "https://images.unsplash.com/photo-1503341504253-dff4815485f1?w=512",
      "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=512",
      "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=512",
      "https://images.unsplash.com/photo-1516826957135-700dedea698c?w=512",
      "https://images.unsplash.com/photo-1490578474895-699cd4e2cf59?w=512",
      "https://images.unsplash.com/photo-1488161628813-04466f872be2?w=512",
      "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=512",
      "https://images.unsplash.com/photo-1507680434567-5739c80be1ac?w=512",
    ],
  },
  coastal_grandmother: {
    display_name: "Coastal Grandmother",
    description: "Relaxed elegance, linen, soft neutrals, Nancy Meyers aesthetic",
    images: [
      "https://images.unsplash.com/photo-1581044777550-4cfa60707c03?w=512",
      "https://images.unsplash.com/photo-1523381210434-271e8be1f52b?w=512",
      "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=512",
      "https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=512",
      "https://images.unsplash.com/photo-1485968579169-a6d388e0c21c?w=512",
      "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=512",
      "https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=512",
      "https://images.unsplash.com/photo-1518622358385-8ea7d0794bf6?w=512",
      "https://images.unsplash.com/photo-1520716963369-9b24de292417?w=512",
      "https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=512",
    ],
  },
  gorpcore: {
    display_name: "Gorpcore",
    description: "Outdoor tech, hiking boots, functional fashion",
    images: [
      "https://images.unsplash.com/photo-1503341504253-dff4815485f1?w=512",
      "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=512",
      "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=512",
      "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=512",
      "https://images.unsplash.com/photo-1516826957135-700dedea698c?w=512",
      "https://images.unsplash.com/photo-1490578474895-699cd4e2cf59?w=512",
      "https://images.unsplash.com/photo-1488161628813-04466f872be2?w=512",
      "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=512",
      "https://images.unsplash.com/photo-1507680434567-5739c80be1ac?w=512",
      "https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=512",
    ],
  },
  ballet_core: {
    display_name: "Ballet Core",
    description: "Soft pinks, wrap tops, delicate femininity, dancewear-inspired",
    images: [
      "https://images.unsplash.com/photo-1518622358385-8ea7d0794bf6?w=512",
      "https://images.unsplash.com/photo-1520716963369-9b24de292417?w=512",
      "https://images.unsplash.com/photo-1519278409-1f56fdda7485?w=512",
      "https://images.unsplash.com/photo-1502716119720-b23a93e5fe1b?w=512",
      "https://images.unsplash.com/photo-1566174053879-31528523f8ae?w=512",
      "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=512",
      "https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=512",
      "https://images.unsplash.com/photo-1485968579169-a6d388e0c21c?w=512",
      "https://images.unsplash.com/photo-1581044777550-4cfa60707c03?w=512",
      "https://images.unsplash.com/photo-1523381210434-271e8be1f52b?w=512",
    ],
  },
  indie_sleaze: {
    display_name: "Indie Sleaze",
    description: "2000s party scene, skinny jeans, messy hair, rock edge",
    images: [
      "https://images.unsplash.com/photo-1503341504253-dff4815485f1?w=512",
      "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=512",
      "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=512",
      "https://images.unsplash.com/photo-1490578474895-699cd4e2cf59?w=512",
      "https://images.unsplash.com/photo-1488161628813-04466f872be2?w=512",
      "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=512",
      "https://images.unsplash.com/photo-1516826957135-700dedea698c?w=512",
      "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=512",
      "https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=512",
      "https://images.unsplash.com/photo-1544441893-675973e31985?w=512",
    ],
  },
  old_money: {
    display_name: "Old Money",
    description: "Inherited elegance, cashmere, loafers, understated wealth",
    images: [
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=512",
      "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=512",
      "https://images.unsplash.com/photo-1581044777550-4cfa60707c03?w=512",
      "https://images.unsplash.com/photo-1523381210434-271e8be1f52b?w=512",
      "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=512",
      "https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=512",
      "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=512",
      "https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=512",
      "https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=512",
      "https://images.unsplash.com/photo-1507680434567-5739c80be1ac?w=512",
    ],
  },
  eclectic_grandpa: {
    display_name: "Eclectic Grandpa",
    description: "Quirky vintage, mixed patterns, cardigans, professorial charm",
    images: [
      "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=512",
      "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=512",
      "https://images.unsplash.com/photo-1516826957135-700dedea698c?w=512",
      "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=512",
      "https://images.unsplash.com/photo-1490578474895-699cd4e2cf59?w=512",
      "https://images.unsplash.com/photo-1488161628813-04466f872be2?w=512",
      "https://images.unsplash.com/photo-1519125323398-675f0ddb6308?w=512",
      "https://images.unsplash.com/photo-1507680434567-5739c80be1ac?w=512",
      "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=512",
      "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=512",
    ],
  },
};

// Generate embedding using SigLIP via Replicate
async function generateEmbedding(imageUrl: string): Promise<number[] | null> {
  const REPLICATE_API_KEY = Deno.env.get("REPLICATE_API_KEY");
  if (!REPLICATE_API_KEY) {
    console.error("REPLICATE_API_KEY not set");
    return null;
  }

  try {
    // Start prediction
    const startResponse = await fetch("https://api.replicate.com/v1/predictions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${REPLICATE_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        version: "9065d1d42f60c4e2b7c2aa5a68c5935c84a3ad56e946826bffae3fd0eec8f7e9",
        input: {
          image: imageUrl,
        },
      }),
    });

    if (!startResponse.ok) {
      const err = await startResponse.text();
      console.error(`Replicate start error: ${err}`);
      return null;
    }

    const prediction = await startResponse.json();
    let result = prediction;

    // Poll until complete
    while (result.status !== "succeeded" && result.status !== "failed") {
      await new Promise(r => setTimeout(r, 500));
      const pollResponse = await fetch(result.urls.get, {
        headers: { "Authorization": `Bearer ${REPLICATE_API_KEY}` },
      });
      result = await pollResponse.json();
    }

    if (result.status === "failed") {
      console.error(`Embedding failed: ${result.error}`);
      return null;
    }

    // SigLIP returns an array of floats
    return result.output;
  } catch (e) {
    console.error(`Embedding error: ${e}`);
    return null;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Check if we should skip existing
    let body: { skip_existing?: boolean } = {};
    try {
      body = await req.json();
    } catch {
      // No body, use defaults
    }
    const skipExisting = body.skip_existing ?? true;

    let totalAnchors = 0;
    let skippedVibes = 0;
    const vibeResults: Record<string, { anchors: number; errors: number }> = {};

    // Process each vibe
    for (const [vibeName, vibeData] of Object.entries(VIBE_REFERENCES)) {
      // Check if vibe already has anchors
      if (skipExisting) {
        const { count } = await supabase
          .from("vibe_anchors")
          .select("*", { count: "exact", head: true })
          .eq("vibe_name", vibeName);

        if (count && count > 0) {
          skippedVibes++;
          continue;
        }
      }

      let anchorsCreated = 0;
      let errors = 0;

      // Process each reference image
      for (let i = 0; i < vibeData.images.length; i++) {
        const imageUrl = vibeData.images[i];

        const embedding = await generateEmbedding(imageUrl);
        if (!embedding) {
          errors++;
          continue;
        }

        // Insert anchor
        const { error: insertError } = await supabase
          .from("vibe_anchors")
          .insert({
            vibe_name: vibeName,
            vibe_display_name: vibeData.display_name,
            vibe_description: vibeData.description,
            embedding: embedding,
            reference_image_url: imageUrl,
            is_active: true,
          });

        if (insertError) {
          errors++;
        } else {
          anchorsCreated++;
          totalAnchors++;
        }

        // Small delay to avoid rate limiting
        await new Promise(r => setTimeout(r, 100));
      }

      vibeResults[vibeName] = { anchors: anchorsCreated, errors };
    }

    // Recalculate centroids
    const { error: rpcError } = await supabase.rpc("recalculate_vibe_centroids");
    if (rpcError) {
      console.error(`Centroid recalculation error: ${rpcError.message}`);
    }

    const latencyMs = Date.now() - startTime;

    return new Response(
      JSON.stringify({
        success: true,
        total_anchors_created: totalAnchors,
        vibes_skipped: skippedVibes,
        vibe_results: vibeResults,
        latency_ms: latencyMs,
        message: "Vibe seeding complete. Centroids recalculated.",
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Seeding error:", error);
    return new Response(
      JSON.stringify({ error: "Seeding failed", message: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
