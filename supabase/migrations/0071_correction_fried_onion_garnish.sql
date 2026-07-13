-- VOORSTEL — NOG NIET UITGEVOERD. Wacht op expliciet akkoord vóór
-- `supabase db push`. Barcode-verankerde correctie, ontdekt tijdens
-- live-verificatie van migratie 0070: 5 gebakken-ui-garneringsproducten
-- waren in Batch 5 (chunk 4/9) als `fried_snacks` geclassificeerd op
-- basis van het vissticks/lekkerbek-precedent (gefrituurd → snack), maar
-- dat precedent klopt hier niet.
--
-- Bewijs: alle 5 hebben een extreem hoge energiewaarde (580-600 kcal/
-- 100g), typisch voor een geconcentreerd frituurproduct dat je in kleine
-- hoeveelheden als garnering gebruikt (bijv. 5-10g op een salade/
-- stamppot), NIET als een 100g-snackportie zoals bitterballen of
-- kroketten. Een "swap" tussen deze producten en echte snacks zou
-- misleidend zijn (portiegrootte-mismatch). Er is geen bestaande familie
-- die "garnering/topping" goed dekt, dus deze 5 gaan terug naar
-- onbeslist in plaats van naar een andere gok.
--
-- Barcodes (geverifieerd via kcal_100g > 400 binnen fried_snacks, alle
-- afkomstig uit classification_reason 'batch5_promotion_r1:%'):
--   8710161000192 - Gebakken uitjes (Flower Brand), 590 kcal
--   8718907269940 - Gebakken uitjes (Albert Heijn), 600 kcal
--   23026438       - Röstzwiebeln (Fortune Express), 590 kcal
--   8710605030884 - Go Tan Fried Onion, 580 kcal
--   20173074       - Ceapa Prăjită (Kania), 585.71 kcal
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

-- Stap 1: snapshot (superset: alle 5 barcodes, huidige staat).
create table if not exists public._snapshot_0071_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in ('8710161000192','8718907269940','23026438','8710605030884','20173074');

-- Stap 2: terug naar onbeslist (geen swap_family-gok voor "garnering").
update public.product_features pf set
  swap_family = null,
  classification_status = null,
  classification_confidence = null,
  classification_reason = 'correction_0071: teruggezet naar onbeslist -- gebakken-ui-garnering (580-600 kcal/100g), geen 100g-snackportie, geen passende bestaande familie',
  classified_at = null,
  mapping_version = null
where pf.barcode in ('8710161000192','8718907269940','23026438','8710605030884','20173074');

-- Stap 3: bijbehorende staging-rijen ontkoppelen van de promotie (voor
-- traceerbaarheid -- deze 5 tellen niet langer mee als "gepromoveerd").
update public.swap_family_staging s set
  promoted_at = null,
  promotion_migration = null
where s.barcode in ('8710161000192','8718907269940','23026438','8710605030884','20173074')
  and s.promotion_migration = '0070_batch5_promotion_round1';

-- POSTFLIGHT (read-only):
-- select barcode, swap_family, classification_status from product_features
--   where barcode in ('8710161000192','8718907269940','23026438','8710605030884','20173074');
--   -- alle 5 moeten swap_family=null, classification_status=null hebben
-- select count(*) from product_features_resolved; -- moet exact gelijk blijven aan aantal products
-- select count(*) from product_features where swap_family is not null and classification_status is null; -- moet 0 blijven

-- ROLLBACK (exact, via de snapshot-tabel):
-- update public.product_features pf set
--   swap_family = s.swap_family, is_swap_relevant = s.is_swap_relevant,
--   classification_status = s.classification_status, classification_confidence = s.classification_confidence,
--   classification_reason = s.classification_reason, matched_rule_id = s.matched_rule_id,
--   rule_version = s.rule_version, mapping_version = s.mapping_version,
--   source_fingerprint = s.source_fingerprint, classified_at = s.classified_at
-- from public._snapshot_0071_before s
-- where pf.barcode = s.barcode;
-- update public.swap_family_staging set promoted_at = now(), promotion_migration = '0070_batch5_promotion_round1'
--   where barcode in ('8710161000192','8718907269940','23026438','8710605030884','20173074');
-- drop table public._snapshot_0071_before; -- pas na bevestigde, succesvolle rollback
