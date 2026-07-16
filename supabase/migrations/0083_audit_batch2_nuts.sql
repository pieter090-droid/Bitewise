-- Fase 1 audit, batch 2 (hartig) — deel 3: leesronde nuts_seeds (309).
-- Elk product individueel gelezen.
--
-- Hoofdbevindingen (wortel: notenregel matcht alles met noten/pistache/
-- hazelnoot/cashew in de naam — R15/R15b/R16 fixen de regexwortels):
--  K1 14 chocoladeproducten (tabletten met noten, pralines/zeevruchten,
--     Dubai-chocolade, Tony's crunch, chocopinda's, pindarotsjes, choco-
--     hazelnootballen) -> chocolate_confectionery; choco-mallows -> candy.
--  K2 7 kruidnoten/stroopwafel-producten -> cookies_biscuits (R15b: kruid-
--     noten/pepernoten expliciet in de koekregel).
--  K3 7 gebak (baklava, donuts, berline, stolletje, vlaai, kadayif) ->
--     cakes_pastries; 6 meerzadenbrood/pistolets -> bread_bakery.
--  K4 3 notendranken -> plant_based_dairy (R16); 2 cashewpasta's ->
--     nut_butters; Duo Penotti -> chocolate_spreads; cashew-smeersel ->
--     savory_spreads; 2 pesto's -> sauces_dips.
--  K5 5 kip/salade-maaltijden -> ready_meals; notenrijst + 2 gekookte
--     kastanjes -> meal_components; walnootolie -> cooking_oils_fats.
--  K6 2 eiwitrepen -> protein_bars; 2 notenrepen -> cereal_bars; pistache-
--     ijs ×2 -> ice_cream_desserts; breakfast oats -> breakfast_cereals;
--     hazelnootburger -> meat_alternatives_non_swap (niet swapbaar).
--  K7 4 review_required (wit pistache, hazelnootcreme, HiPro, Squeezer).
--  NB gekruide/gecoate noten (honing, wasabi, tandoori, suikeramandelen)
--     blijven bewust in nuts_seeds; borrelnoten-groep klopt.
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

create table if not exists public._snapshot_0083_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  '8718452491018','8718403590951','8710871404594','8719587247501','8724900525259',
  '8718989040260','8718907981545','4065019033360','8718452929337','3756587247501',
  '8718907959858','8719956496707','8718907199490','00207330',
  '4335619345058',
  '8718452233137','8718265087774','8710400587309','8718265791084','8715196296817',
  '8710482534642','8721161548959',
  '2154650003992','2150932005951','2150930002389','2230123002508','8719587313763',
  '8718989974565','8710401903269',
  '2254671001004','2258473002757','8715108238430','2298753003197','8718452644803',
  '8719587313787',
  '8711812419653','8718907425612','5060120283184',
  '8712439010407','8713576100174','87172126','87104912',
  '8718989998813','8718907013666','8718907825177','8717228616228','8711578591488',
  '8710400418023','3228170000072','3558370200997',
  '8719587254929','8719587091821',
  '8720986899840','4065019081743','8711812409715','8718907383387',
  '8719587211960','8717228613142','8721161680079','8710400161936','5425003194306',
  '8718989753443','8719587255124','8713788124487','8719587255100'
);

update public.product_features set swap_family='chocolate_confectionery', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0083: chocoladetablet/praline/chocopinda/pindarotsje met noten is chocolade, geen noten'
where barcode in (
  '8718452491018','8718403590951','8710871404594','8719587247501','8724900525259',
  '8718989040260','8718907981545','4065019033360','8718452929337','3756587247501',
  '8718907959858','8719956496707','8718907199490','00207330');

update public.product_features set swap_family='candy_sweets', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0083: choco-mallows zijn snoepgoed (spekjes-regel)'
where barcode in ('4335619345058');

update public.product_features set swap_family='cookies_biscuits', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0083: kruidnoten/stroopwafels zijn koek, geen noten (wortel gefixt in R15b)'
where barcode in (
  '8718452233137','8718265087774','8710400587309','8718265791084','8715196296817',
  '8710482534642','8721161548959');

update public.product_features set swap_family='cakes_pastries', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0083: gebak met noot-naam (baklava, donut, berline, stolletje, vlaai, kadayif) hoort in cakes_pastries'
where barcode in (
  '2154650003992','2150932005951','2150930002389','2230123002508','8719587313763',
  '8718989974565','8710401903269');

update public.product_features set swap_family='bread_bakery', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0083: meerzadenbrood/bollen/pistolets zijn brood, geen zaden'
where barcode in (
  '2254671001004','2258473002757','8715108238430','2298753003197','8718452644803',
  '8719587313787');

update public.product_features set swap_family='plant_based_dairy', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0083: noten-/cashewdrink is een plantaardige zuiveldrank (wortel gefixt in R16)'
where barcode in ('8711812419653','8718907425612','5060120283184');

