// Supabase Edge Function: enrich_batch_submit
//
// Verzamelt alle nog-niet-verrijkte swap-representanten, bouwt per product
// een Claude-classificatievraag (vocab-begrensd via output_config.format),
// en dient ALLES in als één Anthropic Message Batch (async, -50% kosten).
//
// EENMALIGE LOOP: draait alleen als ai_enrichment_control.auto_enrich_enabled
// = true. Wordt automatisch op false gezet zodra de volledige eerste run +
// kwaliteitscheck klaar zijn (zie enrich_batch_collect). Nieuwe verrijking
// pas weer na expliciete herstart.
//
// FOUTAFHANDELING: bij elke fout wacht deze functie minstens 3 uur voor een
// nieuwe poging (last_submit_error_at-afkoeling). Na 5 mislukte pogingen
// schakelt de eenmalige loop zichzelf uit i.p.v. eindeloos te blijven proberen.
//
// BELANGRIJK: dient alleen in -- schrijft NOOIT direct in product_features.

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
const COOLDOWN_MS = 3 * 60 * 60 * 1000; // 3 uur
const MAX_ATTEMPTS = 5;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) return json({ error: "ANTHROPIC_API_KEY ontbreekt." }, 500);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: control } = await supabase
      .from("ai_enrichment_control")
      .select("*")
      .eq("id", 1)
      .maybeSingle();

    if (control && !control.auto_enrich_enabled) {
      return json({ status: "disabled", reason: "eenmalige loop is al voltooid; wacht op expliciete herstart" });
    }
    if (control?.last_submit_error_at) {
      const since = Date.now() - new Date(control.last_submit_error_at).getTime();
      if (since < COOLDOWN_MS) {
        return json({ status: "cooling_down", retry_after_ms: COOLDOWN_MS - since });
      }
    }

    // Niet twee batches tegelijk indienen.
    const { data: active } = await supabase
      .from("ai_enrichment_batches")
      .select("id, batch_id")
      .eq("status", "submitted")
      .limit(1)
      .maybeSingle();
    if (active) {
      return json({ status: "skipped", reason: "batch_already_running", batch_id: active.batch_id });
    }

    const url = new URL(req.url);
    const limitParam = url.searchParams.get("limit");
    const limit = limitParam ? Math.max(1, Math.min(200, parseInt(limitParam, 10))) : null;

    const { data: vocabRows, error: vocabErr } = await supabase
      .from("feature_vocabulary")
      .select("field, value");
    if (vocabErr) return await recordFailure(supabase, `Vocab ophalen mislukt: ${vocabErr.message}`);

    const vocab: Record<string, string[]> = {};
    for (const row of vocabRows ?? []) {
      (vocab[row.field] ??= []).push(row.value);
    }
    const need = [
      "snack_type", "category_cluster", "taste_profile",
      "texture_profile", "use_moment", "swap_tags", "recommended_swap_directions",
    ];
    for (const f of need) {
      if (!vocab[f]?.length) return await recordFailure(supabase, `Vocab-veld '${f}' is leeg.`);
    }

    // Sluit ELK barcode uit dat al ooit gestaged is, ongeacht validation_status.
    // Bugfix: eerder werd hier alleen 'pending' uitgesloten, waardoor barcodes
    // die als 'needs_review' of 'rejected' terugkwamen NOOIT uitgesloten werden
    // -- ze bleven `ai_enriched_at is null` (dat veld wordt pas gezet bij
    // approve_staged_features()) en werden dus bij elke volgende submit-cyclus
    // stilzwijgend opnieuw ingediend en opnieuw betaald. 'needs_review' is een
    // wachtstand voor menselijke review, geen "probeer het later nog eens".
    //
    // Gepagineerd ophalen: PostgREST/supabase-js geeft bij een kale .select()
    // maximaal ~1000 rijen terug. Met >4500 staging-rijen liet een niet-
    // gepagineerde query het merendeel stilzwijgend weg uit de exclusieset --
    // exact dezelfde klasse fout als hierboven net gefixt, dus expliciet.
    const excluded = new Set<string>();
    for (let from = 0; ; from += 1000) {
      const { data: page, error: pageErr } = await supabase
        .from("product_features_staging")
        .select("barcode")
        .range(from, from + 999);
      if (pageErr) return await recordFailure(supabase, `Staging-barcodes ophalen mislukt: ${pageErr.message}`);
      for (const r of page ?? []) excluded.add(r.barcode);
      if (!page || page.length < 1000) break;
    }

    let repQuery = supabase
      .from("product_features")
      .select("barcode, is_drink")
      .eq("is_representative", true)
      .is("ai_enriched_at", null)
      .order("barcode");
    if (limit) repQuery = repQuery.limit(limit);
    const { data: reps, error: repErr } = await repQuery;
    if (repErr) return await recordFailure(supabase, `Representanten ophalen mislukt: ${repErr.message}`);

    const targets = (reps ?? []).filter((r) => !excluded.has(r.barcode));
    if (targets.length === 0) {
      // Niets meer te doen: dit was de laatste representant. Schakel de
      // eenmalige loop uit (nieuwe verrijking pas na expliciete herstart).
      await supabase.from("ai_enrichment_control").update({
        auto_enrich_enabled: false, updated_at: new Date().toISOString(),
      }).eq("id", 1);
      return json({ status: "idle", reason: "geen openstaande representanten -- eenmalige loop uitgeschakeld" });
    }

    const barcodes = targets.map((r) => r.barcode);
    const isDrinkByBarcode = new Map(targets.map((r) => [r.barcode, r.is_drink]));

    const products: Row[] = [];
    for (let i = 0; i < barcodes.length; i += 500) {
      const chunk = barcodes.slice(i, i + 500);
      const { data, error } = await supabase
        .from("products")
        .select(
          "barcode, name, brand, category, subcategory, main_category, pnns_groups_1, " +
          "pnns_groups_2, ingredients_text, nutriscore_grade, nova_group, kcal_100g, " +
          "sugar_100g, protein_100g, fat_100g, salt_100g, fiber_100g",
        )
        .in("barcode", chunk);
      if (error) return await recordFailure(supabase, `Producten ophalen mislukt: ${error.message}`);
      products.push(...(data ?? []));
    }

    const schema = buildSchema(vocab);
    const system = buildSystemPrompt();

    const requests = products.map((p) => ({
      custom_id: p.barcode,
      params: {
        model: MODEL,
        max_tokens: 500,
        system,
        output_config: { format: { type: "json_schema", schema } },
        messages: [{
          role: "user",
          content: buildUserPrompt(p, isDrinkByBarcode.get(p.barcode) ?? null),
        }],
      },
    }));

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
      return await recordFailure(supabase, `Anthropic Batch-aanmaak mislukt: ${batchRes.status} ${text}`);
    }
    const batch = await batchRes.json();

    const { error: insertErr } = await supabase.from("ai_enrichment_batches").insert({
      batch_id: batch.id,
      status: "submitted",
      requested_count: requests.length,
    });
    if (insertErr) return await recordFailure(supabase, `Batch-registratie mislukt: ${insertErr.message}`);

    // Succes: reset de foutteller.
    await supabase.from("ai_enrichment_control").update({
      last_submit_error_at: null, last_submit_error: null, submit_attempts: 0,
      updated_at: new Date().toISOString(),
    }).eq("id", 1);

    return json({ status: "submitted", batch_id: batch.id, requested_count: requests.length });
  } catch (e) {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    return await recordFailure(supabase, `Interne fout: ${e}`);
  }
});

