-- VOORSTEL — NOG NIET UITGEVOERD. Wacht op expliciet akkoord vóór
-- `supabase db push`. Batch 4b: resultaat van handmatige inspectie van
-- élk item in de pnns-buckets Meat (77), Fish and seafood (68) en
-- Legumes (60) uit de review_required-pool.
--
-- Bevinding: Meat en Fish and seafood zijn GEEN veilige categorie-blanket
-- (in tegenstelling tot Batch 4a) -- ze bevatten een mix van rauwe
-- producten (raw_meat-achtig) én gemiste, al-bestaande SWAP-RELEVANTE
-- categorieën (vissticks/lekkerbek/kibbeling -> fried_snacks, fuet/
-- bresaola/tostiham -> cold_cuts) én genuine ambiguë kant-en-klaar/rauw-
-- twijfelgevallen (schnitzel, saté, shoarma, gegrild, gebraden, piri
-- piri) die niet betrouwbaar uit de naam zijn af te leiden.
--
-- Legumes bevatte eveneens gemiste taalvarianten van de al-bestaande
-- `nut_butters`-familie en een handvol geroosterde bonen/edamame-snacks
-- die mogelijk wél swap-relevant zijn -- die blijven daarom expliciet
-- buiten de nieuwe `legumes_non_swap`-familie.
--
-- Deze migratie doet drie dingen, alle additief:
--   1. Vier bestaande SWAP-RELEVANTE families uitbreiden (verhoogt swap
--      candidate coverage): nut_butters (+5), fried_snacks (+~26,
--      inclusief vissticks/lekkerbek/kibbeling/surimi/croquet-spelling/
--      nugget-meervoud), cold_cuts (+11, tostiham/fuet/bresaola/etc.).
--   2. Twee niet-swap-relevante families (fish_seafood uitgebreid van
--      naam-loos naar een pnns-anchored regel; nieuwe legumes_non_swap):
--      +52 en +49.
--   3. De genuine onbeslisbare rest van Meat (69 producten: schnitzel/
--      saté/shoarma/gegrild/gebraden naast rauwe stukken, niet uit naam
--      te onderscheiden) -> classification_status = 'review_required'
--      met expliciete reden. GEEN swap_family-gok. Telt mee als
--      "explained" (review_required met duidelijke reden), niet als
--      swap candidate.
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

-- Stap 1: snapshot. Superset van alles wat deze migratie kan aanraken:
-- alle huidige review_required-pool-barcodes in Meat/Fish and seafood/
-- Legumes, plus de bredere (niet-pnns-beperkte) matches voor de
-- regex-uitbreidingen (nut_butters/fried_snacks/cold_cuts), zodat de
-- snapshot ook de buiten-Meat/Fish-gevonden Lekkerbek/Nuggets/Fuet/
-- Tostiham-producten dekt.
create table if not exists public._snapshot_0056_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  select barcode from public.products
  where pnns_groups_2 in ('Meat', 'Fish and seafood', 'Legumes')
     or name ~* 'vissticks|visstick|lekkerbek|kibbeling|fish cake|surimi|croquet|\mnuggets?\M'
     or name ~* 'tostiham|boerenpat[ée]|fleischsalat|\mfuet\M|bresaola|bresola|pancetta|\mamericain\M|\msalam\M'
     or name ~* 'beurre de cacahu[eè]te|manteiga de amendoim|erdnusscreme|cr[eè]me de cacahu[eè]tes|pinda.{0,3}pasta'
);

-- Stap 2: nieuwe niet-swap-relevante familie (fish_seafood bestaat al
-- met is_swap_relevant_default=false, wordt hier niet opnieuw ingevoegd).
insert into public.swap_family_mapping
  (swap_family, category_cluster, snack_type, product_form, consumption_mode,
   secondary_consumption_modes, usage_context, related_families, is_swap_relevant_default)
values
  ('legumes_non_swap', 'overig', 'ingredient', 'raw_ingredient', 'cook_or_prepare',
   '{}', array['cooking'], '{}', false)
on conflict (swap_family) do update set
  category_cluster = excluded.category_cluster,
  snack_type = excluded.snack_type,
  product_form = excluded.product_form,
  consumption_mode = excluded.consumption_mode,
  usage_context = excluded.usage_context,
  related_families = excluded.related_families,
  is_swap_relevant_default = excluded.is_swap_relevant_default;

