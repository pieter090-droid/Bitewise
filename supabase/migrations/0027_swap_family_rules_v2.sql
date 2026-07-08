-- ---------------------------------------------------------------------------
-- Nieuwe classificatiefunctie: bepaalt ALLEEN nog swap_family (via regels,
-- prioriteit fijn -> grof, met uitsluitingen zoals in de hard_rules-spec).
-- De andere velden komen niet meer hieruit -- die worden in stap 2 (trigger)
-- deterministisch opgehaald uit swap_family_mapping.
-- ---------------------------------------------------------------------------
create or replace function public.compute_swap_family(
  p_name text, p_category text, p_categories_tags text, p_pnns1 text, p_pnns2 text
) returns text
language plpgsql immutable as $$
declare
  n  text := coalesce(p_name, '');
  c  text := coalesce(p_category, '') || ' ' || coalesce(p_categories_tags, '');
  p1 text := coalesce(p_pnns1, '');
  p2 text := coalesce(p_pnns2, '');
  v_is_drink_named boolean;
  v_is_light_zero boolean;
begin
  v_is_drink_named := (n ~* '\mdrink\M|drank|drinkyoghurt|drinkyogur' or c ~* 'drinkable');
  v_is_light_zero  := (n ~* '\mzero\M|\mlight\M|suikervrij|no sugar|sugar.?free|\mdiet\M');

  -- Smeersels/pasta's (regel 12: broodbeleg-achtigen zijn primair spreads).
  if n ~* 'smeerkaas|cream cheese spread|roomkaas smeerbaar' then
    return 'savory_spreads';
  elsif n ~* 'pindakaas|peanut butter|amandelpasta|notenpasta|cashewpasta|hazelnootpasta' then
    return 'nut_butters';
  elsif n ~* 'hummus|houmous|humus\M' then
    return 'hummus_legume_spreads';
  elsif n ~* 'nutella|chocopasta|choco.?pasta' or c ~* 'chocolate.?spread|cocoa.and.hazelnut' then
    return 'chocolate_spreads';
  elsif n ~* 'honing|\mhoney\M|\msiroop\M|\msyrup\M|agave|maple syrup|ahornsiroop' then
    return 'honey_syrups';
  elsif n ~* 'jam|confiture|marmelade' then
    return 'jams_fruit_spreads';
  elsif n ~* 'hagelslag' then
    return 'sweet_spreads_other';

  -- Repen (regel 9: eiwitreep is geen gewone chocoladereep).
  elsif n ~* 'eiwitreep|protein bar' or c ~* 'protein.?bar' then
    return 'protein_bars';
  elsif n ~* 'mueslireep|cerealreep|granolareep' or c ~* 'cereal.?bar' then
    return 'cereal_bars';
  elsif n ~* 'chocoladereep|candy bar' or c ~* 'chocolate.?bar' then
    return 'chocolate_bars';

  -- Chocolade-snoep (regel 7: chocoladepasta is geen chocoladereep -- al
  -- geregeld doordat spreads hierboven staan en dit pas hierna gecheckt wordt).
  elsif c ~* 'pralines|bonbons|chocolates|filled.chocolates' or p2 ~* 'chocolate'
        or n ~* 'bonbon|praline|\mmerci\M' then
    return 'chocolate_confectionery';
  elsif n ~* 'drop\M|winegum|toffee|marshmallow|spekjes|schuimpjes|zuurtjes|\mlolly|fruittella|napoleon|venco' then
    return 'candy_sweets';

  elsif n ~* '\mijs\M|ice cream|sorbet|gelato' then
    return 'ice_cream_desserts';

  -- Zuivel(drank) -- volgorde: smoothie/plantaardig eerst, dan gewone
  -- yoghurt-cup (regel 8: drinkyoghurt is geen yoghurtcup), dan zuiveldrank.
  elsif n ~* '\msmoothie\M' then
    return 'smoothies';
  elsif n ~* 'havermelk|amandelmelk|sojamelk|kokosmelk|\moatly\M|\malpro\M|plantaardige melk|soja.?drink|haver.?drink' then
    return 'plant_based_dairy';
  elsif n ~* 'yoghurt|yaourt|yogur|joghurt|skyr|kwark|quark'
        and not (v_is_drink_named or n ~* 'dressing|saus|sauce|\mdip\M') then
    return 'yoghurt_skyr_quark';
  elsif n ~* 'chocomel|karnemelk|milkshake|yogidrink' or (v_is_drink_named and (p1 ~* 'dairy|milk' or n ~* 'melk|yoghurt|yogur')) then
    return 'dairy_drinks';
  elsif not v_is_drink_named
        and (c ~* 'tiramisu|dairy-desserts'
             or (n ~* 'pudding|mousse|\mvla\M|dessert' and (p1 ~* 'dairy|milk' or p2 ~* 'dairy|milk|dessert'))) then
    return 'dairy_desserts';

  -- Gebak vs. koek (nieuw onderscheid).
  elsif n ~* '\mtaart\M|gebak|\mcake\M' then
    -- (chocolate_bars/cereal_bars staan hierboven al met hogere prioriteit,
    -- dus een "cake bar" is dan al eerder als reep geclassificeerd.)
    return 'cakes_pastries';
  elsif p2 ~* 'biscuits|cookies' or n ~* '\mkoek|cookie' then
    return 'cookies_biscuits';
  elsif n ~* 'cracker|beschuit|rice cake|knackebrod' or c ~* 'cracker' then
    return 'crackers_rice_cakes';

  -- Ontbijt/brood.
  elsif n ~* '\mgranola\M|muesli' then
    return 'granola_muesli';
  elsif p2 ~* 'breakfast cereal' or n ~* 'cornflakes|ontbijtgranen|cruesli' then
    return 'breakfast_cereals';
  elsif n ~* 'broodje|\mwrap\M|sandwich' then
    return 'sandwiches_wraps';
  elsif n ~* '\mbrood\M|croissant|stokbrood|bolletje|baguette' or p2 ~* '\mbread\M' then
    return 'bread_bakery';

  -- Vlees.
  elsif n ~* 'droge worst|beef jerky|cabanossi|snackworst|biltong' then
    return 'meat_snacks';
  elsif n ~* '\mham\M|salami|cervelaat|rookvlees|\mpat[ée]\M|leverworst|kipfilet|achterham|vleeswaren'
        or p2 ~* 'processed meat' then
    return 'cold_cuts';

  elsif n ~* 'popcorn' or c ~* 'popcorn' then
    return 'popcorn';
  elsif n ~* 'chips|crisps' or c ~* 'chips|crisps' then
    return 'crisps_chips';
  elsif p2 ~* '\mcheese\M' or n ~* '\mkaas\M|\mcheese\M' then
    return 'cheese_snacks';

  elsif n ~* 'bier|\mwijn\M|wodka|whisky|whiskey|\mrum\M|\mgin\M|likeur|prosecco|cava\M' or p1 ~* 'alcoholic' then
    return 'alcohol_drinks';

  -- Dranken: energy/sport eerst (specifieker), dan zero/light vs. regular.
  elsif n ~* 'red bull|monster energy|\maa\M drink|energy ?drink|rockstar' then
    return 'energy_drinks';
  elsif n ~* 'isostar|gatorade|powerade|sportdrank|aquarius' then
    return 'sports_drinks';
  elsif v_is_light_zero and (n ~* '\mcola\M|frisdrank|\msoda\M|limonade|fanta|sprite|\m7up\M|tonic|bitter lemon|ice.?tea|rivella|sisi\M' or p2 ~* 'sweetened beverages') then
    return 'soft_drinks_light_zero';
  elsif n ~* '\mcola\M|frisdrank|\msoda\M|limonade|fanta|sprite|\m7up\M|tonic|bitter lemon|ice.?tea|rivella|sisi\M'
        or p2 ~* 'sweetened beverages' then
    return 'soft_drinks_regular';
  elsif n ~* '\msap\M|juice' or c ~* 'juice' then
    return 'fruit_juices';
  elsif n ~* 'koffie|\mcoffee\M|cappuccino|espresso|latte\M|\mthee\M|\mtea\M' or p2 ~* 'coffee and tea' then
    return 'hot_beverages';
  elsif (n ~* '\mwater\M|bronwater|mineraalwater' or p2 ~* 'waters and flavored waters')
        and not v_is_drink_named then
    return 'water';

  elsif (p2 ~* '\mnuts\M' or n ~* 'noten|zaden|amandelen|cashew|walnoot|hazelnoot') and not (n ~* 'pasta') then
    return 'nuts_seeds';

  elsif n ~* 'soep|\msoup\M' or p2 ~* '\msoup\M' then
    return 'soups';
  elsif (n ~* '\mdip\M|saus|sauce|dressing' or p2 ~* 'sauce|dressing')
        and not (n ~* 'boter|butter|\molie\M|olive oil') then
    return 'sauces_dips';

  elsif p2 ~* '\mfruits\M' and not v_is_drink_named then
    return 'fresh_fruit';
  elsif n ~* 'tomaten?\M|komkommer|worteltjes|wortel\M|\msla\M|paprika|\mui\M|uien\M|broccoli|spinazie|courgette|aubergine|\mprei\M|bloemkool|spruitjes|andijvie|\mboon\M|bonen\M|erwt' then
    return 'fresh_vegetables';

  elsif n ~* 'kant.?en.?klaar|magnetronmaaltijd|ovenschotel|maaltijdbox' then
    return 'ready_meals';
  elsif p1 ~* 'composite' or n ~* 'maaltijd|salade|\mmeal\M' then
    return 'meal_components';

  elsif n ~* 'eiwitpoeder|proteine ?poeder|\mwhey\M|supplement' then
    return 'supplements_powders';

  else
    return null;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Trigger herschreven: bepaalt swap_family via de regelfunctie, en haalt de
