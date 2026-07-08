-- ---------------------------------------------------------------------------
-- Gevonden via live-test: "roomboter" leverde geen swap op. Oorzaak: pure
-- boter/margarine-producten hadden nooit een eigen swap_family (viel overal
-- doorheen, kwam op NULL uit) -- 27 producten geraakt (Roomboter, Becel
-- Light Boter, Bakboter, Kruidenboter, enz.).
--
-- Bij het uitzoeken bleek een tweede, verwant probleem in dezelfde data:
-- \m...\M (woordgrens) werkt niet voor Nederlandse samenstellingen zonder
-- spatie -- "appeltaart" bevat "taart" niet als los woord (geen grens vóór
-- "taart"), dus \mtaart\M miste "AH Roomboter appeltaart", "Roomboter
-- Appeltaart" enz. Zelfde voor \mkoek\M-varianten die niet "koek" heten
-- (jan hagel, spritsen, kletsmajoors, picolientje, speculaas).
-- ---------------------------------------------------------------------------

insert into public.swap_family_mapping
  (swap_family, category_cluster, snack_type, product_form, consumption_mode, secondary_consumption_modes, usage_context, related_families)
values
  ('butter_margarine', 'hartig', 'hartige_snack', 'spread', 'spread_on_bread', '{}', array['breakfast','lunch','cooking'], array['savory_spreads','nut_butters'])
