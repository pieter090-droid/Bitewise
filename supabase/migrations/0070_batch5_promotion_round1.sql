-- VOORSTEL — NOG NIET UITGEVOERD. Wacht op expliciet akkoord vóór
-- `supabase db push`. Batch 5, eerste PROMOTIE-ronde: zet de tot nu toe
-- handmatig beoordeelde 2345 staging-rijen (uit swap_family_staging) om
-- naar echte `product_features`-classificatie, zodat de app dit
-- daadwerkelijk kan tonen en getest kan worden. Latere chunks van de
-- unknown-staart worden apart toegevoegd (zelfde staging->promotie-
-- proces).
--
-- Promotieregels (zoals eerder afgesproken):
--   - confidence >= 0.5 én suggested_swap_family niet null
--       -> classification_status = 'classified', swap_family gezet.
--          Telt mee als explained EN (als de familie dat toelaat) als
--          swap candidate.
--   - confidence < 0.5 én suggested_swap_family niet null
--       -> classification_status = 'review_required', swap_family
--          blijft null, de staging-reasoning wordt de classification_reason.
--          Telt mee als explained, NIET als swap candidate.
--   - suggested_swap_family is null -> onaangeroerd, blijft unclassified.
--
-- Alleen rijen waar product_features.classification_status nog null is
-- worden aangeraakt (additief, geen bestaande classificaties overschreven).
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

-- Stap 1: snapshot van alle barcodes die deze migratie kan aanraken.
create table if not exists public._snapshot_0070_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (select barcode from public.swap_family_staging);

-- Stap 2: nieuwe niet-swap-relevante familie toevoegen (ontdekt tijdens
-- handmatige beoordeling van de Milk and yogurt-pool: kookroom/crème
-- fraîche zonder bestaande familie).
insert into public.swap_family_mapping
  (swap_family, category_cluster, snack_type, product_form, consumption_mode,
   secondary_consumption_modes, usage_context, related_families, is_swap_relevant_default)
values
  ('dairy_cooking_cream_non_swap', 'overig', 'ingredient', 'raw_ingredient', 'cook_or_prepare',
   '{}', array['cooking'], '{}', false)
on conflict (swap_family) do update set
  category_cluster = excluded.category_cluster,
  snack_type = excluded.snack_type,
  product_form = excluded.product_form,
  consumption_mode = excluded.consumption_mode,
  usage_context = excluded.usage_context,
  related_families = excluded.related_families,
  is_swap_relevant_default = excluded.is_swap_relevant_default;

-- Stap 3: promotie -- classified (confidence >= 0.5).
with promotable as (
  select s.barcode, s.suggested_swap_family, s.confidence, s.reasoning, s.batch_label,
    row_number() over (partition by s.barcode order by s.confidence desc) as rn
  from public.swap_family_staging s
  where s.suggested_swap_family is not null and s.confidence >= 0.5
)
update public.product_features pf set
  swap_family = p.suggested_swap_family,
  classification_status = 'classified',
  classification_confidence = p.confidence,
  classification_reason = 'batch5_promotion_r1: ' || p.reasoning,
  classified_at = now(),
  mapping_version = 1
from promotable p
where pf.barcode = p.barcode and p.rn = 1 and pf.classification_status is null;

-- Stap 4: promotie -- review_required (confidence < 0.5).
with reviewable as (
  select s.barcode, s.suggested_swap_family, s.confidence, s.reasoning, s.batch_label,
    row_number() over (partition by s.barcode order by s.confidence desc) as rn
  from public.swap_family_staging s
  where s.suggested_swap_family is not null and s.confidence < 0.5
)
update public.product_features pf set
  classification_status = 'review_required',
  classification_confidence = r.confidence,
  classification_reason = 'batch5_promotion_r1: ' || r.reasoning,
  classified_at = now(),
  mapping_version = 1
from reviewable r
where pf.barcode = r.barcode and r.rn = 1 and pf.classification_status is null;

-- Stap 5: markeer gepromoveerde staging-rijen (voor traceerbaarheid,
-- niet voor coverage-logica).
update public.swap_family_staging s set
  promoted_at = now(),
  promotion_migration = '0070_batch5_promotion_round1'
where s.barcode in (
  select barcode from public.product_features
  where classification_reason like 'batch5_promotion_r1:%'
);

-- POSTFLIGHT (read-only, uit te voeren na deze migratie):
-- select classification_status, count(*) from product_features
--   where classification_reason like 'batch5_promotion_r1:%' group by 1;
--   -- verwacht: classified ~957, review_required ~727
-- select count(*) from product_features_resolved; -- moet exact gelijk blijven aan aantal products
-- select count(*) from product_features where swap_family is not null and classification_status is null; -- moet 0 blijven
-- select is_swap_relevant, count(*) from product_features_resolved
--   where classification_reason like 'batch5_promotion_r1:%' and swap_family is not null
--   group by 1;
--   -- kern-check: non-swap families (fish_seafood/legumes_non_swap/dairy_cooking_cream_non_swap/etc.)
--   -- moeten allemaal is_swap_relevant=false zijn; swap-relevante families (fresh_vegetables/
--   -- cheese_snacks/etc.) moeten is_swap_relevant=true zijn
-- select max(updated_at) from products; -- moet ongewijzigd blijven (products blijft raw)

-- ROLLBACK (exact, via de snapshot-tabel):
-- update public.product_features pf set
--   swap_family = s.swap_family, is_swap_relevant = s.is_swap_relevant,
--   classification_status = s.classification_status, classification_confidence = s.classification_confidence,
--   classification_reason = s.classification_reason, matched_rule_id = s.matched_rule_id,
--   rule_version = s.rule_version, mapping_version = s.mapping_version,
--   source_fingerprint = s.source_fingerprint, classified_at = s.classified_at
-- from public._snapshot_0070_before s
-- where pf.barcode = s.barcode;
-- update public.swap_family_staging set promoted_at = null, promotion_migration = null
--   where promotion_migration = '0070_batch5_promotion_round1';
-- delete from public.swap_family_mapping where swap_family = 'dairy_cooking_cream_non_swap';
-- drop table public._snapshot_0070_before; -- pas na bevestigde, succesvolle rollback
