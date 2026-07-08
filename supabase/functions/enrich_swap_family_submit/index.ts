// Supabase Edge Function: enrich_swap_family_submit
//
// EENMALIGE, kleine taak (geen doorlopende cron zoals enrich_batch_submit):
// classificeert ALLEEN swap_family (niet het volledige verrijkingsschema)
// voor representanten die na de gratis regelrondes (compute_swap_family)
// nog steeds geen swap_family hebben. Kleinere prompt dan de hoofd-
// enrichment-pipeline, dus lagere kosten per product.
//
// Handmatig aangeroepen, geen tracking-tabel nodig (geen doorlopende loop) --
// batch_id wordt in de response teruggegeven, gebruik die bij
// enrich_swap_family_collect om de resultaten op te halen zodra de batch klaar is.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

const MODEL = "claude-sonnet-5";
const ANTHROPIC_VERSION = "2023-06-01";

const ALLOWED_SWAP_FAMILIES = [
  "water", "soft_drinks_regular", "soft_drinks_light_zero", "energy_drinks", "sports_drinks",
  "fruit_juices", "smoothies", "hot_beverages", "alcohol_drinks", "fresh_fruit", "fresh_vegetables",
  "bread_bakery", "breakfast_cereals", "granola_muesli", "crackers_rice_cakes", "chocolate_bars",
  "chocolate_confectionery", "candy_sweets", "cookies_biscuits", "cakes_pastries", "cereal_bars",
  "protein_bars", "ice_cream_desserts", "crisps_chips", "popcorn", "nuts_seeds", "cheese_snacks",
  "meat_snacks", "cold_cuts", "yoghurt_skyr_quark", "dairy_desserts", "dairy_drinks", "plant_based_dairy",
  "chocolate_spreads", "nut_butters", "jams_fruit_spreads", "honey_syrups", "sweet_spreads_other",
  "savory_spreads", "hummus_legume_spreads", "sauces_dips", "soups", "meal_components", "ready_meals",
  "sandwiches_wraps", "supplements_powders", "unknown",
];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) return json({ error: "ANTHROPIC_API_KEY ontbreekt." }, 500);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: reps, error: repErr } = await supabase
      .from("product_features")
      .select("barcode, products(name, brand, category, categories_tags, pnns_groups_1, pnns_groups_2)")
      .eq("is_representative", true)
      .eq("is_swap_relevant", true)
      .is("swap_family", null);
    if (repErr) return json({ error: `Representanten ophalen mislukt: ${repErr.message}` }, 500);
    if (!reps || reps.length === 0) {
      return json({ status: "idle", reason: "geen representanten zonder swap_family" });
    }

    const schema = {
      type: "object",
      properties: {
        swap_family: { type: "string", enum: ALLOWED_SWAP_FAMILIES },
        confidence: { type: "number" },
      },
      required: ["swap_family", "confidence"],
      additionalProperties: false,
    };

    const system =
      "Je classificeert supermarktproducten in exact 1 vaste categorie (swap_family) " +
      "voor een voedings-swap-app. Gebruik UITSLUITEND een van de toegestane waarden uit " +
      "het schema -- verzin nooit een nieuwe categorie. Classificeer op functie/gebruik " +
      "(hoe wordt het gegeten/gedronken), niet alleen op smaak. Weet je het niet zeker " +
      "genoeg: kies 'unknown' en geef een lage confidence (0-1). Verander of verzin nooit " +
      "voedingswaarden, allergenen of ingrediënten -- je classificeert alleen.";

    const requests = (reps as any[]).map((r) => {
      const p = r.products ?? {};
      const facts = {
        naam: p.name, merk: p.brand, categorie: p.category,
        categorieen_tags: p.categories_tags, pnns_1: p.pnns_groups_1, pnns_2: p.pnns_groups_2,
      };
      return {
        custom_id: r.barcode,
        params: {
          model: MODEL,
          max_tokens: 150,
          system,
          output_config: { format: { type: "json_schema", schema } },
          messages: [{ role: "user", content: JSON.stringify(facts) }],
        },
      };
    });

    const batchRes = await fetch("https://api.anthropic.com/v1/messages/batches", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": ANTHROPIC_VERSION,
        "content-type": "application/json",
      },
      body: JSON.stringify({ requests }),
    });
    if (!batchRes.ok) {
      const text = await batchRes.text();
      return json({ error: `Anthropic Batch-aanmaak mislukt: ${batchRes.status} ${text}` }, 500);
    }
    const batch = await batchRes.json();
    return json({ status: "submitted", batch_id: batch.id, requested_count: requests.length });
  } catch (e) {
    return json({ error: `Interne fout: ${e}` }, 500);
  }
});
