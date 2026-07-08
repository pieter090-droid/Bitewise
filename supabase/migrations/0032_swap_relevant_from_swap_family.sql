-- ---------------------------------------------------------------------------
-- is_swap_relevant volgde tot nu toe UITSLUITEND de oude, pre-taxonomy-v2
-- regel (compute_swap_relevance: pnns_groups_1 in Sugary/Salty snacks,
-- Beverages, Milk and dairy products, of pnns_groups_2 Breakfast cereals/
-- Fruits/Dried fruits, of een keyword-rescue zonder brood/maaltijd-termen).
--
-- Toen dit seizoen swap_family werd uitgebreid met bread_bakery,
-- sandwiches_wraps, ready_meals, soups, meal_components, cold_cuts,
-- savory_spreads, hummus_legume_spreads, meat_snacks, supplements_powders
-- enz. is is_swap_relevant nooit teruggekoppeld: die categorieen werden wel
-- correct geclassificeerd (swap_family gezet) maar bleven onzichtbaar voor
-- de hele swap-feature, want is_swap_relevant = false sluit een product uit
-- als zowel bronproduct als kandidaat (zie getCandidatesForCluster in
-- snackswap_service.dart, en de eerste check in ruleBasedSwapProvider).
--
-- Concreet gevonden via een live-check met een broodproduct (barcode
-- 9712187104662, "Volkoren brood" Ah): correct swap_family=bread_bakery,
-- maar is_swap_relevant=false -> "Geen swaps gevonden" voor alle 4 doelen.
-- Steekproef op alle 47 swap_family-waarden: 4.212 producten hebben een
-- geldige swap_family maar is_swap_relevant=false -- bijna evenveel als de
-- huidige actieve pool (4.968). Deze fix is puur additief: niets dat nu
-- werkt stopt met werken, het maakt alleen al-geclassificeerde producten
-- alsnog zichtbaar.
-- ---------------------------------------------------------------------------
create or replace function public.compute_product_features()
returns trigger language plpgsql as $$
declare
  v_is_drink boolean;
  v_reason   text;
  v_cluster  text;
  v_family   text;
  v_map      record;
  v_relevant boolean;
