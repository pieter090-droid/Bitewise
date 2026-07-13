-- VOORSTEL — NOG NIET UITGEVOERD. Wacht op expliciet akkoord vóór
-- `supabase db push`. Batch 4a: drie nieuwe, bewust niet-swap-relevante
-- families voor pnns_groups_2-categorieën die na volledige handmatige
-- inspectie van élk item (niet alleen op aantal) schoon bleken:
-- Baby foods/Baby milks (74), Eggs (23), Fats (89) — samen 186 producten.
--
-- Zelfde mechanisme als de al-bestaande `raw_poultry`/`raw_meat`/
-- `fish_seafood`/`grain_starch_ingredients`/`meat_alternatives_non_swap`:
-- `is_swap_relevant_default = false`. Verhoogt explained coverage,
-- NIET swap candidate coverage.
--
-- Expliciet NIET meegenomen in deze batch (bewust uitgesloten na
-- inspectie, apart te beoordelen):
--   - Legumes (60): bevat naast rauwe/blik peulvruchten ook gemiste
--     pindapasta-taalvarianten ("Beurre de cacahuète", "Manteiga de
--     amendoim cremosa", "Erdnusscreme") die bij bestaande `nut_butters`
--     horen, en geroosterde bonen-snacks ("Crunchy Beans chili-lime",
--     "Edamame") die mogelijk wél swap-relevant zijn. Blanket-regel zou
--     die fout wegzetten.
--   - Meat (77) en Fish and seafood (68): bevatten naast rauw vlees/vis
--     ook gerookte/gepekelde/blik-producten (bacon, casselerrib, gerookte
--     zalm, tonijn in blik) die eerder op `cold_cuts`/ready-to-eat lijken
--     dan op de bestaande "rauw, zelf te bereiden"-precedent. Vraagt
--     naam-patroon-onderscheid, geen categorie-blanket.
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

-- Stap 1: snapshot.
create table if not exists public._snapshot_0055_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  select barcode from public.products
  where pnns_groups_2 ~* 'baby foods|baby milks|\meggs\M|\mfats\M'
);

-- Stap 2: drie nieuwe families in swap_family_mapping.
insert into public.swap_family_mapping
  (swap_family, category_cluster, snack_type, product_form, consumption_mode,
   secondary_consumption_modes, usage_context, related_families, is_swap_relevant_default)
values
  ('baby_food_non_swap', 'overig', 'ingredient', 'prepared_or_raw', 'feed_or_prepare',
   '{}', array['feeding'], '{}', false),
  ('raw_eggs_non_swap', 'overig', 'ingredient', 'raw_ingredient', 'cook_or_prepare',
   '{}', array['cooking'], '{}', false),
  ('fats_oils_non_swap', 'overig', 'ingredient', 'raw_ingredient', 'cook_or_prepare',
   '{}', array['cooking'], '{}', false)
on conflict (swap_family) do update set
  category_cluster = excluded.category_cluster,
  snack_type = excluded.snack_type,
  product_form = excluded.product_form,
  consumption_mode = excluded.consumption_mode,
  usage_context = excluded.usage_context,
  related_families = excluded.related_families,
  is_swap_relevant_default = excluded.is_swap_relevant_default;

-- Stap 3: compute_swap_family() additief uitbreiden. Alle drie takken zijn
-- puur pnns_groups_2-gebaseerd (niet naam-gebaseerd), geplaatst in het
-- BATCH3B "bewust niet-swap-relevante grondstoffen"-blok, ná de
-- meat-alternatives/grain-tak en VÓÓR ready_meals/meal_components — zodat
-- alle specifiekere naam-regels hierboven (nut_butters, butter_margarine,
-- cheese_snacks, sauces_dips, honey_syrups, etc.) altijd voorrang houden.
-- Elk van de drie pnns-waarden komt in de praktijk niet voor bij een
-- product dat al eerder in de keten is afgevangen (handmatig geverifieerd
-- op alle 186 producten in de dry-run).
create or replace function public.compute_swap_family(p_name text, p_category text, p_categories_tags text, p_pnns1 text, p_pnns2 text, p_brand text default null::text)
 returns text
 language plpgsql
 immutable
