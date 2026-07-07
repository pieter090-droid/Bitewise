// Supabase Edge Function: enrich_batch_collect
//
// Heartbeat, elke 15 minuten aangeroepen door pg_cron. Doet drie dingen,
// in deze volgorde, en is verder een goedkope no-op:
//
//   1. Is er een actieve batch? Check status bij Anthropic. Fout/nog niet
//      klaar? -> respecteer de 3-uur-afkoeling voor een nieuwe poging.
//      Klaar? -> resultaten ophalen (INCREMENTEEL: alleen barcodes die nog
//      niet in staging staan voor dit batch_id -- een halverwege gecrashte
//      poging kost bij hervatting dus geen extra tokens of dubbele rijen),
//      valideren, goedkeuren. Geen representanten meer over? -> eenmalige
//      loop uitschakelen.
//
//   2. Geen actieve batch, wel nog werk, eenmalige loop nog aan, niet in
//      afkoeling? -> zelf enrich_batch_submit aanroepen (self-heal).
//
//   3. Een voltooide batch zonder kwaliteitscheck (de trigger kan zijn
//      mislukt)? -> evaluate_swap_quality opnieuw aanroepen, met dezelfde
//      3-uur-afkoeling.

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
const MODEL = "claude-sonnet-5";
const COOLDOWN_MS = 3 * 60 * 60 * 1000;
const MAX_ATTEMPTS = 5;
const SUPABASE_URL = "https://ulgfgawoulkyumfzqgrc.supabase.co";
const ANON_KEY = "sb_publishable_SUIlYw03NLjU-tRlCn752w_ssZfGEFe";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) return json({ error: "ANTHROPIC_API_KEY ontbreekt." }, 500);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: batchRow } = await supabase
      .from("ai_enrichment_batches")
      .select("*")
      .eq("status", "submitted")
      .order("submitted_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (batchRow) {
      return await processActiveBatch(supabase, apiKey, batchRow);
    }

    // Geen actieve batch: check op een voltooide batch zonder kwaliteitscheck
    // (bv. omdat de databasetrigger zelf een keer mislukte). BELANGRIJK: dit
    // mag de rest van de heartbeat (nieuw werk indienen) NOOIT blokkeren --
    // vroeger stopte de hele functie hier bij een cooldown, waardoor nieuwe
    // enrichment-batches urenlang niet werden ingediend zolang een oudere
    // batch op zijn kwaliteitscheck-afkoeling wachtte.
    let qualityCheckStatus: string | null = null;
    const { data: uncheckedBatch } = await supabase
      .from("ai_enrichment_batches")
      .select("*")
      .eq("status", "completed")
      .is("quality_checked_at", null)
      .order("completed_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (uncheckedBatch) {
      if (inCooldown(uncheckedBatch.quality_check_last_error_at)) {
        qualityCheckStatus = "quality_check_cooling_down";
      } else {
        // Zelf de kwaliteitscheck opnieuw aanroepen (idempotent: al-beoordeelde
        // paren worden overgeslagen, kost geen extra tokens). Fire-and-forget:
        // we wachten niet op de uitkomst, zodat de heartbeat meteen doorgaat.
        fetch(`${SUPABASE_URL}/functions/v1/evaluate_swap_quality`, {
          method: "POST",
          headers: { "Content-Type": "application/json", apikey: ANON_KEY },
          body: JSON.stringify({ batch_id: uncheckedBatch.batch_id }),
        }).catch(() => {});
        qualityCheckStatus = "quality_check_retriggered";
      }
    }

    // Geen actieve batch: is er nog enrichment-werk? (altijd checken, ook als
    // er hierboven een kwaliteitscheck liep/afkoelde)
    const { data: control } = await supabase
      .from("ai_enrichment_control").select("*").eq("id", 1).maybeSingle();

    if (control && !control.auto_enrich_enabled) {
      return json({ status: "idle", reason: "eenmalige loop is voltooid", qualityCheckStatus });
    }
    if (control?.last_submit_error_at && inCooldown(control.last_submit_error_at)) {
      return json({ status: "submit_cooling_down", qualityCheckStatus });
    }

    const { data: pending } = await supabase
      .from("product_features")
      .select("barcode")
      .eq("is_representative", true)
      .is("ai_enriched_at", null)
      .limit(1);

    if (!pending || pending.length === 0) {
      return json({ status: "idle", reason: "geen openstaand werk", qualityCheckStatus });
    }

    // Self-heal: dien zelf een nieuwe batch in.
    const submitRes = await fetch(`${SUPABASE_URL}/functions/v1/enrich_batch_submit`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON_KEY },
      body: JSON.stringify({}),
    });
    const submitBody = await submitRes.json();
    return json({ status: "self_healed_submit", result: submitBody, qualityCheckStatus });
  } catch (e) {
    return json({ error: `Interne fout: ${e}` }, 500);
  }
});