on conflict (swap_family) do update set
  category_cluster = excluded.category_cluster,
  snack_type = excluded.snack_type,
  product_form = excluded.product_form,
  consumption_mode = excluded.consumption_mode,
  secondary_consumption_modes = excluded.secondary_consumption_modes,
  usage_context = excluded.usage_context,
  related_families = excluded.related_families;

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

  if n ~* 'smeerkaas|cream cheese spread|roomkaas smeerbaar' then
    return 'savory_spreads';
  elsif n ~* 'pindakaas|peanut butter|amandelpasta|notenpasta|cashewpasta|hazelnootpasta|pistachepasta|pistachio paste' then
    return 'nut_butters';
  elsif n ~* 'hummus|houmous|humus\M' then
    return 'hummus_legume_spreads';
  elsif n ~* 'nutella|chocopasta|choco.?pasta' or c ~* 'chocolate.?spread|cocoa.and.hazelnut' then
    return 'chocolate_spreads';
  elsif n ~* '\mjam\M|confiture|marmelade|fruitspread|vruchtenspread|fruit spread' then
    return 'jams_fruit_spreads';
  elsif n ~* 'hagelslag' then
    return 'sweet_spreads_other';

  elsif n ~* 'eiwitreep|protein bar' or c ~* 'protein.?bar' then
    return 'protein_bars';
  elsif n ~* 'mueslireep|cerealreep|granolareep' or c ~* 'cereal.?bar' then
    return 'cereal_bars';
  elsif n ~* 'chocoladereep|candy bar' or c ~* 'chocolate.?bar' then
    return 'chocolate_bars';

  elsif c ~* 'pralines|bonbons|chocolates|filled.chocolates|liquorice|licorice' or p2 ~* 'chocolate'
        or n ~* 'bonbon|praline|\mmerci\M|salmiak' then
    return 'chocolate_confectionery';
  elsif n ~* 'drop\M|winegum|toffee|marshmallow|spekjes|schuimpjes|zuurtjes|\mlolly|fruittella|napoleon|venco|fruit roll' then
    return 'candy_sweets';

  elsif n ~* '\mijs\M|ice cream|sorbet|gelato' or p2 ~* 'ice cream' then
    return 'ice_cream_desserts';

  elsif n ~* '\msmoothie\M' then
    return 'smoothies';
  elsif n ~* 'havermelk|amandelmelk|sojamelk|kokosmelk|\moatly\M|\malpro\M|plantaardige melk|soja.?drink|haver.?drink|barista.{0,10}(haver|oat|soja|soy)|(haver|oat|soja|soy).{0,10}barista' then
    return 'plant_based_dairy';
  elsif n ~* 'yoghurt|yaourt|yogur|joghurt|skyr|kwark|quark'
        and not (v_is_drink_named or n ~* 'dressing|saus|sauce|\mdip\M') then
    return 'yoghurt_skyr_quark';
  elsif n ~* 'chocomel|karnemelk|milkshake|yogidrink|\mcafe au lait\M|caf[ée] au lait' or (v_is_drink_named and (p1 ~* 'dairy|milk' or n ~* 'melk|yoghurt|yogur')) then
    return 'dairy_drinks';
  elsif not v_is_drink_named
        and (c ~* 'tiramisu|dairy-desserts'
             or (n ~* 'pudding|mousse|\mvla\M|dessert' and (p1 ~* 'dairy|milk' or p2 ~* 'dairy|milk|dessert'))) then
    return 'dairy_desserts';

  -- taart\M/flap\M (geen leidende \m) i.p.v. \mtaart\M: Nederlandse
  -- samenstellingen ("appeltaart", "appelflap") hebben geen woordgrens vóór
  -- het tweede deel. \mgebak\M blijft ongewijzigd (die \m voorkomt juist dat
  -- "Ovengebakken" hier ten onrechte in terechtkomt).
  elsif n ~* 'taart\M|\mgebak\M|cake\M|flap\M' then
    return 'cakes_pastries';
  elsif p2 ~* 'biscuits|cookies' or n ~* '\mkoek|koek\M|cookie|jan hagel|sprits|kletsmajoor|picolient|speculaas|\mkrans|biscuit' then
    return 'cookies_biscuits';
  elsif n ~* 'cracker|beschuit|rice cake|knackebrod' or c ~* 'cracker' then
    return 'crackers_rice_cakes';

  elsif n ~* '\mgranola\M|muesli' then
    return 'granola_muesli';
  elsif p2 ~* 'breakfast cereal' or n ~* 'cornflakes|ontbijtgranen|cruesli' then
    return 'breakfast_cereals';
  elsif n ~* 'broodje|\mwrap\M|sandwich' then
    return 'sandwiches_wraps';
  elsif n ~* '\mbrood\M|croissant|stokbrood|bolletje|baguette' or p2 ~* '\mbread\M' then
    return 'bread_bakery';

  elsif n ~* 'droge worst|beef jerky|cabanossi|snackworst|biltong' then
    return 'meat_snacks';
  elsif n ~* '\mham\M|salami|cervelaat|rookvlees|\mpat[ée]\M|leverworst|kipfilet|achterham|vleeswaren|boterhamworst'
        or p2 ~* 'processed meat' then
    return 'cold_cuts';

  elsif n ~* 'popcorn' or c ~* 'popcorn' then
    return 'popcorn';
  elsif n ~* 'chips|crisps' or c ~* 'chips|crisps' then
    return 'crisps_chips';
  elsif n ~* 'olijven|\molive\M|olives' then
    return 'sauces_dips';
  elsif p2 ~* '\mcheese\M' or n ~* '\mkaas\M|\mcheese\M' then
    return 'cheese_snacks';

  -- Pure boter/margarine (roomboter, bakboter, kruidenboter, margarine,
  -- halvarine). boter\M (suffix, geen leidende \m) vangt "roomboter" en
  -- "bakboter" maar NIET "boterham(worst)" (daar volgt nog "ham"/"hamworst"
  -- na "boter", dus geen woordgrens meteen na "boter"). Uitsluiting van
  -- aardappelproducten met kruidenboter-SMAAK (geen echte boter).
  elsif (n ~* 'boter\M|\mmargarine\M|\mhalvarine\M') and not (n ~* 'aardappel|frites|friet|krokett|croquett') then
    return 'butter_margarine';

  elsif n ~* 'bier|\mwijn\M|wodka|whisky|whiskey|\mrum\M|\mgin\M|likeur|prosecco|cava\M' or p1 ~* 'alcoholic' then
    return 'alcohol_drinks';

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
  elsif n ~* 'koffie|\mcoffee\M|\mcafe\M|cappuccino|espresso|latte\M|\mthee\M|\mtea\M' or p2 ~* 'coffee and tea' then
    return 'hot_beverages';
  elsif (n ~* '\mwater\M|bronwater|mineraalwater' or p2 ~* 'waters and flavored waters')
        and not v_is_drink_named then
    return 'water';

  elsif (p2 ~* '\mnuts\M' or n ~* 'noten|zaden|amandelen|cashew|walnoot|hazelnoot|pistache') and not (n ~* 'pasta') then
    return 'nuts_seeds';

  elsif n ~* 'soep|\msoup\M' or p2 ~* '\msoup\M' then
    return 'soups';
  elsif (n ~* '\mdip\M|saus|sauce|dressing|streich' or p2 ~* 'sauce|dressing') and not (n ~* 'boter|butter|\molie\M|olive oil') then
    return 'sauces_dips';

  elsif n ~* '\mhoning\M|\mhoney\M|\msiroop\M|\mstroop\M|\msyrup\M|\magave\M|maple syrup|ahornsiroop' then
    return 'honey_syrups';

  elsif p2 ~* '\mfruits\M' and not v_is_drink_named then
    return 'fresh_fruit';
  elsif n ~* 'tomaten?\M|komkommer|worteltjes|wortel\M|\msla\M|paprika|\mui\M|uien\M|broccoli|spinazie|courgette|aubergine|\mprei\M|bloemkool|spruitjes|andijvie|\mboon\M|bonen\M|erwt|betteraves?\M|carottes?\M|oignons?\M' then
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

update public.product_features pf set
  swap_family                  = v.family,
  category_cluster             = m.category_cluster,
  snack_type                   = m.snack_type,
  product_form                 = m.product_form,
  consumption_mode             = m.consumption_mode,
  secondary_consumption_modes  = coalesce(m.secondary_consumption_modes, '{}'),
  usage_context                = coalesce(m.usage_context, '{}'),
  is_swap_relevant             = true,
  swap_relevance_reason        = coalesce(pf.swap_relevance_reason, 'swap_family_v2'),
  updated_at                   = now()
from public.products p,
     lateral (select public.compute_swap_family(
       p.name, p.category, p.categories_tags, p.pnns_groups_1, p.pnns_groups_2) as family) v
left join public.swap_family_mapping m on m.swap_family = v.family
where p.barcode = pf.barcode
  and (pf.swap_family is distinct from v.family
    or pf.category_cluster is distinct from m.category_cluster
    or pf.snack_type is distinct from m.snack_type
    or pf.product_form is distinct from m.product_form
    or pf.consumption_mode is distinct from m.consumption_mode)
  and v.family is not null and v.family <> 'unknown';
