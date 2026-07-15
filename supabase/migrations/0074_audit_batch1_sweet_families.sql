-- Fase 1 audit, batch 1 (zoete families) — deel 1: check-gedreven correcties.
-- Bron: docs/AUDIT_VOORTGANG.md. Drie checks over chocolate_bars,
-- chocolate_confectionery, chocolate_spreads, candy_sweets, cookies_biscuits,
-- cakes_pastries, ice_cream_desserts, sweet_spreads_other, honey_syrups,
-- jams_fruit_spreads:
--   A) naam-splits  B) bak-ingrediënt-signalen  C) kcal-uitschieters
-- Elke correctie hieronder is barcode-verankerd en per product geverifieerd.
-- Zes regex-wortels worden in dezelfde migratie gefixt zodat nieuwe scans
-- dezelfde fout niet herintroduceren (live-trigger gebruikt deze functie).
--
-- Regex-wortels (bewijs per stuk):
--  R1 hagelslag-regel dekte varianten niet ("Chocoladehagel", "Hagel slag",
--     vlokken, hagelwit) -> die vielen in chocolade-families of bleven null.
--  R2 'liquorice|licorice' in de categorie-check van chocolate_confectionery
--     grijpt drop vóór de candy-regel (Klene suikervrije drop x5).
--  R3 honing/stroop-regel grijpt stroopwafels en honing-gearomatiseerde
--     noten ("Leeuw Nootjes Honey BBQ", "Honey Sea Salt" cashews).
--  R4 ijs-regel matcht "Rijswafels" (zonder t, dus de rijst-exclusie mist).
--  R5 meal_components grijpt maaltijdvervangende shakes/poeders
--     (Huel/Jimmy Joy/Yfood: "meal"/"maaltijd" in naam).
--  R6 (data) taart-/vlaaifruit en kook-/couverturechocolade zijn
--     bakingrediënten; nieuwe familie baking_ingredients_non_swap
--     (zelfde patroon als fats_oils_non_swap).
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

-- Stap 1: snapshot (alle expliciet genoemde barcodes + retro-patronen).
create table if not exists public._snapshot_0074_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  '8715700119328','8715700124209','15957580','8710496977718','8710496978999',
  '8710496977527','8715700119410','8718907267410','8710400017653',
  '2289089002008','2167711002995','8710998538066','8719587293935',
  '8718452872763','8710508927830','8718907492775',
  '8710412044364',
  '5600699792313','5600241424082','8718907694100','4056489751328',
  '3270160420186','8715661020282','8715661016704',
  '8710742300109','5900951311123',
  '5060929632282','5060495116537','5060495115417','5060495117404',
  '5060495113918','8720165350155','8720165350117','8717953209207',
  '8717953209221','8720165350452','8717953209276',
  '5060925294576','5410063042018','4260556631806',
  '8723400794981','8723400795063','8723400795162','8723400779940',
  '8723400795223','7610700607756','7610700015902',
  '4056489538172','8718452639564','5690845001147','5690845003707',
  '5711953195327','87346794','8718907825627','8058333131023',
  '5425003195112','8718452689194','8718907567237','5701182018498',
  '5410441003303','8717228615641','4270000119941',
  '8710412041424','8713965500134','8720600612206','8710624278090',
  '8719587008553','8710624621001',
  '8711271116162','8710624336349','8718907133166','8710466301321',
  '4048885045781','87352542'
)
or barcode in (
  -- retro-doelgroep R1: onbeoordeelde hagelslag-varianten
  select p.barcode from public.products p
  join public.product_features pf2 on pf2.barcode = p.barcode
  where pf2.classification_status is null
    and p.name ~* 'hagelslag|hagel ?slag|chocoladehagel|chocolade ?vlokken|vruchtenhagel|hagelwit|kokos ?hagel'
);

-- Stap 2: nieuwe familie voor bakingrediënten.
insert into public.swap_family_mapping
  (swap_family, category_cluster, snack_type, product_form, consumption_mode,
   secondary_consumption_modes, usage_context, related_families, is_swap_relevant_default)