as $function$
declare
  n  text := coalesce(p_name, '');
  c  text := coalesce(p_category, '') || ' ' || coalesce(p_categories_tags, '');
  p1 text := coalesce(p_pnns1, '');
  p2 text := coalesce(p_pnns2, '');
  b  text := coalesce(p_brand, '');
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
  elsif (n ~* 'drop\M|winegum|toffee|marshmallow|spekjes|schuimpjes|zuurtjes|\mlolly|fruittella|napoleon|venco|fruit roll'
         or n ~* 'gummy|gummies|wine ?gums?|fruit ?gums?|liquorice|licorice')
        and n !~* 'vitamine|\mcbd\M|\mhemp\M|supplement' then
    return 'candy_sweets';

  elsif n ~* '\mijs\M|ice cream|sorbet|gelato' or p2 ~* 'ice cream'
        or (n ~* 'ijs' and n !~* 'ijsbergsla|amandelspijs|spijskoek|radijs|saucijs|parijs|anijs|ijsthee|rijst|prijs|wijze|vrijst') then
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

  elsif n ~* 'taart\M|\mgebak\M|cake\M|flap\M' then
    return 'cakes_pastries';
  elsif p2 ~* 'biscuits|cookies' or n ~* '\mkoek|koek\M|cookie|jan hagel|sprits|kletsmajoor|picolient|speculaas|\mkrans|biscuit' then
    return 'cookies_biscuits';
  elsif n ~* 'cracker|beschuit|rice cake|knackebrod'
        or n ~* 'rijstwafel|rijswafel|maiswafel'
        or c ~* 'cracker' then
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

  elsif n ~* 'kroket|frikandel|bitterbal|kaassouffl[ée]|bamischijf|nasischijf|loempia|\mnugget\M'
        and n !~* 'broodje|\mwrap\M|sandwich|maaltijd|kant.?en.?klaar|\msalade\M|\msaus\M' then
    return 'fried_snacks';

  elsif n ~* 'popcorn' or c ~* 'popcorn' then
    return 'popcorn';
  elsif n ~* 'chips|crisps' or c ~* 'chips|crisps' then
    return 'crisps_chips';
  elsif n ~* 'olijven|\molive\M|olives' then
    return 'sauces_dips';
  elsif p2 ~* '\mcheese\M' or n ~* '\mkaas\M|\mcheese\M' then
    return 'cheese_snacks';

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

  -- BATCH3B: bewust niet-swap-relevante grondstoffen-clusters, puur op
  -- categories_tags (OFF), NIET op naam -- dus geen risico dat een
  -- "echte" snack per ongeluk hier terechtkomt (die is al hierboven
  -- afgevangen door een specifiekere naam-regel). meat-alternatives heeft
  -- voorrang op de graan-tak bij overlap (bv. seitan).
  elsif c ~* 'meat-alternatives|meat-analogues' then
    return 'meat_alternatives_non_swap';
  elsif c ~* 'cereals-and-potatoes|pastas|cereal-grains' then
    return 'grain_starch_ingredients';

  -- BATCH4A: bewust niet-swap-relevante grondstoffen-clusters, puur op
  -- pnns_groups_2 (OFF), NIET op naam. Alle drie handmatig per item
  -- geverifieerd (186 producten) -- geen enkel bewerkt/snack-achtig
  -- product ertussen; wat wél snack-achtig was is elders al afgevangen
  -- door een specifiekere regel hierboven.
  elsif p2 ~* 'baby foods|baby milks' then
    return 'baby_food_non_swap';
  elsif p2 ~* '\meggs\M' then
    return 'raw_eggs_non_swap';
  elsif p2 ~* '\mfats\M' then
    return 'fats_oils_non_swap';

  elsif n ~* 'kant.?en.?klaar|magnetronmaaltijd|ovenschotel|maaltijdbox'
        or (n ~* '\mpizza\M'
            and n !~* 'pizzasaus|pizza.?saus|pizzakruiden|pizza.?kruiden|pizzadeeg|pizza.?deeg|pizzabodem|pizza.?bodem|pizzameel|pizza.?meel|\mmeel\M|farina|dippers|m[ée]lange') then
    return 'ready_meals';
  elsif p1 ~* 'composite' or n ~* 'maaltijd|salade|\mmeal\M' then
    return 'meal_components';

  elsif n ~* 'eiwitpoeder|proteine ?poeder|\mwhey\M|supplement'
        or n ~* 'protein.?powder|\mshake\M|creatine' and n !~* '\mmilkshake\M' then
    return 'supplements_powders';

  elsif b ~* '\mred ?bull\M|\mmonster\M|\mrockstar\M|\mburn\M' then
    return 'energy_drinks';
  elsif b ~* '\mbueno\M|kit ?kat|\mtwix\M|\mlion\M|\mmars\M|snickers|bounty|knoppers|milky ?way|kinder country|kinder maxi' then
    return 'chocolate_bars';
  elsif b ~* '\mharibo\M' then
    return 'candy_sweets';
  elsif b ~* '\mmaoam\M|\mkatja\M|look.?o.?look|\mvenco\M|chupa.?chups' then
    return 'candy_sweets';
  elsif b ~* '\mbonduelle\M'
        and n !~* 'lunch bowl|\mpasta\M|quinoa|boulgour|\morge\M|\mriz\M|cuisin|\mwok\M|salteado|\mcurry\M|pur[ée]e|\mservice\M|minute|ligne|composée|composee|cr[eè]me|epeautre|épeautre' then
    return 'fresh_vegetables';

  else
    return null;
  end if;