begin
  v_is_drink := case
    when NEW.categories_tags is null and NEW.pnns_groups_1 is null then null
    when NEW.pnns_groups_1 ilike '%beverage%'
      or NEW.categories_tags ilike '%en:beverages%'
      or NEW.categories_tags ilike '%drinks%' then true
    else false end;

  v_reason := public.compute_swap_relevance(NEW.pnns_groups_1, NEW.pnns_groups_2, NEW.categories_tags);
  v_family := public.compute_swap_family(NEW.name, NEW.category, NEW.categories_tags, NEW.pnns_groups_1, NEW.pnns_groups_2);
  select * into v_map from public.swap_family_mapping where swap_family = v_family;

  v_relevant := (v_reason is not null) or (v_family is not null and v_family <> 'unknown');
  v_cluster := case when v_relevant
    then public.compute_cluster_key(NEW.categories_tags, NEW.main_category,
                                    NEW.kcal_100g, NEW.sugar_100g, NEW.protein_100g)
    else null end;

  insert into public.product_features as pf (
    barcode, data_quality_score, ingredient_count,
    is_drink, is_dairy, is_chocolate, has_palm_oil, has_sweeteners,
    is_low_sugar, is_high_fiber, is_high_protein, is_low_kcal, is_less_processed,
    is_swap_relevant, swap_relevance_reason, cluster_key,
    swap_family, category_cluster, snack_type, product_form, consumption_mode,
    secondary_consumption_modes, usage_context
  ) values (
    NEW.barcode,
    public.calculate_product_data_quality(NEW.barcode),
    case when nullif(trim(NEW.ingredients_tags), '') is null then null
         else array_length(string_to_array(NEW.ingredients_tags, ','), 1) end,
    v_is_drink,
    case when NEW.allergens is null and NEW.categories_tags is null then null
         when NEW.allergens ilike '%milk%' or NEW.categories_tags ilike '%dairy%' then true else false end,
    case when NEW.categories_tags is null and NEW.category is null then null
         when NEW.categories_tags ilike '%chocolate%' or NEW.category ilike '%chocolate%' then true else false end,
    case when NEW.ingredients_analysis_tags is null then null
         when NEW.ingredients_analysis_tags ilike '%en:palm-oil-free%' then false
         when NEW.ingredients_analysis_tags ilike '%en:palm-oil%' then true else null end,
    case when NEW.additives_tags is null then null
         when NEW.additives_tags ~* 'e(420|421|95[0-9]|96[0-9])(\D|$)' then true else false end,
    case when NEW.sugar_100g is null then null
         when v_is_drink is true then NEW.sugar_100g <= 2.5 else NEW.sugar_100g <= 5 end,
    case when NEW.fiber_100g is null then null else NEW.fiber_100g >= 6 end,
    case when NEW.protein_100g is null or NEW.kcal_100g is null or NEW.kcal_100g = 0 then null
         else (NEW.protein_100g * 4) >= (0.20 * NEW.kcal_100g) end,
    case when NEW.kcal_100g is null then null
         when v_is_drink is true then NEW.kcal_100g <= 20 else NEW.kcal_100g <= 150 end,
    case when NEW.nova_group is null then null else NEW.nova_group <= 2 end,
    v_relevant,
    coalesce(v_reason, case when v_relevant then 'swap_family_v2' else null end),
    v_cluster,
    v_family,
    coalesce(v_map.category_cluster, null), coalesce(v_map.snack_type, null),
    coalesce(v_map.product_form, null), coalesce(v_map.consumption_mode, null),
    coalesce(v_map.secondary_consumption_modes, '{}'), coalesce(v_map.usage_context, '{}')
  )
  on conflict (barcode) do update set
    data_quality_score    = excluded.data_quality_score,
    ingredient_count      = excluded.ingredient_count,
    is_drink              = excluded.is_drink,
    is_dairy              = excluded.is_dairy,
    is_chocolate          = excluded.is_chocolate,
    has_palm_oil          = excluded.has_palm_oil,
    has_sweeteners        = excluded.has_sweeteners,
    is_low_sugar          = excluded.is_low_sugar,
    is_high_fiber         = excluded.is_high_fiber,
    is_high_protein       = excluded.is_high_protein,
    is_low_kcal           = excluded.is_low_kcal,
    is_less_processed     = excluded.is_less_processed,
    is_swap_relevant      = excluded.is_swap_relevant,
    swap_relevance_reason = excluded.swap_relevance_reason,
    cluster_key           = excluded.cluster_key,
    swap_family           = excluded.swap_family,
    category_cluster      = excluded.category_cluster,
    snack_type            = excluded.snack_type,
    product_form          = excluded.product_form,
    consumption_mode      = excluded.consumption_mode,
    secondary_consumption_modes = excluded.secondary_consumption_modes,
    usage_context         = excluded.usage_context,
    updated_at            = now();
  return NEW;
end $$;

-- ---------------------------------------------------------------------------
-- Backfill: alle bestaande rijen met een geldige swap_family maar
-- is_swap_relevant=false alsnog op relevant zetten, en cluster_key vullen
-- zodat toekomstige AI-verrijking/representant-selectie ze ook meeneemt.
-- ---------------------------------------------------------------------------
update public.product_features pf set
  is_swap_relevant      = true,
  swap_relevance_reason = coalesce(pf.swap_relevance_reason, 'swap_family_v2'),
  cluster_key           = coalesce(pf.cluster_key,
                             public.compute_cluster_key(p.categories_tags, p.main_category,
                                                         p.kcal_100g, p.sugar_100g, p.protein_100g)),
  updated_at            = now()
from public.products p
where p.barcode = pf.barcode
  and coalesce(pf.is_swap_relevant, false) = false
  and pf.swap_family is not null
  and pf.swap_family <> 'unknown';

-- Representanten opnieuw bepalen zodat de net vrijgekomen clusters ook een
-- representant krijgen (voor toekomstige, kostenbewuste AI-verrijking).
select public.refresh_swap_representatives();