-- Stap 3: compute_swap_family() additief uitbreiden.
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
  elsif n ~* 'pindakaas|peanut butter|amandelpasta|notenpasta|cashewpasta|hazelnootpasta|pistachepasta|pistachio paste|beurre de cacahu[eè]te|manteiga de amendoim|erdnusscreme|cr[eè]me de cacahu[eè]tes|pinda.{0,3}pasta' then
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
  elsif n ~* '\mham\M|salami|cervelaat|rookvlees|\mpat[ée]\M|leverworst|kipfilet|achterham|vleeswaren|boterhamworst|tostiham|boerenpat[ée]|fleischsalat|\mfuet\M|bresaola|bresola|pancetta|\mamericain\M|\msalam\M'
        or p2 ~* 'processed meat' then
    return 'cold_cuts';

  elsif n ~* 'kroket|croquet|frikandel|bitterbal|kaassouffl[ée]|bamischijf|nasischijf|loempia|\mnuggets?\M|vissticks|visstick|lekkerbek|kibbeling|fish cake|surimi'
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
  -- categories_tags (OFF), NIET op naam.
  elsif c ~* 'meat-alternatives|meat-analogues' then
    return 'meat_alternatives_non_swap';
  elsif c ~* 'cereals-and-potatoes|pastas|cereal-grains' then
    return 'grain_starch_ingredients';

  -- BATCH4A: bewust niet-swap-relevante grondstoffen-clusters, puur op
  -- pnns_groups_2 (OFF), NIET op naam.
  elsif p2 ~* 'baby foods|baby milks' then
    return 'baby_food_non_swap';
  elsif p2 ~* '\meggs\M' then
    return 'raw_eggs_non_swap';
  elsif p2 ~* '\mfats\M' then
    return 'fats_oils_non_swap';

  -- BATCH4B: fish_seafood nu ook via pnns_groups_2 herkend (voorheen
  -- alleen via eenmalige historische UPDATE, niet in deze functie).
  -- Sushi expliciet uitgesloten (kant-en-klaar gerecht, geen rauwe/
  -- conserven-vis) -- blijft onbeslist, geen gok. legumes_non_swap
  -- expliciet zonder de geroosterde bonen/edamame-snacks die mogelijk
  -- wél swap-relevant zijn.
  elsif p2 ~* 'fish and seafood' and n !~* 'sushi' then
    return 'fish_seafood';
  elsif p2 ~* '\mlegumes\M'
        and n !~* 'crunchy beans|edamame|bonenmix|bonnenmix|original flavor peas|crunch dark roasted' then
    return 'legumes_non_swap';

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
-- null is (additief). Zelfde priority-logica als in de functie.
with newly_classified as (
  select p.barcode, p.name, p.pnns_groups_2,
    case
      when p.name ~* 'pindakaas|peanut butter|amandelpasta|notenpasta|cashewpasta|hazelnootpasta|pistachepasta|pistachio paste|beurre de cacahu[eè]te|manteiga de amendoim|erdnusscreme|cr[eè]me de cacahu[eè]tes|pinda.{0,3}pasta' then 'nut_butters'
      when p.name ~* '\mham\M|salami|cervelaat|rookvlees|\mpat[ée]\M|leverworst|kipfilet|achterham|vleeswaren|boterhamworst|tostiham|boerenpat[ée]|fleischsalat|\mfuet\M|bresaola|bresola|pancetta|\mamericain\M|\msalam\M'
           or p.pnns_groups_2 ~* 'processed meat' then 'cold_cuts'
      when p.name ~* 'kroket|croquet|frikandel|bitterbal|kaassouffl[ée]|bamischijf|nasischijf|loempia|\mnuggets?\M|vissticks|visstick|lekkerbek|kibbeling|fish cake|surimi'
           and p.name !~* 'broodje|\mwrap\M|sandwich|maaltijd|kant.?en.?klaar|\msalade\M|\msaus\M' then 'fried_snacks'
      when p.pnns_groups_2 ~* 'fish and seafood' and p.name !~* 'sushi' then 'fish_seafood'
      when p.pnns_groups_2 ~* '\mlegumes\M'
           and p.name !~* 'crunchy beans|edamame|bonenmix|bonnenmix|original flavor peas|crunch dark roasted' then 'legumes_non_swap'
      else null
    end as new_family
  from public.products p
  join public.product_features pf on pf.barcode = p.barcode
  -- BUGFIX tijdens dry-run: classification_status is null (niet swap_family
  -- is null) -- anders vangt dit ook de bestaande ~44 "Kipfilet [smaak]"
  -- review_required-rijen (confidence 0.3, "alleen smaakwoord") die niet
  -- handmatig zijn geïnspecteerd in deze batch en dus buiten scope horen.
  where pf.classification_status is null
)
update public.product_features pf set
  swap_family = nc.new_family,
  classification_reason = 'batch4b_meat_fish_legumes_split'