async function recordFailure(supabase: any, message: string) {
  const { data: control } = await supabase
    .from("ai_enrichment_control").select("submit_attempts").eq("id", 1).maybeSingle();
  const attempts = (control?.submit_attempts ?? 0) + 1;
  await supabase.from("ai_enrichment_control").update({
    last_submit_error_at: new Date().toISOString(),
    last_submit_error: message,
    submit_attempts: attempts,
    auto_enrich_enabled: attempts >= 5 ? false : true,
    updated_at: new Date().toISOString(),
  }).eq("id", 1);
  return json({ error: message, attempts, disabled: attempts >= 5 }, 500);
}

type Row = Record<string, any>;

function buildSchema(vocab: Record<string, string[]>) {
  return {
    type: "object",
    properties: {
      snack_type: { type: "string", enum: vocab.snack_type },
      category_cluster: { type: "string", enum: vocab.category_cluster },
      taste_profile: { type: "array", items: { type: "string", enum: vocab.taste_profile } },
      texture_profile: { type: "array", items: { type: "string", enum: vocab.texture_profile } },
      use_moment: { type: "array", items: { type: "string", enum: vocab.use_moment } },
      swap_tags: { type: "array", items: { type: "string", enum: vocab.swap_tags } },
      recommended_swap_directions: {
        type: "array",
        items: { type: "string", enum: vocab.recommended_swap_directions },
      },
      is_sweet: { type: "boolean" },
      is_salty: { type: "boolean" },
      is_crunchy: { type: "boolean" },
      confidence: { type: "number" },
    },
    required: [
      "snack_type", "category_cluster", "taste_profile", "texture_profile",
      "use_moment", "swap_tags", "recommended_swap_directions",
      "is_sweet", "is_salty", "is_crunchy", "confidence",
    ],
    additionalProperties: false,
  };
}

function buildSystemPrompt(): string {
  return (
    "Je classificeert Nederlandse supermarktproducten voor een voedings-app (SnackSwap). " +
    "Je krijgt feitelijke productdata (Open Food Facts). " +
    "Gebruik UITSLUITEND de toegestane waarden uit het schema -- verzin niets buiten die lijsten. " +
    "Je MAG NOOIT voedingswaarden, allergenen, ingredienten, Nutri-Score of NOVA veranderen of " +
    "verzinnen -- die staan al vast; jij classificeert alleen soort, smaak, textuur, eetmoment " +
    "en swap-richting op basis van de gegeven feiten. " +
    "'confidence' is jouw eigen inschatting (0-1) van hoe zeker je bent over deze classificatie; " +
    "wees eerlijk laag bij twijfelachtige of onvolledige productdata."
  );
}

function buildUserPrompt(p: Row, isDrink: boolean | null): string {
  const facts = {
    naam: p.name, merk: p.brand,
    categorie: p.category, subcategorie: p.subcategory, hoofdcategorie: p.main_category,
    pnns_1: p.pnns_groups_1, pnns_2: p.pnns_groups_2,
    is_drank: isDrink,
    ingredienten: p.ingredients_text,
    nutriscore: p.nutriscore_grade, nova: p.nova_group,
    per_100g: {
      kcal: p.kcal_100g, suiker_g: p.sugar_100g, eiwit_g: p.protein_100g,
      vet_g: p.fat_100g, zout_g: p.salt_100g, vezels_g: p.fiber_100g,
    },
  };
  return `Classificeer dit product:\n${JSON.stringify(facts)}`;
}