values
  ('baking_ingredients_non_swap', 'overig', 'ingredient', 'raw_ingredient', 'cook_or_prepare',
   '{}', array['baking'], '{}', false)
on conflict (swap_family) do update set
  category_cluster = excluded.category_cluster,
  snack_type = excluded.snack_type,
  product_form = excluded.product_form,
  consumption_mode = excluded.consumption_mode,
  usage_context = excluded.usage_context,
  related_families = excluded.related_families,
  is_swap_relevant_default = excluded.is_swap_relevant_default;

-- Stap 3: compute_swap_family() met de zes regel-fixes (R1-R5; R6 is
-- data/mapping). Volledige herdefinitie, wijzigingen gemarkeerd met -- R#.
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
  -- R1: hagelslag-varianten (chocoladehagel, vlokken, hagelwit, kokoshagel)
  elsif n ~* 'hagelslag|hagel ?slag|chocoladehagel|chocolade ?vlokken|vruchtenhagel|hagelwit|kokos ?hagel' then
    return 'sweet_spreads_other';

  elsif n ~* 'eiwitreep|protein bar' or c ~* 'protein.?bar' then
    return 'protein_bars';
  elsif n ~* 'mueslireep|cerealreep|granolareep' or c ~* 'cereal.?bar' then
    return 'cereal_bars';
  elsif n ~* 'chocoladereep|candy bar' or c ~* 'chocolate.?bar' then
    return 'chocolate_bars';

  -- R2: liquorice/licorice weggehaald uit de categorie-check hier...
  elsif c ~* 'pralines|bonbons|chocolates|filled.chocolates' or p2 ~* 'chocolate'
        or n ~* 'bonbon|praline|\mmerci\M|salmiak' then
    return 'chocolate_confectionery';
  -- R2: ...en toegevoegd aan de candy-categorie-check (drop hoort hier).
  elsif (n ~* 'drop\M|winegum|toffee|marshmallow|spekjes|schuimpjes|zuurtjes|\mlolly|fruittella|napoleon|venco|fruit roll'
         or n ~* 'gummy|gummies|wine ?gums?|fruit ?gums?|liquorice|licorice'
         or c ~* 'liquorice|licorice')
        and n !~* 'vitamine|\mcbd\M|\mhemp\M|supplement' then
    return 'candy_sweets';

  -- R4: rijswafel toegevoegd aan de ijs-exclusies.
  elsif n ~* '\mijs\M|ice cream|sorbet|gelato' or p2 ~* 'ice cream'
        or (n ~* 'ijs' and n !~* 'ijsbergsla|amandelspijs|spijskoek|radijs|saucijs|parijs|anijs|ijsthee|rijst|prijs|wijze|vrijst|rijswafel') then
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

  -- R3: stroopwafels/honingnoten niet meer in de siroop-familie.
  elsif n ~* '\mhoning\M|\mhoney\M|\msiroop\M|\mstroop\M|\msyrup\M|\magave\M|maple syrup|ahornsiroop'
        and n !~* 'wafel|waffle|\mkoek|nootjes|\mnoten\M|cashew|pinda' then
    return 'honey_syrups';

  elsif p2 ~* '\mfruits\M' and not v_is_drink_named then
    return 'fresh_fruit';
  elsif n ~* 'tomaten?\M|komkommer|worteltjes|wortel\M|\msla\M|paprika|\mui\M|uien\M|broccoli|spinazie|courgette|aubergine|\mprei\M|bloemkool|spruitjes|andijvie|\mboon\M|bonen\M|erwt|betteraves?\M|carottes?\M|oignons?\M' then
    return 'fresh_vegetables';

  elsif c ~* 'meat-alternatives|meat-analogues' then
    return 'meat_alternatives_non_swap';
  elsif c ~* 'cereals-and-potatoes|pastas|cereal-grains' then
    return 'grain_starch_ingredients';

  elsif p2 ~* 'baby foods|baby milks' then
    return 'baby_food_non_swap';
  elsif p2 ~* '\meggs\M' then
    return 'raw_eggs_non_swap';
  elsif p2 ~* '\mfats\M' then
    return 'fats_oils_non_swap';

  elsif p2 ~* 'fish and seafood' and n !~* 'sushi' then
    return 'fish_seafood';
  elsif p2 ~* '\mlegumes\M'
        and n !~* 'crunchy beans|edamame|bonenmix|bonnenmix|original flavor peas|crunch dark roasted' then
    return 'legumes_non_swap';

  elsif n ~* 'kant.?en.?klaar|magnetronmaaltijd|ovenschotel|maaltijdbox'
        or (n ~* '\mpizza\M'
            and n !~* 'pizzasaus|pizza.?saus|pizzakruiden|pizza.?kruiden|pizzadeeg|pizza.?deeg|pizzabodem|pizza.?bodem|pizzameel|pizza.?meel|\mmeel\M|farina|dippers|m[ée]lange') then
    return 'ready_meals';
  -- R5: maaltijdvervangende shakes/poeders horen niet in meal_components.
  elsif (p1 ~* 'composite' or n ~* 'maaltijd|salade|\mmeal\M')
        and n !~* '\mshake\M|drinkmaaltijd|meal ?replacement' then
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