update public.product_features set swap_family='nut_butters', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0083: cashewpasta/-creme is notenpasta'
where barcode in ('8712439010407','8713576100174');

update public.product_features set swap_family='chocolate_spreads', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0083: Duo Penotti is chocoladepasta'
where barcode in ('87172126');

update public.product_features set swap_family='savory_spreads', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0083: plantaardige cashew-smeerspread is hartig broodbeleg'
where barcode in ('87104912');

update public.product_features set swap_family='ready_meals', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0083: kip-/saladegerecht met noten is een maaltijd, geen noten'
where barcode in (
  '8718989998813','8718907013666','8718907825177','8717228616228','8711578591488');

update public.product_features set swap_family='meal_components', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0083: notenrijst en gekookte kastanjes zijn maaltijdcomponenten'
where barcode in ('8710400418023','3228170000072','3558370200997');

update public.product_features set swap_family='sauces_dips', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0083: pesto is een saus, geen noten'
where barcode in ('8719587254929','8719587091821');

update public.product_features set swap_family='protein_bars', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0083: eiwitreep met noot-smaak is een protein bar'
where barcode in ('8720986899840','4065019081743');

update public.product_features set swap_family='cereal_bars', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0083: noten-/pindareep is een cereal bar (consistent met 0079)'
where barcode in ('8711812409715','8718907383387');

update public.product_features set swap_family='ice_cream_desserts', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0083: pistache-roomijs/ijsrepen zijn ijs, geen noten'
where barcode in ('8719587211960','8717228613142');

update public.product_features set swap_family='breakfast_cereals', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0083: breakfast oats zijn ontbijtgranen'
where barcode in ('8721161680079');

update public.product_features set swap_family='cooking_oils_fats', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0083: walnootolie is een keukenolie, geen noten'
where barcode in ('8710400161936');

update public.product_features set swap_family='meat_alternatives_non_swap', is_swap_relevant=false, classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0083: vegan hazelnootburger is een vleesvervanger, geen snack'
where barcode in ('5425003194306');

update public.product_features set swap_family=null, classification_status='review_required',
  classification_confidence=0.3, classified_at=now(), mapping_version=1,
  classification_reason='audit1_0083: producttype onduidelijk (wit pistache: tablet of anders; hazelnootcreme: puur of choco; HiPro pistache: drink of dessert; Squeezer pistache)'
where barcode in ('8718989753443','8719587255124','8713788124487','8719587255100');

