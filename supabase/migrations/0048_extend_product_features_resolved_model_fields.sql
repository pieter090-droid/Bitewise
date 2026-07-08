-- Additieve uitbreiding van `product_features_resolved` (expliciet
-- goedgekeurd): 7 boolean-velden die het SwapScore-model nodig heeft voor
-- de vergelijkbaarheids-/bewerkingskwaliteitsblokken, en die al op
-- `product_features` bestaan maar niet in de view (0039) waren opgenomen.
-- Verandert verder niets: identieke velden/joins als 0039, geen writes naar
-- `products`/`product_features`, geen nieuwe regels, geen backfill.

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
  end as is_swap_relevant,
  -- Nieuw in 0048: aan het eind toegevoegd (Postgres staat `create or replace
  -- view` alleen toe als nieuwe kolommen aan het EIND van de lijst staan --
  -- ertussen invoegen probeert bestaande kolommen te hernoemen en faalt).
  pf.is_sweet, pf.is_salty, pf.is_drink, pf.is_dairy, pf.is_chocolate,
  pf.is_crunchy, pf.is_less_processed
from public.products p
left join public.product_features pf on pf.barcode = p.barcode
left join public.swap_family_mapping m on m.swap_family = pf.swap_family;

grant select on public.product_features_resolved to anon, authenticated;

-- POSTFLIGHT (read-only):
-- select count(*) from product_features_resolved; -- moet exact 15.128 zijn
-- select count(distinct barcode) from product_features_resolved; -- ook 15.128
-- select column_name from information_schema.columns where table_name='product_features_resolved'
--   and column_name in ('is_sweet','is_salty','is_drink','is_dairy','is_chocolate','is_crunchy','is_less_processed');
--   -- moet 7 rijen zijn
-- select is_swap_relevant, count(*) from product_features_resolved group by 1; -- moet 8.970 true / 6.158 false blijven

-- ROLLBACK: create or replace view public.product_features_resolved as <exacte 0039-definitie>;
-- (of: drop view public.product_features_resolved; -- alleen als niets meer afhankelijk is)
