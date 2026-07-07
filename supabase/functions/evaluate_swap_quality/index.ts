// Supabase Edge Function: evaluate_swap_quality
//
// Wordt automatisch aangeroepen door de databasetrigger zodra een
// enrichment-batch 'completed' wordt (en door enrich_batch_collect als
// vangnet als die trigger een keer mislukte).
//
// Neemt een vaste (reproduceerbare) steekproef van max 50 paren uit de
// zojuist verrijkte barcodes, laat Sonnet 5 BLIND (zonder onze score te
// zien) een onafhankelijk oordeel geven, en vergelijkt dat met onze eigen
// calculate_swap_score(). Grote afwijkingen worden gemarkeerd.
//
// INCREMENTEEL/HERVATBAAR: elk paar wordt direct na beoordeling weggeschreven
// (unique constraint op batch_id+from+to). Bij een crash halverwege worden
// bij een retry alleen de nog-niet-beoordeelde paren opnieuw aan Sonnet 5
// voorgelegd -- geen dubbele tokenkosten.
//
// HARDE CAP: max 50 paren, max 200 output-tokens per beoordeling, model
// vast op Sonnet 5, en quality_checked_at zorgt dat dit maar 1x per batch
// tot een afgeronde staat komt.

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
const SAMPLE_SIZE = 50;
const MAX_OUTPUT_TOKENS = 400;
const COOLDOWN_MS = 3 * 60 * 60 * 1000;
const MAX_ATTEMPTS = 5;
const DISCREPANCY_THRESHOLD = 35; // punten verschil op 0-100-schaal

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) return json({ error: "ANTHROPIC_API_KEY ontbreekt." }, 500);

    const { batch_id } = await req.json().catch(() => ({ batch_id: null }));
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    let batchRow;
    if (batch_id) {
      const { data } = await supabase.from("ai_enrichment_batches")
        .select("*").eq("batch_id", batch_id).maybeSingle();
      batchRow = data;
    } else {
      const { data } = await supabase.from("ai_enrichment_batches")
        .select("*").eq("status", "completed").is("quality_checked_at", null)
        .order("completed_at", { ascending: false }).limit(1).maybeSingle();
      batchRow = data;
    }
    if (!batchRow) return json({ status: "idle", reason: "geen batch gevonden" });
    if (batchRow.quality_checked_at) return json({ status: "already_done", batch_id: batchRow.batch_id });

    if (batchRow.quality_check_last_error_at) {
      const since = Date.now() - new Date(batchRow.quality_check_last_error_at).getTime();
      if (since < COOLDOWN_MS) return json({ status: "cooling_down" });
    }

    // Vaste, reproduceerbare steekproef (op barcode gesorteerd) uit de net
    // goedgekeurde producten van deze batch.
    const { data: sample, error: sampleErr } = await supabase
      .from("product_features_staging")
      .select("barcode")
      .eq("batch_id", batchRow.batch_id)
      .eq("validation_status", "approved")
      .order("barcode")
      .limit(SAMPLE_SIZE);
    if (sampleErr) return await recordFailure(supabase, batchRow, `Steekproef mislukt: ${sampleErr.message}`);

    if (!sample || sample.length === 0) {
      await markDone(supabase, batchRow.id);
      return json({ status: "completed", checked: 0, reason: "geen goedgekeurde producten om te bemonsteren" });
    }

    // Al beoordeelde paren voor deze batch overslaan (hervatting kost geen tokens).
    const { data: existing } = await supabase
      .from("swap_score_eval_results").select("from_barcode")
      .eq("batch_id", batchRow.batch_id);
    const alreadyDone = new Set((existing ?? []).map((r: any) => r.from_barcode));

    let checked = 0, discrepancies = 0;

    for (const row of sample) {
      const fromBarcode = row.barcode;
      if (alreadyDone.has(fromBarcode)) continue;

      // Kandidaat: hoogste-datakwaliteit ander product van hetzelfde
      // product-type. Zelfde tweetraps-aanpak als de app (snackswap_service.dart
      // getCandidatesForCluster): snack_type eerst (fijn, ~22 waarden), pas als
      // dat niets oplevert terugvallen op category_cluster (grof, 7 emmers --
      // "zoet" alleen mengt bv. kokosmelk met oregano, dus nooit als eerste keus).
      const { data: fromFeatures } = await supabase
        .from("product_features").select("category_cluster, snack_type")
        .eq("barcode", fromBarcode).maybeSingle();
      if (!fromFeatures?.category_cluster) continue;

      let toBarcode: string | undefined;
      if (fromFeatures.snack_type) {
        const { data: sameType } = await supabase
          .from("product_features")
          .select("barcode")
          .eq("snack_type", fromFeatures.snack_type)
          .neq("barcode", fromBarcode)
          .order("data_quality_score", { ascending: false })
          .order("barcode")
          .limit(1);
        toBarcode = sameType?.[0]?.barcode;
      }
      if (!toBarcode) {
        const { data: sameCluster } = await supabase
          .from("product_features")
          .select("barcode")
          .eq("category_cluster", fromFeatures.category_cluster)
          .neq("barcode", fromBarcode)
          .order("data_quality_score", { ascending: false })
          .order("barcode")
          .limit(1);
        toBarcode = sameCluster?.[0]?.barcode;
      }
      if (!toBarcode) continue;

      const { data: ourResult, error: rpcErr } = await supabase.rpc("calculate_swap_score", {
        p_from: fromBarcode, p_to: toBarcode, p_goal: "gezonder_eten", p_day_context: {},
      });
      if (rpcErr) return await recordFailure(supabase, batchRow, `calculate_swap_score mislukt: ${rpcErr.message}`);
      const ours = ourResult?.[0];
      if (!ours) continue;

      // Inclusief processing_quality_score/is_less_processed: ons model rekent
      // "gezonder eten" voor 30% als "hoe onbewerkt is de kandidaat" (NOVA/
      // additieven-gebaseerd), niet alleen macros. Zonder dit signaal beoordeelt
      // de AI-rechter een andere vraag dan wij stellen en ontstaan schijnbare
      // afwijkingen die geen echte modelfout zijn.
      const [fromProduct, toProduct] = await Promise.all([
        supabase.from("products")
          .select("name, kcal_100g, sugar_100g, protein_100g, product_features(processing_quality_score, is_less_processed)")
          .eq("barcode", fromBarcode).maybeSingle(),
        supabase.from("products")
          .select("name, kcal_100g, sugar_100g, protein_100g, product_features(processing_quality_score, is_less_processed)")
          .eq("barcode", toBarcode).maybeSingle(),
      ]);

      let judgment: { score: number; reason: string } | null = null;
      try {
        judgment = await judgeSwap(apiKey, flattenProduct(fromProduct.data), flattenProduct(toProduct.data));
      } catch (e) {
        return await recordFailure(supabase, batchRow, `AI-oordeel mislukt: ${e}`);
      }

      const ourScaled = Number(ours.score); // 0-100
      const aiScaled = judgment.score * 20; // 1-5 -> 0-100
      const isDiscrepancy = Math.abs(ourScaled - aiScaled) > DISCREPANCY_THRESHOLD;
      if (isDiscrepancy) discrepancies++;

      const { error: insertErr } = await supabase.from("swap_score_eval_results").insert({
        batch_id: batchRow.batch_id,
        from_barcode: fromBarcode, to_barcode: toBarcode,
        our_score: ours.score, our_breakdown: ours.breakdown,
        ai_judgment_score: judgment.score, ai_judgment_reason: judgment.reason,
        is_discrepancy: isDiscrepancy,
      });
      if (insertErr && !insertErr.message?.includes("duplicate")) {
        return await recordFailure(supabase, batchRow, `Resultaat opslaan mislukt: ${insertErr.message}`);
      }
      checked++;
    }

    await markDone(supabase, batchRow.id);
    return json({ status: "completed", checked, discrepancies });
  } catch (e) {
    return json({ error: `Interne fout: ${e}` }, 500);
  }
});