end $function$;

-- Stap 4: retroactieve toepassing, alleen op rijen waar swap_family nu
-- null is (additief). De drie pnns_groups_2-waarden zijn onderling
-- exclusief, dus volgorde binnen deze CASE is niet betekenisvol.
with newly_classified as (
  select p.barcode,
    case
      when p.pnns_groups_2 ~* 'baby foods|baby milks' then 'baby_food_non_swap'
      when p.pnns_groups_2 ~* '\meggs\M' then 'raw_eggs_non_swap'
      when p.pnns_groups_2 ~* '\mfats\M' then 'fats_oils_non_swap'
      else null
    end as new_family
  from public.products p
  join public.product_features pf on pf.barcode = p.barcode
  where pf.swap_family is null
)
update public.product_features pf set
  swap_family = nc.new_family,
  classification_reason = 'batch4a_pnns_raw_ingredient_sweep'
from newly_classified nc
where pf.barcode = nc.barcode and nc.new_family is not null;

-- Stap 5: status-backfill, uitsluitend voor de rijen die deze migratie
-- zelf zojuist heeft aangeraakt.
update public.product_features pf set
  classification_status = 'classified',
  classified_at = now(),
  classification_confidence = 0.70,
  mapping_version = 1
where pf.classification_reason = 'batch4a_pnns_raw_ingredient_sweep'
  and pf.classification_status is null;

-- POSTFLIGHT (read-only, uit te voeren na deze migratie):
-- select swap_family, count(*) from product_features where classification_reason='batch4a_pnns_raw_ingredient_sweep' group by 1;
--   -- verwacht: baby_food_non_swap ~74, raw_eggs_non_swap ~23, fats_oils_non_swap ~89
-- select count(*) from product_features_resolved; -- moet exact gelijk blijven aan aantal products
-- select count(*) from product_features where swap_family is not null and classification_status is null; -- moet 0 blijven
-- select is_swap_relevant, count(*) from product_features_resolved
--   where swap_family in ('baby_food_non_swap','raw_eggs_non_swap','fats_oils_non_swap') group by 1;
--   -- ALLE rijen moeten is_swap_relevant=false zijn -- kern-check: swap candidate coverage stijgt niet
-- select max(updated_at) from products; -- moet ongewijzigd blijven t.o.v. vóór deze migratie (products blijft raw)

-- ROLLBACK (exact, via de snapshot-tabel):
-- update public.product_features pf set
--   swap_family = s.swap_family, is_swap_relevant = s.is_swap_relevant,
--   classification_status = s.classification_status, classification_confidence = s.classification_confidence,
--   classification_reason = s.classification_reason, matched_rule_id = s.matched_rule_id,
--   rule_version = s.rule_version, mapping_version = s.mapping_version,
--   source_fingerprint = s.source_fingerprint, classified_at = s.classified_at
-- from public._snapshot_0055_before s
-- where pf.barcode = s.barcode;
-- delete from public.swap_family_mapping where swap_family in ('baby_food_non_swap','raw_eggs_non_swap','fats_oils_non_swap');
-- create or replace function public.compute_swap_family(...) <exacte vorige definitie uit 0054>;
-- drop table public._snapshot_0055_before; -- pas na bevestigde, succesvolle rollback
