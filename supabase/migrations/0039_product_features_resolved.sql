-- Fase 1A (expliciet goedgekeurd). Vereist 0035-0038.
--
-- Schone uitleeslaag voor de Flutter-app. LEFT JOIN vanaf products (nooit
-- INNER) zodat elk product zichtbaar blijft, ook zonder product_features-rij
-- of zonder swap_family. Precies 1 rij per products.barcode gegarandeerd
-- door constructie (product_features.barcode en swap_family_mapping.swap_family
-- zijn allebei unieke sleutels waarop gejoined wordt, dus geen fan-out mogelijk).
create or replace view public.product_features_resolved as
select
  p.barcode, p.name, p.brand, p.image_url, p.category, p.categories_tags,
  p.pnns_groups_1, p.pnns_groups_2,
  p.kcal_100g, p.protein_100g, p.carbs_100g, p.sugar_100g, p.fat_100g,
  p.fiber_100g, p.salt_100g, p.saturated_fat_100g,
  p.serving_quantity, p.serving_size, p.kcal_serving, p.proteins_serving,
  p.sugars_serving, p.fiber_serving, p.salt_serving, p.saturated_fat_serving,
  p.nova_group, p.nutriscore_grade, p.nutriscore_score,
  p.ingredients_text, p.ingredients_tags, p.additives_n, p.additives_tags,
  p.completeness, p.states_tags, p.allergens,
  pf.classification_status, pf.classification_confidence, pf.classification_reason,
  pf.matched_rule_id, pf.swap_family,
  pf.taste_profile, pf.texture_profile, pf.use_moment, pf.swap_tags,
  pf.recommended_swap_directions, pf.processing_quality_score,
  pf.data_quality_score, pf.ai_confidence, pf.has_sweeteners,
  pf.has_palm_oil, pf.ingredient_count,
  m.category_cluster, m.snack_type, m.product_form, m.consumption_mode,
  m.secondary_consumption_modes, m.usage_context, m.is_swap_relevant_default,
  case
    when pf.classification_status = 'classified' then m.is_swap_relevant_default
    else false
  end as is_swap_relevant
from public.products p
left join public.product_features pf on pf.barcode = p.barcode
left join public.swap_family_mapping m on m.swap_family = pf.swap_family;

grant select on public.product_features_resolved to anon, authenticated;

-- POSTFLIGHT (read-only, verplicht vóór live-gebruik):
-- select count(*) from product_features_resolved; -- moet exact 15.128 zijn
-- select count(distinct barcode) from product_features_resolved; -- moet ook 15.128 zijn (bevestigt geen dubbele rijen)
-- select count(*) from product_features_resolved where is_swap_relevant = true and classification_status != 'classified'; -- moet 0 zijn
-- select count(*) from product_features_resolved where classification_status is null; -- verwacht: alle producten die nog niet
--   door de nieuwe regelmotor zijn gehaald (bij fase 1 is dat nog ALLES, want classification_status wordt pas in migratie 10 gevuld)

-- ROLLBACK: drop view public.product_features_resolved;