async function markDone(supabase: any, id: string) {
  await supabase.from("ai_enrichment_batches").update({
    quality_checked_at: new Date().toISOString(),
    quality_check_last_error_at: null, quality_check_last_error: null,
  }).eq("id", id);
}

async function recordFailure(supabase: any, batchRow: any, message: string) {
  const attempts = (batchRow.quality_check_attempts ?? 0) + 1;
  await supabase.from("ai_enrichment_batches").update({
    quality_check_last_error_at: new Date().toISOString(),
    quality_check_last_error: message,
    quality_check_attempts: attempts,
    // Na te veel pogingen: markeer als "klaar" om oneindig hameren te
    // voorkomen -- de deelresultaten die al gelukt zijn blijven staan.
    quality_checked_at: attempts >= MAX_ATTEMPTS ? new Date().toISOString() : null,
  }).eq("id", batchRow.id);
  return json({ error: message, attempts }, 500);
}

// PostgREST geeft de 1:1-embed terug als object of als array van 1 -- normaliseer.
function flattenProduct(row: any): any {
  if (!row) return row;
  const pf = Array.isArray(row.product_features) ? row.product_features[0] : row.product_features;
  const { product_features: _drop, ...rest } = row;
  return { ...rest, processing_quality_score: pf?.processing_quality_score ?? null, is_less_processed: pf?.is_less_processed ?? null };
}

async function judgeSwap(apiKey: string, from: any, to: any): Promise<{ score: number; reason: string }> {
  const schema = {
    type: "object",
    properties: {
      score: { type: "integer", enum: [1, 2, 3, 4, 5] },
      reason: { type: "string", maxLength: 120 },
    },
    required: ["score", "reason"],
    additionalProperties: false,
  };
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": apiKey, "anthropic-version": ANTHROPIC_VERSION, "content-type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: MAX_OUTPUT_TOKENS,
      output_config: { format: { type: "json_schema", schema } },
      messages: [{
        role: "user",
        content:
          "Je bent een onafhankelijke voedingsrechter. Beoordeel of 'kandidaat' een zinnig " +
          "alternatief is voor 'origineel' voor iemand die gezonder wil eten. Weeg zowel de " +
          "macro's (kcal/suiker/eiwit) als processing_quality_score (0-100, hoger = minder " +
          "bewerkt, gebaseerd op NOVA-groep en additieven) mee -- een kandidaat met betere " +
          "macro's maar even sterk bewerkt is hooguit een matig alternatief. " +
          "Geef score 1 (onzinnig) t/m 5 (uitstekend alternatief) + een reden van maximaal 15 woorden.\n" +
          `Origineel: ${JSON.stringify(from)}\nKandidaat: ${JSON.stringify(to)}`,
      }],
    }),
  });
  if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
  const data = await res.json();
  const text = data.content?.find((b: any) => b.type === "text")?.text ?? "{}";
  const parsed = JSON.parse(text);
  return { score: parsed.score, reason: parsed.reason };
}
