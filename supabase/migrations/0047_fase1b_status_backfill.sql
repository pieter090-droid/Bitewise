-- Fase 1B, stap 4: status-backfill voor bestaande geldige swap_family-
-- classificaties die nog geen classification_status hebben (legacy rijen
-- van vóór de status-kolommen). Raakt geen swap_family, nutritionele
-- waarden, products, of matched_rule_id (blijft null bij legacy backfill).

create table if not exists public._snapshot_fase1b_before as
select barcode, classification_status, classification_confidence,
       classification_reason, mapping_version, classified_at, source_fingerprint
from public.product_features pf
where pf.classification_status is null
  and pf.swap_family is not null
  and exists (select 1 from public.swap_family_mapping m where m.swap_family = pf.swap_family);

with fingerprint as (
  select barcode,
    md5(
      coalesce(name,'') || '|' || coalesce(category,'') || '|' ||
      coalesce(categories_tags,'') || '|' || coalesce(pnns_groups_1,'') || '|' ||
      coalesce(pnns_groups_2,'') || '|' || coalesce(ingredients_text,'') || '|' ||
      coalesce(ingredients_tags,'')
    ) as fp
  from public.products
)
update public.product_features pf set
  classification_status = 'classified',
  classification_confidence = 0.80,
  classification_reason = 'legacy_existing_valid_family_status_backfill',
  mapping_version = 1,
  classified_at = now(),
  source_fingerprint = f.fp
from fingerprint f
where pf.barcode = f.barcode
  and pf.barcode in (select barcode from public._snapshot_fase1b_before);

-- POSTFLIGHT (read-only):
-- select count(*) from product_features where classification_reason = 'legacy_existing_valid_family_status_backfill';
-- select count(*) from product_features where classification_status is null and swap_family is not null; -- orphans, moet 0 zijn
-- select count(*) from product_features where classification_status is null; -- resterend zonder status

-- ROLLBACK (exact, via de snapshot-tabel):
-- update public.product_features pf set
--   classification_status = s.classification_status,
--   classification_confidence = s.classification_confidence,
--   classification_reason = s.classification_reason,
--   mapping_version = s.mapping_version,
--   classified_at = s.classified_at,
--   source_fingerprint = s.source_fingerprint
-- from public._snapshot_fase1b_before s
-- where pf.barcode = s.barcode;
-- drop table public._snapshot_fase1b_before; -- pas na bevestigde, succesvolle rollback
