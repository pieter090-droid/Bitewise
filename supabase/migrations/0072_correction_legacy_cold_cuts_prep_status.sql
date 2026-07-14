-- VOORSTEL — NOG NIET UITGEVOERD. Wacht op expliciet akkoord vóór
-- `supabase db push`. Barcode-verankerde correctie, ontdekt tijdens
-- live-verificatie in de app: de swap-suggestie voor "Filet americain"
-- gaf "Kipfillet" en "Varkensbraadworst" als alternatief -- beide
-- legacy-geclassificeerd als `cold_cuts` (classification_reason
-- 'legacy_existing_valid_family_status_backfill', dus van vóór deze
-- sessie), terwijl het rauwe/te-bereiden producten zijn.
--
-- Handmatig alle 280 legacy `cold_cuts`-producten doorgelopen. Twee
-- categorieën fouten gevonden:
--
--   A) Expliciet rauw/te bereiden (braadworst/bratwurst/chipolata/
--      "à griller"/BBQ-worstjes) -> raw_meat. 9 producten.
--   B) Kale, dubbelzinnige naam ("Kipfillet"/"Kalkoenfilet"/"Poulet"/
--      "Gebruide worstjes") -- kan zowel rauw vlees als dungesneden
--      deli-beleg zijn, niet uit de naam te bepalen. Zelfde
--      terughoudendheid als de Meat-bucket-analyse in migratie 0056:
--      -> review_required, geen gok. 7 producten.
--
-- De overige 264 legacy cold_cuts-producten (ham/salami/cervelaat/
-- rookworst/leverworst/paté/knakworst/etc.) zijn wél terecht -- allemaal
-- kant-en-klare vleeswaren, niet aangeraakt.
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

-- Stap 1: snapshot (alle 16 barcodes, huidige staat).
create table if not exists public._snapshot_0072_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  '8718906904590','8718906904309','2221157010997','4335619012691','8717545694510',
  '03113318','5063334033576','4056489051817','4056489793601',
  '8718907715805','8713999994602','8718452677849','8710624351908','8718907715812',
  '2351881202006','20289676'
);

-- Stap 2A: expliciet rauw -> raw_meat.
update public.product_features pf set
  swap_family = 'raw_meat',
  classification_confidence = 0.55,
  classification_reason = 'correction_0072: legacy cold_cuts was fout -- naam bevat expliciet rauw/te-bereiden-signaal (braadworst/bratwurst/chipolata/à griller/BBQ), geen kant-en-klaar vleeswaren',
  classified_at = now()
where pf.barcode in (
  '8718906904590','8718906904309','2221157010997','4335619012691','8717545694510',
  '03113318','5063334033576','4056489051817','4056489793601'
);

-- Stap 2B: kale, dubbelzinnige naam -> review_required, geen swap_family-gok.
update public.product_features pf set
  swap_family = null,
  classification_status = 'review_required',
  classification_confidence = 0.3,
  classification_reason = 'correction_0072: legacy cold_cuts was mogelijk fout -- kale naam (kipfillet/kalkoenfilet/poulet/gekruide worstjes) geeft geen rauw-of-kant-en-klaar-signaal, niet te bepalen',
  classified_at = now()
where pf.barcode in (
  '8718907715805','8713999994602','8718452677849','8710624351908','8718907715812',
  '2351881202006','20289676'
);

-- POSTFLIGHT (read-only):
-- select barcode, swap_family, classification_status from product_features
--   where barcode in ('8718906904590','8718906904309','2221157010997','4335619012691','8717545694510','03113318','5063334033576','4056489051817','4056489793601');
--   -- alle 9 moeten swap_family='raw_meat' hebben
-- select barcode, swap_family, classification_status from product_features
--   where barcode in ('8718907715805','8713999994602','8718452677849','8710624351908','8718907715812','2351881202006','20289676');
--   -- alle 7 moeten swap_family=null, classification_status='review_required' hebben
-- select count(*) from product_features_resolved; -- moet exact gelijk blijven aan aantal products
-- select count(*) from product_features where swap_family='cold_cuts' and classification_reason='legacy_existing_valid_family_status_backfill'; -- moet nu 264 zijn (280-16)

-- ROLLBACK (exact, via de snapshot-tabel):
-- update public.product_features pf set
--   swap_family = s.swap_family, is_swap_relevant = s.is_swap_relevant,
--   classification_status = s.classification_status, classification_confidence = s.classification_confidence,
--   classification_reason = s.classification_reason, matched_rule_id = s.matched_rule_id,
--   rule_version = s.rule_version, mapping_version = s.mapping_version,
--   source_fingerprint = s.source_fingerprint, classified_at = s.classified_at
-- from public._snapshot_0072_before s
-- where pf.barcode = s.barcode;
-- drop table public._snapshot_0072_before; -- pas na bevestigde, succesvolle rollback