-- R15/R15b/R16: regelwortel-fixes, volledige functie hieronder.
-- POSTFLIGHT: select count(*) from product_features where classification_reason like 'audit1_0083%'; -- 65
-- ROLLBACK: herstel via _snapshot_0083_before.

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
  elsif n ~* 'hagelslag|hagel ?slag|chocoladehagel|chocolade ?vlokken|vruchtenhagel|hagelwit|kokos ?hagel' then
    return 'sweet_spreads_other';

  elsif n ~* 'eiwitreep|protein bar' or c ~* 'protein.?bar' then
    return 'protein_bars';
  elsif n ~* 'mueslireep|cerealreep|granolareep' or c ~* 'cereal.?bar' then
    return 'cereal_bars';
  elsif n ~* 'chocoladereep|candy bar' or c ~* 'chocolate.?bar' then
    return 'chocolate_bars';

  elsif c ~* 'pralines|bonbons|chocolates|filled.chocolates' or p2 ~* 'chocolate'
        or n ~* 'bonbon|praline|\mmerci\M|salmiak' then
    return 'chocolate_confectionery';
  elsif (n ~* 'drop\M|winegum|toffee|marshmallow|spekjes|schuimpjes|zuurtjes|\mlolly|fruittella|napoleon|venco|fruit roll'
         or n ~* 'gummy|gummies|wine ?gums?|fruit ?gums?|liquorice|licorice'
         or c ~* 'liquorice|licorice')
        and n !~* 'vitamine|\mcbd\M|\mhemp\M|supplement' then
    return 'candy_sweets';

  -- R8 (0076): whey/caseine-poeders met ijssmaak zijn supplementen, geen ijs.
  elsif (n ~* '\mijs\M|ice cream|sorbet|gelato' or p2 ~* 'ice cream'
        or (n ~* 'ijs' and n !~* 'ijsbergsla|amandelspijs|spijskoek|radijs|saucijs|parijs|anijs|ijsthee|rijst|prijs|wijze|vrijst|rijswafel'))
        and n !~* '\mwhey\M|case[iï]ne|casein|eiwitpoeder|protein powder' then
    return 'ice_cream_desserts';

  elsif n ~* '\msmoothie\M' then
    return 'smoothies';
  elsif n ~* 'havermelk|amandelmelk|sojamelk|kokosmelk|\moatly\M|\malpro\M|plantaardige melk|soja.?drink|haver.?drink|barista.{0,10}(haver|oat|soja|soy)|(haver|oat|soja|soy).{0,10}barista|(hazelnoot|cashew|amandel|noten|kokos|rijst|erwten).{0,3}drink' then
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

  -- R7 (0076): poffertjes canoniek naar cakes; zalm(staart), pannenkoek/
  -- pancake(mix), bakmixen en rice cakes expliciet uitgesloten.
  elsif n ~* 'taart\M|\mgebak\M|cake\M|flap\M|poffertjes'
        and n !~* 'zalm|\mvis\M|pancake|pannenkoek|bakmix|cake ?mix|mix voor|hartige taart|rice cake' then
    return 'cakes_pastries';
  -- R9 (0079): candybar-merken voor de koekregel, anders wint 'koek' in
  -- namen als "Twix ... koek repen" van het merk. IJs-varianten uitgezonderd.
  elsif (b ~* '\mbueno\M|kit ?kat|\mtwix\M|\mlion\M|\mmars\M|snickers|bounty|knoppers|milky ?way|kinder country|kinder maxi|b.{0,3}tween\M|\mtronky\M'
         or n ~* 'kit ?kat|\mtronky\M')
        and n !~* 'glac[eé]\M|\mijs\M|ice ?cream|sorbet' then
    return 'chocolate_bars';
  -- R10 (0079): stroopwafels/zoete wafels expliciet naar koek (gaven null).
  elsif p2 ~* 'biscuits|cookies' or n ~* '\mkoek|koek\M|cookie|jan hagel|sprits|kletsmajoor|picolient|speculaas|\mkrans|biscuit|stroop ?wafel|stroopkoek|luikse wafel|suikerwafel|eierwafel|\mgaufre|kruidnoten|pepernoten' then
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

  -- R11 (0081): gepaneerde vis is een visproduct, geen borrelsnack.
  elsif n ~* 'visstick|lekkerbek|kibbeling|fish ?cakes?\M|surimi' then
    return 'fish_seafood';
  -- R13 (0081): snackSMAAK-producten (chips 'bitterbal smaak') niet naar fried.
  elsif n ~* 'kroket|croquet|frikandel|bitterbal|kaassouffl[ée]|bamischijf|nasischijf|loempia|\mnuggets?\M'
        and n !~* 'broodje|\mwrap\M|sandwich|maaltijd|kant.?en.?klaar|\msalade\M|\msaus\M|smaak|saveur|flavou?r|chips' then
    return 'fried_snacks';

  -- R12 (0081): popcorn chicken is een fried snack, geen popcorn.
  elsif (n ~* 'popcorn' or c ~* 'popcorn') and n !~* 'chicken|\mkip\M' then
    return 'popcorn';
  -- R14 (0082): friet/frites (OFF-categorie 'chips and fries' bevat 'chips')
  -- en bak-chocochips zijn geen chips-snack.
  elsif (n ~* 'chips|crisps' or c ~* 'chips|crisps')
        and n !~* 'friet|frites|\mfries\M|\mpommes\M|aardappelpartjes|choco.{0,6}chips' then
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

  -- R15 (0083): kruidnoten/dranken/cremes/gebak/salades met noot-namen zijn
  -- geen noten; choco-omhulde noten horen bij chocolade (data-verankerd).
  elsif (p2 ~* '\mnuts\M' or n ~* 'noten|zaden|amandelen|cashew|walnoot|hazelnoot|pistache|pinda|peanut|pecan|macadamia|pitten|pijnboompit|zonnebloempit|pompoenpit')
        and not (n ~* 'pasta|cr[eè]me|\mdrink\M|drank|vlaai|donut|baklava|kadayif|kruidnoten|pepernoten|burger|salade|pesto|olie\M|reep\M|chocolade|chocolate|stroopwafel|saus|sauce|sat[eé]\M|satay|rotsje|\mkaas\M') then
    return 'nuts_seeds';

  elsif n ~* 'soep|\msoup\M' or p2 ~* '\msoup\M' then
    return 'soups';
  elsif (n ~* '\mdip\M|saus|sauce|dressing|streich' or p2 ~* 'sauce|dressing') and not (n ~* 'boter|butter|\molie\M|olive oil') then
    return 'sauces_dips';

  -- R3 (aangescherpt in 0075): honing/siroop alleen voor echte
  -- siropen/honingproducten -- niet voor honing-geAROMAtiseerde producten
  -- (zalm, kip, kaas, noten, mosterd, pretzels, granen) en niet voor
  -- blikfruit "op (lichte) siroop".
  elsif n ~* '\mhoning\M|\mhoney\M|\msiroop\M|\mstroop\M|\msyrup\M|\magave\M|maple syrup|ahornsiroop'
        and n !~* 'wafel|waffle|\mkoek|nootjes|\mnoten\M|cashew|pinda|zalm|salmon|\mkip\M|chicken|\mkaas\M|mosterd|mustard|pretzel|lasagne|multivitamine|cereal|bubbles|op (extra )?(lichte )?siroop|op stroop' then
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