-- overige 4(+1) velden ALTIJD op uit swap_family_mapping -- nooit meer los
-- gegokt. Bestaande objectieve kolommen (is_low_sugar, cluster_key, enz.)
-- blijven ongewijzigd.
-- ---------------------------------------------------------------------------
create or replace function public.compute_product_features()
returns trigger language plpgsql as $$
declare
  v_is_drink boolean;
  v_reason   text;
  v_cluster  text;
  v_family   text;
  v_map      record;
begin
  v_is_drink := case
    when NEW.categories_tags is null and NEW.pnns_groups_1 is null then null
    when NEW.pnns_groups_1 ilike '%beverage%'
      or NEW.categories_tags ilike '%en:beverages%'
      or NEW.categories_tags ilike '%drinks%' then true
    else false end;

  v_reason := public.compute_swap_relevance(NEW.pnns_groups_1, NEW.pnns_groups_2, NEW.categories_tags);
  v_cluster := case when v_reason is not null
    then public.compute_cluster_key(NEW.categories_tags, NEW.main_category,
                                    NEW.kcal_100g, NEW.sugar_100g, NEW.protein_100g)
    else null end;

  v_family := public.compute_swap_family(NEW.name, NEW.category, NEW.categories_tags, NEW.pnns_groups_1, NEW.pnns_groups_2);
  select * into v_map from public.swap_family_mapping where swap_family = v_family;

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
    (v_reason is not null), v_reason, v_cluster,
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
-- Eenmalige herbackfill: ALLE rijen krijgen swap_family opnieuw bepaald +
-- category_cluster/snack_type/product_form/consumption_mode/secondary/
-- usage_context deterministisch uit de mapping -- vervangt de losse
-- classificatie van de vorige 0013-0025-reeks volledig en consistent.
-- ---------------------------------------------------------------------------
update public.product_features pf set
  swap_family                  = v.family,
  category_cluster             = m.category_cluster,
  snack_type                   = m.snack_type,
  product_form                 = m.product_form,
  consumption_mode             = m.consumption_mode,
  secondary_consumption_modes  = coalesce(m.secondary_consumption_modes, '{}'),
  usage_context                = coalesce(m.usage_context, '{}'),
  updated_at                   = now()
from public.products p,
     lateral (select public.compute_swap_family(
       p.name, p.category, p.categories_tags, p.pnns_groups_1, p.pnns_groups_2) as family) v
left join public.swap_family_mapping m on m.swap_family = v.family
where p.barcode = pf.barcode
  and pf.swap_family is distinct from v.family;
