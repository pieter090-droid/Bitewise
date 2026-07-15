-- VOORSTEL — NOG NIET UITGEVOERD. Wacht op expliciet akkoord vóór
-- `supabase db push`. Systematische correctie, naar aanleiding van het
-- Cottage Cheese / Solero-swap-probleem: een SQL-query die producten met
-- (bijna) identieke naam maar verschillende `swap_family` opspoort, over
-- de HELE database (niet alleen cold_cuts zoals migratie 0072).
--
-- Methode: normaliseer productnamen (alleen letters, lowercase), groepeer,
-- en zoek naar namen die met genoeg volume over >1 familie verspreid staan.
-- Zo'n split is bijna altijd een classificatiefout -- hetzelfde product
-- hoort niet in twee verschillende families te zitten. Elke hieronder
-- gecorrigeerde groep is handmatig geverifieerd (niet alleen op de
-- naam-match vertrouwd) voordat de nieuwe familie is gekozen.
--
-- Gevonden en gecorrigeerd (allemaal `legacy_existing_valid_family_
-- status_backfill`, dus van vóór deze sessie):
--   - Chiazaad (4x)        grain_starch_ingredients -> nuts_seeds
--       (chiazaad is een zaad/snack-ingrediënt, geen graan/zetmeel)
--   - Cottage cheese (4x)  dairy_desserts -> cheese_snacks
--       (hartige kwark-achtige kaas, geen zoet toetje -- dit was de
--       oorzaak van de Solero-ijslolly-swap-suggestie)
--   - Kokos melk (1x)      chocolate_confectionery -> plant_based_dairy
--   - Pinda kaas (3x)      cheese_snacks -> nut_butters
--       ("pindakaas" is pindapasta, geen kaas -- waarschijnlijk een
--       regex die op "kaas" matchte)
--   - Tomaten soep (1x)    cereal_bars -> soups
--   - Tomaten Ketchup (1x) fresh_vegetables -> sauces_dips
--       (waarschijnlijk gevangen door de "tomaten"-regel in
--       fresh_vegetables, want ketchup bevat "tomaten" in de naam)
--   - Melkchocolade (1x)   cereal_bars -> chocolate_bars
--
-- Bewust NIET aangeraakt (onderzocht, maar legitieme variatie, geen
-- fout): couscous, eierkoeken, framboos, maiskorrels, nasigoreng,
-- naturel/original/light (te generiek), orange, paprika -- deze namen
-- verschijnen terecht in meerdere families omdat het om aantoonbaar
-- verschillende producttypes gaat (bv. "Paprika" de groente vs.
-- paprika-chips).
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

-- Stap 1: snapshot (alle 15 barcodes, huidige staat).
create table if not exists public._snapshot_0073_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  '4718098550654','8718906006720','8718546991202','8718906773493',
  '7640101096682','7640101092547','8718906515772','9009865005923',
  '8718452877157',
  '8718452574902','8718452491650','8718452378203',
  '20521721',
  '8719587146354',
  '8713500010449'
);

-- Stap 2: correcties per groep.
update public.product_features set
  swap_family = 'nuts_seeds', classification_confidence = 0.6,
  classification_reason = 'correction_0073: chiazaad is een zaad-snackingrediënt, geen graan/zetmeel',
  classified_at = now()
where barcode in ('4718098550654','8718906006720','8718546991202','8718906773493');

update public.product_features set
  swap_family = 'cheese_snacks', classification_confidence = 0.6,
  classification_reason = 'correction_0073: cottage cheese is hartige kwark-achtige kaas, geen zoet toetje',
  classified_at = now()
where barcode in ('7640101096682','7640101092547','8718906515772','9009865005923');

update public.product_features set
  swap_family = 'plant_based_dairy', classification_confidence = 0.6,
  classification_reason = 'correction_0073: kokosmelk is een plantaardige melkdrank, geen chocoladeproduct',
  classified_at = now()
where barcode = '8718452877157';

update public.product_features set
  swap_family = 'nut_butters', classification_confidence = 0.6,
  classification_reason = 'correction_0073: pindakaas is pindapasta, geen kaas',
  classified_at = now()
where barcode in ('8718452574902','8718452491650','8718452378203');

update public.product_features set
  swap_family = 'soups', classification_confidence = 0.6,
  classification_reason = 'correction_0073: tomatensoep is een soep, geen graanreep',
  classified_at = now()
where barcode = '20521721';

update public.product_features set
  swap_family = 'sauces_dips', classification_confidence = 0.6,
  classification_reason = 'correction_0073: tomatenketchup is een saus, geen verse groente',
  classified_at = now()
where barcode = '8719587146354';

update public.product_features set
  swap_family = 'chocolate_bars', classification_confidence = 0.6,
  classification_reason = 'correction_0073: melkchocolade is een chocoladereep, geen graanreep',
  classified_at = now()
where barcode = '8713500010449';

-- POSTFLIGHT (read-only):
-- select barcode, name, swap_family from product_features_resolved
--   where barcode in ('4718098550654','8718906006720','8718546991202','8718906773493','7640101096682','7640101092547','8718906515772','9009865005923','8718452877157','8718452574902','8718452491650','8718452378203','20521721','8719587146354','8713500010449')
--   order by swap_family;
-- select count(*) from product_features_resolved; -- moet exact gelijk blijven aan aantal products
-- select count(*) from product_features where swap_family is not null and classification_status is null; -- moet 0 blijven

-- ROLLBACK (exact, via de snapshot-tabel):
-- update public.product_features pf set
--   swap_family = s.swap_family, is_swap_relevant = s.is_swap_relevant,
--   classification_status = s.classification_status, classification_confidence = s.classification_confidence,
--   classification_reason = s.classification_reason, matched_rule_id = s.matched_rule_id,
--   rule_version = s.rule_version, mapping_version = s.mapping_version,
--   source_fingerprint = s.source_fingerprint, classified_at = s.classified_at
-- from public._snapshot_0073_before s
-- where pf.barcode = s.barcode;
-- drop table public._snapshot_0073_before; -- pas na bevestigde, succesvolle rollback