from newly_classified nc
where pf.barcode = nc.barcode and nc.new_family is not null;

-- Stap 5: status-backfill, uitsluitend voor de rijen die deze migratie
-- zelf zojuist heeft aangeraakt.
update public.product_features pf set
  classification_status = 'classified',
  classified_at = now(),
  classification_confidence = 0.70,
  mapping_version = 1
where pf.classification_reason = 'batch4b_meat_fish_legumes_split'
  and pf.classification_status is null;

-- Stap 6: de genuine onbeslisbare rest van de Meat-bucket ->
-- review_required met expliciete reden. GEEN swap_family. Confidence
-- 0.3, zelfde conventie als de bestaande 25 review_required-rijen.
update public.product_features pf set
  classification_status = 'review_required',
  classification_reason = 'batch4b_meat_prep_status_ambiguous: vlees/gevogelte-categorie, rauw-of-kant-en-klaar (schnitzel/saté/shoarma/gegrild/gebraden vs. rauwe filet/gehakt) niet betrouwbaar uit productnaam af te leiden',
  classified_at = now(),
  classification_confidence = 0.3,
  mapping_version = 1
where pf.swap_family is null
  and pf.classification_status is null
  and pf.barcode in (select barcode from public.products where pnns_groups_2 = 'Meat');

-- POSTFLIGHT (read-only, uit te voeren na deze migratie):
-- select swap_family, count(*) from product_features where classification_reason='batch4b_meat_fish_legumes_split' group by 1 order by 1;
--   -- verwacht: nut_butters ~5, cold_cuts ~16, fried_snacks ~29, fish_seafood ~52, legumes_non_swap ~49
-- select classification_status, count(*) from product_features where classification_reason like 'batch4b_meat_prep_status_ambiguous%' group by 1;
--   -- verwacht: review_required ~69
-- select count(*) from product_features_resolved; -- moet exact gelijk blijven aan aantal products
-- select count(*) from product_features where swap_family is not null and classification_status is null; -- moet 0 blijven
-- select is_swap_relevant, count(*) from product_features_resolved
--   where swap_family in ('fish_seafood','legumes_non_swap') group by 1;
--   -- ALLE rijen moeten is_swap_relevant=false zijn
-- select is_swap_relevant, count(*) from product_features_resolved
--   where swap_family in ('nut_butters','cold_cuts','fried_snacks') and classification_reason='batch4b_meat_fish_legumes_split' group by 1;
--   -- deze mogen (moeten) is_swap_relevant=true zijn -- dit verhoogt swap candidate coverage bewust
-- select max(updated_at) from products; -- moet ongewijzigd blijven (products blijft raw)

-- ROLLBACK (exact, via de snapshot-tabel):
-- update public.product_features pf set
--   swap_family = s.swap_family, is_swap_relevant = s.is_swap_relevant,
--   classification_status = s.classification_status, classification_confidence = s.classification_confidence,
--   classification_reason = s.classification_reason, matched_rule_id = s.matched_rule_id,
--   rule_version = s.rule_version, mapping_version = s.mapping_version,
--   source_fingerprint = s.source_fingerprint, classified_at = s.classified_at
-- from public._snapshot_0056_before s
-- where pf.barcode = s.barcode;
-- delete from public.swap_family_mapping where swap_family in ('legumes_non_swap');
-- create or replace function public.compute_swap_family(...) <exacte vorige definitie uit 0055>;
-- drop table public._snapshot_0056_before; -- pas na bevestigde, succesvolle rollback