-- Stap 4: barcode-verankerde correcties (reason bevat de motivering).

update public.product_features set swap_family='sweet_spreads_other', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: hagelslag/vlokken/hagelwit is broodbeleg-strooisel (canoniek sweet_spreads_other, R1)'
where barcode in ('8715700119328','8715700124209','15957580','8710496977718','8710496978999','8710496977527','8715700119410','8718907267410','8710400017653');

update public.product_features set swap_family='cookies_biscuits', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: eierkoek/macaron/stroopwafel is koek (naam-split of R3-stroopwortel)'
where barcode in ('2289089002008','2167711002995','8710998538066','8719587293935','8718452872763','8710508927830','8718907492775');

update public.product_features set swap_family='chocolate_confectionery', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: chocoladetablet zonder reep-naam is canoniek chocolate_confectionery (consistent met runtime-regel)'
where barcode in ('8710412044364');

update public.product_features set swap_family='cakes_pastries', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: pastel de nata/Bossche bol/soesjes/taart is gebak, geen koekje'
where barcode in ('5600699792313','5600241424082','8718907694100','4056489751328','3270160420186','8715661020282','8715661016704');

update public.product_features set swap_family='honey_syrups', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: rinse appelstroop is stroop (naam-split, 3 van 4 stonden al goed)'
where barcode in ('8710742300109');

update public.product_features set swap_family='chocolate_bars', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: Snickers is een candy bar (merk-regel bestond al, dit exemplaar was ouder)'
where barcode in ('5900951311123');

update public.product_features set swap_family='supplements_powders', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: maaltijdvervangend poeder (Huel/Jimmy Joy) is supplement-poeder, geen maaltijdcomponent (R5)'
where barcode in ('5060929632282','5060495116537','5060495115417','5060495117404','5060495113918','8720165350155','8720165350117','8717953209207','8717953209221','8720165350452','8717953209276');

update public.product_features set swap_family='dairy_drinks', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: drinkbare maaltijdvervanger (RTD) hoort bij drinkzuivel, consistent met yfood-precedent (R5)'
where barcode in ('5060925294576','5410063042018','4260556631806');

update public.product_features set swap_family='candy_sweets', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: (suikervrije) drop en kruidenpastilles zijn snoep, geen bonbons (R2)'
where barcode in ('8723400794981','8723400795063','8723400795162','8723400779940','8723400795223','7610700607756','7610700015902');

update public.product_features set swap_family='ice_cream_desserts', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: Gelatelli praline lollies is ijs (Lidl-ijsmerk), geen bonbon'
where barcode in ('4056489538172');

update public.product_features set swap_family='soft_drinks_light_zero', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: cola zero (marshmallow-smaak) is frisdrank, geen snoep (1 kcal/100g bevestigt)'
where barcode in ('8718452639564');

update public.product_features set swap_family='yoghurt_skyr_quark', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: Isey is skyr (Toffee/Cherry Cheesecake zijn smaakvarianten, 54-70 kcal bevestigt zuivel)'
where barcode in ('5690845001147','5690845003707');

