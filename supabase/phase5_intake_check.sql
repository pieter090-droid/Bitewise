-- Fase 5b — read-only intakecontrole voor aanwas uit de live trigger.
-- Geeft uitsluitend nul rijen terug bij een schone intake. Gebruik :since
-- als ISO-timestamp in psql; standaardvoorbeeld: now() - interval '7 days'.

-- A. Geclassificeerd maar zonder familie.
select 'classified_without_family' as issue, pf.barcode, p.name,
       pf.swap_family, pf.classification_status, pf.classification_reason
from public.product_features pf
join public.products p using (barcode)
where pf.classified_at >= now() - interval '7 days'
  and pf.classification_reason like 'live_trigger%'
  and pf.classification_status = 'classified'
  and pf.swap_family is null;

-- B. Non-swapfamilie ten onrechte relevant.
select 'non_swap_relevant' as issue, pf.barcode, p.name,
       pf.swap_family, pf.classification_status, pf.classification_reason
from public.product_features pf
join public.products p using (barcode)
where pf.classified_at >= now() - interval '7 days'
  and pf.classification_reason like 'live_trigger%'
  and pf.swap_family like '%\_non\_swap' escape '\'
  and pf.is_swap_relevant is true;

-- C. Regular frisdrank met nutritioneel zero-profiel.
select 'zero_profile_still_regular' as issue, pf.barcode, p.name,
       pf.swap_family, pf.classification_status, pf.classification_reason
from public.product_features pf
join public.products p using (barcode)
where pf.classified_at >= now() - interval '7 days'
  and pf.classification_reason like 'live_trigger%'
  and pf.swap_family = 'soft_drinks_regular'
  and p.kcal_100g = 0
  and coalesce(p.sugar_100g, 0) <= 0.5
  and pf.classification_status = 'classified';

-- D. Ontbrekende ondubbelzinnige profieldefault.
select 'missing_family_default' as issue, pf.barcode, p.name,
       pf.swap_family, pf.classification_status, pf.classification_reason
from public.product_features pf
join public.products p using (barcode)
join public.swap_family_profile_defaults d using (swap_family)
where pf.classified_at >= now() - interval '7 days'
  and pf.classification_reason like 'live_trigger%'
  and pf.classification_status = 'classified'
  and ((d.d_is_sweet is not null and pf.is_sweet is null)
    or (d.d_is_salty is not null and pf.is_salty is null)
    or (d.d_is_crunchy is not null and pf.is_crunchy is null)
    or (d.d_taste is not null and (pf.taste_profile is null or cardinality(pf.taste_profile) = 0))
    or (d.d_texture is not null and (pf.texture_profile is null or cardinality(pf.texture_profile) = 0))
    or (d.d_moment is not null and (pf.use_moment is null or cardinality(pf.use_moment) = 0)));
