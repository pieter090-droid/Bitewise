-- 0005_snackswap_backfill.sql
-- Backfill van UITSLUITEND objectieve, rule-based velden in product_features.
-- Idempotent: ON CONFLICT DO UPDATE raakt alleen de objectieve kolommen aan en
-- laat AI-velden (snack_type, taste_profile, ...) ongemoeid, zodat een herhaalde
-- run toekomstige AI-verrijking niet overschrijft.
-- Grondslag: per 100 g; ontbrekende brondata => NULL (nooit false).

with d as (
  select
    p.barcode, p.name, p.kcal_100g, p.sugar_100g, p.protein_100g,
    p.fat_100g, p.saturated_fat_100g, p.fiber_100g, p.salt_100g,
    p.nova_group, p.ingredients_tags, p.ingredients_analysis_tags,
    p.additives_tags, p.allergens, p.categories_tags, p.category, p.pnns_groups_1,
    -- is_drink stuurt de drank-drempels, dus eerst afleiden.
    case
      when p.categories_tags is null and p.pnns_groups_1 is null then null
      when p.pnns_groups_1 ilike '%beverage%'
        or p.categories_tags ilike '%en:beverages%'
        or p.categories_tags ilike '%drinks%' then true
      else false
    end as is_drink
  from public.products p
)
insert into public.product_features as pf (
  barcode, data_quality_score, ingredient_count,
  is_drink, is_dairy, is_chocolate, has_palm_oil, has_sweeteners,
  is_low_sugar, is_high_fiber, is_high_protein, is_low_kcal, is_less_processed
)
select
  d.barcode,
  public.calculate_product_data_quality(d.barcode),
  case when nullif(trim(d.ingredients_tags), '') is null then null
       else array_length(string_to_array(d.ingredients_tags, ','), 1) end,
  d.is_drink,
  -- is_dairy
  case when d.allergens is null and d.categories_tags is null then null
       when d.allergens ilike '%milk%' or d.categories_tags ilike '%dairy%' then true
       else false end,
  -- is_chocolate
  case when d.categories_tags is null and d.category is null then null
       when d.categories_tags ilike '%chocolate%' or d.category ilike '%chocolate%' then true
       else false end,
  -- has_palm_oil (let op: palm-oil-free bevat 'palm-oil' als substring)
  case when d.ingredients_analysis_tags is null then null
       when d.ingredients_analysis_tags ilike '%en:palm-oil-free%' then false
       when d.ingredients_analysis_tags ilike '%en:palm-oil%' then true
       else null end,
  -- has_sweeteners: zoetstof/polyol E-nummers (E420/421, E950-969)
  case when d.additives_tags is null then null
       when d.additives_tags ~* 'e(420|421|95[0-9]|96[0-9])(\D|$)' then true
       else false end,
  -- is_low_sugar (EU: <=5 g vast / <=2,5 g drank)
  case when d.sugar_100g is null then null
       when d.is_drink is true then d.sugar_100g <= 2.5
       else d.sugar_100g <= 5 end,
  -- is_high_fiber (EU: >=6 g)
  case when d.fiber_100g is null then null else d.fiber_100g >= 6 end,
  -- is_high_protein (EU: >=20% van de energie uit eiwit)
  case when d.protein_100g is null or d.kcal_100g is null or d.kcal_100g = 0 then null
       else (d.protein_100g * 4) >= (0.20 * d.kcal_100g) end,
  -- is_low_kcal (snack-realistisch: <=150 kcal vast / <=20 kcal drank)
  case when d.kcal_100g is null then null
       when d.is_drink is true then d.kcal_100g <= 20
       else d.kcal_100g <= 150 end,
  -- is_less_processed (NOVA <=2; alleen als NOVA bekend)
  case when d.nova_group is null then null else d.nova_group <= 2 end
from d
on conflict (barcode) do update set
  data_quality_score = excluded.data_quality_score,
  ingredient_count   = excluded.ingredient_count,
  is_drink           = excluded.is_drink,
  is_dairy           = excluded.is_dairy,
  is_chocolate       = excluded.is_chocolate,
  has_palm_oil       = excluded.has_palm_oil,
  has_sweeteners     = excluded.has_sweeteners,
  is_low_sugar       = excluded.is_low_sugar,
  is_high_fiber      = excluded.is_high_fiber,
  is_high_protein    = excluded.is_high_protein,
  is_low_kcal        = excluded.is_low_kcal,
  is_less_processed  = excluded.is_less_processed,
  updated_at         = now();