function inCooldown(lastErrorAt: string | null | undefined): boolean {
  if (!lastErrorAt) return false;
  return Date.now() - new Date(lastErrorAt).getTime() < COOLDOWN_MS;
}

async function processActiveBatch(supabase: any, apiKey: string, batchRow: any) {
  if (inCooldown(batchRow.last_error_at)) {
    return json({ status: "cooling_down", batch_id: batchRow.batch_id });
  }

  const statusRes = await fetch(
    `https://api.anthropic.com/v1/messages/batches/${batchRow.batch_id}`,
    { headers: { "x-api-key": apiKey, "anthropic-version": ANTHROPIC_VERSION } },
  );
  if (!statusRes.ok) {
    const text = await statusRes.text();
    return await recordBatchFailure(supabase, batchRow, `Statuscheck mislukt: ${statusRes.status} ${text}`);
  }
  const batchStatus = await statusRes.json();
  await supabase.from("ai_enrichment_batches")
    .update({ last_checked_at: new Date().toISOString() }).eq("id", batchRow.id);

  if (batchStatus.processing_status !== "ended") {
    return json({ status: "pending", processing_status: batchStatus.processing_status });
  }

  const resultsRes = await fetch(
    `https://api.anthropic.com/v1/messages/batches/${batchRow.batch_id}/results`,
    { headers: { "x-api-key": apiKey, "anthropic-version": ANTHROPIC_VERSION } },
  );
  if (!resultsRes.ok) {
    const text = await resultsRes.text();
    return await recordBatchFailure(supabase, batchRow, `Resultaten ophalen mislukt: ${resultsRes.status} ${text}`);
  }
  const raw = await resultsRes.text();
  const lines = raw.split("\n").map((l) => l.trim()).filter(Boolean);

  // INCREMENTEEL: alleen barcodes invoegen die nog niet in staging staan
  // voor dit batch_id -- een hervatte poging doet nooit dubbel werk.
  // Gepagineerd: een kale .select() geeft bij >1000 rijen maar de eerste 1000
  // terug (zelfde valkuil als in enrich_batch_submit), en sommige batches
  // hebben ruim over de 1000 gestagede rijen.
  const done = new Set<string>();
  for (let from = 0; ; from += 1000) {
    const { data: page } = await supabase
      .from("product_features_staging")
      .select("barcode")
      .eq("batch_id", batchRow.batch_id)
      .range(from, from + 999);
    for (const r of page ?? []) done.add(r.barcode);
    if (!page || page.length < 1000) break;
  }

  let succeeded = 0, failed = 0;
  const stagingRows: Record<string, unknown>[] = [];

  for (const line of lines) {
    let entry: any;
    try { entry = JSON.parse(line); } catch { failed++; continue; }
    const barcode = entry.custom_id;
    if (done.has(barcode)) continue; // al eerder verwerkt, overslaan

    if (entry.result?.type !== "succeeded") { failed++; continue; }
    const textBlock = entry.result.message?.content?.find((b: any) => b.type === "text");
    if (!textBlock?.text) { failed++; continue; }
    let parsed: any;
    try { parsed = JSON.parse(textBlock.text); } catch { failed++; continue; }

    stagingRows.push({
      barcode, batch_id: batchRow.batch_id,
      snack_type: parsed.snack_type ?? null,
      category_cluster: parsed.category_cluster ?? null,
      taste_profile: parsed.taste_profile ?? [],
      texture_profile: parsed.texture_profile ?? [],
      use_moment: parsed.use_moment ?? [],
      swap_tags: parsed.swap_tags ?? [],
      recommended_swap_directions: parsed.recommended_swap_directions ?? [],
      is_sweet: parsed.is_sweet ?? null,
      is_salty: parsed.is_salty ?? null,
      is_crunchy: parsed.is_crunchy ?? null,
      ai_confidence: typeof parsed.confidence === "number" ? parsed.confidence : null,
      ai_model: MODEL,
      raw_ai_response: entry,
      validation_status: "pending",
    });
    succeeded++;
  }

  for (let i = 0; i < stagingRows.length; i += 500) {
    const chunk = stagingRows.slice(i, i + 500);
    const { error } = await supabase.from("product_features_staging").insert(chunk);
    if (error) return await recordBatchFailure(supabase, batchRow, `Staging-insert mislukt: ${error.message}`);
  }

  const { error: validateErr } = await supabase.rpc("validate_staged_features");
  if (validateErr) return await recordBatchFailure(supabase, batchRow, `Validatie mislukt: ${validateErr.message}`);
  const { error: approveErr } = await supabase.rpc("approve_staged_features");
  if (approveErr) return await recordBatchFailure(supabase, batchRow, `Goedkeuring mislukt: ${approveErr.message}`);

  const allBarcodesThisBatch = [...done, ...stagingRows.map((r) => r.barcode as string)];
  const counts = { approved: 0, needs_review: 0, rejected: 0 };
  for (let i = 0; i < allBarcodesThisBatch.length; i += 500) {
    const chunk = allBarcodesThisBatch.slice(i, i + 500);
    const { data } = await supabase
      .from("product_features_staging").select("validation_status")
      .eq("batch_id", batchRow.batch_id).in("barcode", chunk);
    for (const r of data ?? []) {
      if (r.validation_status === "approved") counts.approved++;
      else if (r.validation_status === "needs_review") counts.needs_review++;
      else if (r.validation_status === "rejected") counts.rejected++;
    }
  }

  await supabase.from("ai_enrichment_batches").update({
    status: "completed", completed_at: new Date().toISOString(),
    applied_count: counts.approved, needs_review_count: counts.needs_review,
    rejected_count: counts.rejected, last_error_at: null, last_error: null,
  }).eq("id", batchRow.id);

  // Geen representanten meer over? Eenmalige loop uitschakelen.
  const { data: remaining } = await supabase
    .from("product_features").select("barcode")
    .eq("is_representative", true).is("ai_enriched_at", null).limit(1);
  if (!remaining || remaining.length === 0) {
    await supabase.from("ai_enrichment_control").update({
      auto_enrich_enabled: false, updated_at: new Date().toISOString(),
    }).eq("id", 1);
  }

  return json({
    status: "completed", succeeded, failed,
    applied: counts.approved, needs_review: counts.needs_review, rejected: counts.rejected,
  });
}

async function recordBatchFailure(supabase: any, batchRow: any, message: string) {
  const attempts = (batchRow.attempts ?? 0) + 1;
  await supabase.from("ai_enrichment_batches").update({
    last_error_at: new Date().toISOString(),
    last_error: message,
    attempts,
    status: attempts >= MAX_ATTEMPTS ? "failed" : "submitted",
  }).eq("id", batchRow.id);
  return json({ error: message, attempts, failed_permanently: attempts >= MAX_ATTEMPTS }, 500);
}
