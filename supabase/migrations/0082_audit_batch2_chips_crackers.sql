-- Fase 1 audit, batch 2 (hartig) — deel 2: leesronde crisps_chips (268) +
-- crackers_rice_cakes (240). Elk product individueel gelezen.
--
-- Hoofdbevindingen:
--  K1 27 diepvries/oven-frietproducten (Aviko, McCain, Lamb Weston, AH/
--     Jumbo oven- en airfryerfriet, aardappelpartjes, aardappelwafels)
--     zaten in crisps_chips via de OFF-categorie 'chips and fries' ->
--     meal_components; regelwortel R14 (friet-exclusie in de chipsregel).
--     AH "mini friet" (borrelzoutje) blijft bewust in crisps.
--  K2 14 extruded/gefrituurde zoutjes uit crackers (Cheetos Nibb-It/Goals/
--     gout fromage, Herr's curls, AH Curly, Bugles, Lay's Oven Thins,
--     wokkels, kroepoek, kaasflips, hot krokantjes) -> crisps_chips
--     (consistent met de rest van die merklijnen die al in crisps staan).
--  K3 5 borrel-kaasbiscuits (De Rit batonnets/kaasvlinders, Buiteman
--     geitenkaas, Van Strien palmiers, Roka crispies) -> cheese_snacks
--     (consistent met 0079/Buiteman); crackers MET kaassmaak blijven
--     crackers (broodvervanger-lijn).
--  K4 5 rijstzoutjes/toastjes/pretzel uit crisps -> crackers_rice_cakes
--     (rijstzoutjes-groep staat daar al); 5 gedroogd-fruitchips (appel,
--     banaan) -> nuts_seeds (droogfruit, dadels-precedent 0077); plantain/
--     groente/lotus-chips blijven crisps (hartig gefrituurd).
--  K5 3 bak-chocochips -> baking_ingredients_non_swap (R14 dekt de wortel);
--     Liga Evergreen -> cookies; Ristorante pizza -> ready_meals; Santa
--     Maria dip -> sauces_dips; 3 review_required (Dugadoo's, Mister Choc
--     Speculoos creamy, Casa Mediterrana zonder duidbaar producttype).
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

create table if not exists public._snapshot_0082_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  '8718452509836','8710624234294','8710438126853','8710438128840','2501181458973',
  '8718265503434','8711571093293','8710624286132','8718265503410','8710449919437',
  '8719326061474','8710449944651','20104153','8718265820029','8710449978199',
  '8718452295050','8710624751401','8718265503427','8718906512290','8710624266943',
  '0328069006918','8710449954308','8710449948475','5060037679506','8718907418553',
  '8718452295067','8718989000783',
  '8710398502506','8710398502728','8710398517920','0072600069145','8719587199848',
  '8719587283868','8710398517876','8710398169167','8710398169129','8710398510112',
  '8710398502544','8718452361861','23006232','8718907636827',
  '8711823197045','8711823197069','8710873997193','8716827129009','8710588600074',
  '8710445018479','8718907136167','8710400127222','8856742000035','5715904112982',
  '5706779186079','0793611134133','8718452748822','8718906255203','3760159100835',
  '8718452927371','8721161885184','8721161885160',
  '7622210651785','4001724051275','6317322383433',
  '8710532432966','4056489215226','8717931904537'
);

update public.product_features set swap_family='meal_components', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0082: diepvries/oven-friet en aardappelproducten zijn maaltijdcomponenten, geen chips (OFF-categorie chips-and-fries, wortel gefixt in R14)'
where barcode in (
  '8718452509836','8710624234294','8710438126853','8710438128840','2501181458973',
  '8718265503434','8711571093293','8710624286132','8718265503410','8710449919437',
  '8719326061474','8710449944651','20104153','8718265820029','8710449978199',
  '8718452295050','8710624751401','8718265503427','8718906512290','8710624266943',
  '0328069006918','8710449954308','8710449948475','5060037679506','8718907418553',
  '8718452295067','8718989000783');

update public.product_features set swap_family='crisps_chips', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0082: extruded/gefrituurd zoutje (flips, curls, bugles, wokkels, kroepoek) hoort bij chips, consistent met bestaande merklijnen'
where barcode in (
  '8710398502506','8710398502728','8710398517920','0072600069145','8719587199848',
  '8719587283868','8710398517876','8710398169167','8710398169129','8710398510112',
  '8710398502544','8718452361861','23006232','8718907636827');

update public.product_features set swap_family='cheese_snacks', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0082: borrel-kaasbiscuit hoort in cheese_snacks (consistent met 0079); crackers met kaassmaak blijven crackers'
where barcode in (
  '8711823197045','8711823197069','8710873997193','8716827129009','8710588600074');

update public.product_features set swap_family='crackers_rice_cakes', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0082: rijstzoutjes/borreltoast/pretzel horen bij crackers_rice_cakes (rijstzoutjes-groep staat daar al)'
where barcode in (
  '8710445018479','8718907136167','8710400127222','8856742000035','5715904112982');

update public.product_features set swap_family='nuts_seeds', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0082: appel-/bananenchips is gedroogd fruit (droogfruit-groep, dadels-precedent 0077)'
where barcode in (
  '5706779186079','0793611134133','8718452748822','8718906255203','3760159100835');

update public.product_features set swap_family='baking_ingredients_non_swap', is_swap_relevant=false, classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0082: chocochips zijn bak-ingredient, geen snack (wortel gefixt in R14)'
where barcode in ('8718452927371','8721161885184','8721161885160');

update public.product_features set swap_family='cookies_biscuits', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0082: Liga Evergreen is een koek (zelfde product staat al in cookies_biscuits)'
where barcode in ('7622210651785');

update public.product_features set swap_family='ready_meals', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0082: Ristorante diepvriespizza is een maaltijd, geen cracker'
where barcode in ('4001724051275');

update public.product_features set swap_family='sauces_dips', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0082: tex-mex dipsaus hoort in sauces_dips'
where barcode in ('6317322383433');

update public.product_features set swap_family=null, classification_status='review_required',
  classification_confidence=0.3, classified_at=now(), mapping_version=1,
  classification_reason='audit1_0082: producttype niet duidbaar uit naam/merk (Dugadoo''s, Speculoos creamy: spread of reep, Casa Mediterrana zonder producttype)'
where barcode in ('8710532432966','4056489215226','8717931904537');

-- R14: regelwortel-fix, volledige functie hieronder.
-- POSTFLIGHT: select count(*) from product_features where classification_reason like 'audit1_0082%'; -- 65
-- ROLLBACK: herstel via _snapshot_0082_before.

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
  elsif p2 ~* 'biscuits|cookies' or n ~* '\mkoek|koek\M|cookie|jan hagel|sprits|kletsmajoor|picolient|speculaas|\mkrans|biscuit|stroop ?wafel|stroopkoek|luikse wafel|suikerwafel|eierwafel|\mgaufre' then
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

  elsif (p2 ~* '\mnuts\M' or n ~* 'noten|zaden|amandelen|cashew|walnoot|hazelnoot|pistache') and not (n ~* 'pasta') then
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
