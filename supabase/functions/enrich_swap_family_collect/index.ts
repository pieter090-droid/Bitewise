// Supabase Edge Function: enrich_swap_family_collect
//
// Handmatig aan te roepen met { "batch_id": "..." } (uit enrich_swap_family_submit).
// Checkt de Anthropic-batchstatus; zodra klaar: past resultaten toe op
// product_features (swap_family + de overige velden deterministisch uit
// swap_family_mapping, exact zoals de regelfunctie dat doet) en propageert
// gratis naar clustergenoten die ZELF nog geen swap_family hebben (nooit een
// al aanwezige regelgebaseerde of eerder-AI-gezette waarde overschrijven).
// Confidence < 0.6 of 'unknown': niet toepassen, blijft NULL (nooit gokken).

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

const ANTHROPIC_VERSION = "2023-06-01";
const MIN_CONFIDENCE = 0.6;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) return json({ error: "ANTHROPIC_API_KEY ontbreekt." }, 500);

    const { batch_id } = await req.json().catch(() => ({ batch_id: null }));
    if (!batch_id) return json({ error: "batch_id ontbreekt in de request-body." }, 400);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const statusRes = await fetch(
      `https://api.anthropic.com/v1/messages/batches/${batch_id}`,
      { headers: { "x-api-key": apiKey, "anthropic-version": ANTHROPIC_VERSION } },
    );
    if (!statusRes.ok) {
      const text = await statusRes.text();
      return json({ error: `Statuscheck mislukt: ${statusRes.status} ${text}` }, 500);
    }
    const batchStatus = await statusRes.json();
    if (batchStatus.processing_status !== "ended") {
      return json({ status: "pending", processing_status: batchStatus.processing_status });
    }

    const resultsRes = await fetch(
      `https://api.anthropic.com/v1/messages/batches/${batch_id}/results`,
      { headers: { "x-api-key": apiKey, "anthropic-version": ANTHROPIC_VERSION } },
    );
    if (!resultsRes.ok) {
      const text = await resultsRes.text();
      return json({ error: `Resultaten ophalen mislukt: ${resultsRes.status} ${text}` }, 500);
    }
    const raw = await resultsRes.text();
    const lines = raw.split("\n").map((l) => l.trim()).filter(Boolean);

    let applied = 0, lowConfidence = 0, failed = 0, propagated = 0;

    for (const line of lines) {
      let entry: any;
      try { entry = JSON.parse(line); } catch { failed++; continue; }
      const barcode = entry.custom_id;
      if (entry.result?.type !== "succeeded") { failed++; continue; }
      const textBlock = entry.result.message?.content?.find((b: any) => b.type === "text");
      if (!textBlock?.text) { failed++; continue; }
      let parsed: any;
      try { parsed = JSON.parse(textBlock.text); } catch { failed++; continue; }

      const family = parsed.swap_family;
      const confidence = typeof parsed.confidence === "number" ? parsed.confidence : 0;
      if (!family || family === "unknown" || confidence < MIN_CONFIDENCE) {
        lowConfidence++;
        continue;
      }

      const { data: mapRow } = await supabase
        .from("swap_family_mapping").select("*").eq("swap_family", family).maybeSingle();
      if (!mapRow) { failed++; continue; }

      const { data: repRow } = await supabase
        .from("product_features").select("cluster_key").eq("barcode", barcode).maybeSingle();

      const updatePayload = {
        swap_family: family,
        category_cluster: mapRow.category_cluster,
        snack_type: mapRow.snack_type,
        product_form: mapRow.product_form,
        consumption_mode: mapRow.consumption_mode,
        secondary_consumption_modes: mapRow.secondary_consumption_modes ?? [],
        usage_context: mapRow.usage_context ?? [],
        updated_at: new Date().toISOString(),
      };

      const { error: updErr } = await supabase
        .from("product_features").update(updatePayload).eq("barcode", barcode);
      if (updErr) { failed++; continue; }
      applied++;

      // Gratis propagatie naar clustergenoten die zelf nog geen swap_family
      // hebben (nooit een bestaande regelgebaseerde/AI-waarde overschrijven).
      if (repRow?.cluster_key) {
        const { data: mates, error: propErr } = await supabase
          .from("product_features")
          .update(updatePayload)
          .eq("cluster_key", repRow.cluster_key)
          .is("swap_family", null)
          .neq("barcode", barcode)
          .select("barcode");
        if (!propErr && mates) propagated += mates.length;
      }
    }

    return json({ status: "completed", applied, propagated, low_confidence_or_unknown: lowConfidence, failed });
  } catch (e) {
    return json({ error: `Interne fout: ${e}` }, 500);
  }
});