update public.product_features set swap_family='dairy_desserts', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: zuiveldessert (mousse/kwark-hoekje), geen snoep of koek (77-141 kcal bevestigt)'
where barcode in ('5711953195327','87346794');

update public.product_features set swap_family='meat_alternatives_non_swap', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: plantaardige spekjes = vegan spekreepjes (88 kcal, 0.7g suiker), geen marshmallow'
where barcode in ('8718907825627');

update public.product_features set swap_family='nut_butters', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: 100% hazelnootpasta (722 kcal, 4g suiker) is notenpasta, geen chocoladepasta'
where barcode in ('8058333131023');

update public.product_features set swap_family='savory_spreads', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0074: Tartin''o is een hartige vegan tartinade (3.5g suiker), geen chocoladepasta'
where barcode in ('5425003195112');

update public.product_features set swap_family='crackers_rice_cakes', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: rijst-/maiswafels horen bij crackers (R4: ijs-regel matchte "Rijswafels")'
where barcode in ('8718452689194','8718907567237');

update public.product_features set swap_family='hot_beverages', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0074: fredsted chai latte is thee (48 kcal), geen koekje'
where barcode in ('5701182018498');

update public.product_features set swap_family='baby_food_non_swap', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: lait de croissance is groeimelk (babyvoeding), geen koekje'
where barcode in ('5410441003303');

update public.product_features set swap_family='ready_meals', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: macaroni bolognese is een kant-en-klare maaltijd (120 kcal), geen koekje'
where barcode in ('8717228615641');

update public.product_features set swap_family='jams_fruit_spreads', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0074: Weinaufstrich is een (wijn)fruitspread, geen hagelslag'
where barcode in ('4270000119941');

update public.product_features set swap_family='baking_ingredients_non_swap', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0074: kook-/couverturechocolade en taart-/vlaaifruit zijn bakingrediënten, geen snacks (R6)'
where barcode in ('8710412041424','8713965500134','8720600612206','8710624278090','8719587008553','8710624621001');

-- Terug naar onbeslist: condiment/poeder/pannenkoeken/bouillon — geen
-- passende familie, consistent met eerdere bewuste buiten-scope-besluiten.
update public.product_features set swap_family=null, classification_status=null,
  classification_confidence=null, classified_at=null, mapping_version=null,
  classification_reason='audit1_0074: teruggezet naar onbeslist -- condiment (zoetzure augurk), chocolademelkpoeder, kant-en-klare pannenkoeken of drinkbouillon; bewust buiten het swap-model'
where barcode in ('8711271116162','8710624336349','8718907133166','8710466301321','4048885045781');

-- Onbruikbare naam -> review_required.
update public.product_features set swap_family=null, classification_status='review_required',
  classification_confidence=0.3, classified_at=now(), mapping_version=1,
  classification_reason='audit1_0074: naam ("smaak mousse and cookie") geeft onvoldoende signaal over producttype'
where barcode in ('87352542');

-- Stap 5: retroactief — R1-hagelslagvarianten die nu nog onbeoordeeld zijn.
update public.product_features pf set
  swap_family = 'sweet_spreads_other',
  classification_status = 'classified',
  classification_confidence = 0.6,
  classification_reason = 'audit1_0074: retro R1 -- hagelslag/vlokken-variant herkend door uitgebreide regel',
  classified_at = now(),
  mapping_version = 1
from public.products p
where p.barcode = pf.barcode
  and pf.classification_status is null
  and p.name ~* 'hagelslag|hagel ?slag|chocoladehagel|chocolade ?vlokken|vruchtenhagel|hagelwit|kokos ?hagel';

-- POSTFLIGHT (read-only):
-- select classification_reason, count(*) from product_features where classification_reason like 'audit1_0074%' group by 1 order by 2 desc;
-- select count(*) from product_features_resolved; -- gelijk aan products
-- select count(*) from product_features where swap_family is not null and classification_status is null; -- 0
-- select max(updated_at) from products; -- ongewijzigd

-- ROLLBACK: herstel via _snapshot_0074_before (zelfde patroon als 0070-0073),
-- delete from swap_family_mapping where swap_family='baking_ingredients_non_swap',
-- en herstel compute_swap_family() met de definitie uit 0056.
