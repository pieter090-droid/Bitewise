-- Fase 1 audit, batch 5 (maaltijd/vers/rest) — deel 2: leesronde
-- bread_bakery (507) + sandwiches_wraps (148). Elk product individueel
-- gelezen.
--
-- Dit deel legt het grootste structurele probleem van de hele audit bloot:
--  K1 Het Nederlandse woord "broodje" betekent zowel een KAAL bread roll als
--     een BELEGD broodje. De sandwich-regel matchte op 'broodje' en trok
--     daardoor ~100 kale broodjes (kaiser-, hamburger-, hotdog-, pita-,
--     melk-, desem-, brunch-, schnitt-, keizerbroodjes) én zoete
--     viennoiserie (chocolade-, kaneel-, koffie-, room-, puddingbroodjes) én
--     hartige bakkerijsnacks (worsten-, saucijzen-, frikandel-, kaas-,
--     pizzabroodjes) naar sandwiches_wraps. Gevolg: wie een hamburgerbroodje
--     scande kreeg belegde sandwiches als swap, en andersom.
--     Regelwortel R51: sandwiches_wraps vereist nu een BELEGD-signaal
--     ('sandwich', 'wrap', 'belegd broodje', of 'broodje <vulling>');
--     R51b laat de broodregel kale broodjes opvangen.
--  K2 6 onbelegde tortilla-/piadine-wraps -> bread_bakery (de tortilla-wraps
--     stonden daar al; dit heft de splitsing op).
--  K3 66 CRISPBREAD-producten stonden in bread_bakery: knäckebröd (de regel
--     had alleen 'knackebrod' zonder umlauts), melba toast, biscottes,
--     Wasa/Leksands crispbread, Bolletje Oerknäck, grissini/broodstengels,
--     krokante toast, croutons, soepstengels, zwieback, Dr. Karg's ->
--     crackers_rice_cakes. Regelwortel R52.
--  K4 losse missers uit bread_bakery: 6 paneermeel/bakmix -> baking, 3
--     aardappelbolletjes/burgermeat/Spaanse tortilla (omelet) ->
--     meal_components, vanillevla -> dairy_desserts, 2 kaasbolletjes ->
--     cheese_snacks, belegde baguette -> sandwiches_wraps, tortillachips ->
--     crisps_chips, 1 review ("Brood spread").
--  K5 uit sandwiches_wraps: 3 sandwich spreads -> savory_spreads, 3
--     sandwichaugurken/-dressings/tacosaus -> sauces_dips, zalmplakken ->
--     fish_seafood.
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

create table if not exists public._snapshot_0096_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where swap_family in ('bread_bakery','sandwiches_wraps');

-- K1+K2: kale broodjes, viennoiserie, hartige bakkerijsnacks en onbelegde
-- tortilla-wraps -> bread_bakery.
update public.product_features set swap_family='bread_bakery', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0096: kaal broodje / zoete viennoiserie / hartige bakkerijsnack / onbelegde tortillawrap is bakkerij, geen belegd broodje (wortel gefixt in R51/R51b)'
where barcode in (
  '8718906150508','8718906154056','8718907704366','8718906693081','8718907198011',
  '8719587287859','8719587044209','8718907211307','88884424','8719689949006',
  '8718452650668','8710871401159','8718907765237','8718452815531','8718906150447',
  '1095019902338','8710871399463','4056489286165','20521066','8719587056813',
  '8718564135459','8718452971985','8718452649792','8718452649785','8718907614979',
  '8719587056820','8901529079916','2167908001497','8172927232818','8718452554164',
  '8718452356447','8715196064560','8718927232405','8718907440585','8718452566884',
  '8718906749085','8718452836024','8718452933532','8718452933501','8718907211291',
  '8717228617492','8718452637362','8710624214647','8718907128179','8710400165620',
  '8718927761059','25012484','8719587009666','8718907657839','27067963',
  '4056489218524','2152063001383','8718907261043','8718452393763','8710400631491',
  '8718265010970','4260634275434','8719587009581','8718907197168','5012121010382',
  '8710400606338','8720589173316','4056489680581','8719587313909','8710871413046',
  '8718452437283','8718265810198','8718452871315','8718989076849','8718796047582',
  '8718452633388','8718452436316','20114350','8718907097703','8718907170079',
  '8718452887927','8718907614948','2170388000980','8710624852252','8718907108126',
  '2270489001807','8717931022842','8719587009567','4068706918032','8710624453954',
  '2272642001990','4065019015786','8718265445383','8718452966486','8718452966479',
  '8718907151702','8710555482306','8718452994571','8718452647460','8712076090886',
  '23017221','8718452981526','8719089007429','8718906169890','8718452356782',
  '8718452994519','8718452203314','8719587009574',
  '7311312009760','7311312009784','7311310331276','9481018016183','8718976016285',
  '8720182761187');

-- K3: crispbread/toast/grissini/croutons/soepstengels -> crackers.
update public.product_features set swap_family='crackers_rice_cakes', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0096: knäckebröd/melba toast/biscotte/crispbread/grissini/crouton/soepstengel is knapperig plat baksel, hoort bij crackers (regel had alleen "knackebrod" zonder umlauts; wortel gefixt in R52)'
where barcode in (
  '8718265743489','8710400197430','8710649121067','8710785120078','8000270010121',
  '8710649120992','8017596077875','8718907087018','8719587056622','8718907360012',
  '0752945086952','8718907081511','8718452924110','8718452617302','8710624312374',
  '8720326041397','8718452215706','8710482534192','8718906445383','8718907086936',
  '8718907086912','8718907081528','8710482534536','7300400481731','4024297007814',
  '8710482532938','8710482535076','8710482532174','7300400482820','7300400126229',
  '7300400245005','7300400483285','7300400481823','7312082002104','8008698007303',
  '4022993047127','8710445018233','8710759005707','0085097289095','8710759305326',
  '8008698002100','5706779186000','4022993045987','8007197000099','8720299320987',
  '8718907466844','4033634062201','4033634076000','8711521912032','3270190178927',
  '3564700121511','3268350120336','20978105','20067816','4006182005044',
  '8712100540981','8718907854702','8711299100303','8710624620820','8718265422834',
  '8718265422841','8718452548460','8718265422810','8710445024951','8710445024364',
  '8009280002249');

-- K4/K5: losse missers.
update public.product_features set swap_family='baking_ingredients_non_swap', is_swap_relevant=false, classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0096: paneermeel/chapelure/semmelbrösel en broodbakmix zijn bak-ingredienten, geen brood'
where barcode in (
  '8710400665656','0858051520011','8713445020244','4008791003602','4000186010400',
  '8710466325327');

update public.product_features set swap_family='meal_components', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0096: aardappelbolletjes, burgervlees en Spaanse tortilla (aardappelomelet) zijn maaltijdcomponenten, geen brood'
where barcode in ('8710449913626','13356194','8718907540599');

update public.product_features set swap_family='dairy_desserts', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0096: "Bolletjes Vla Vanille" is vla, geen broodje'
where barcode in ('8712800003090');

update public.product_features set swap_family='cheese_snacks', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0096: kaasbolletjes (geitenkaas/Parmigiano) zijn kaassnacks, geen brood'
where barcode in ('4065019064579','8718452916177');

update public.product_features set swap_family='sandwiches_wraps', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0096: luxe baguette kip caesar is een kant-en-klaar belegd broodje'
where barcode in ('8718907533553');

update public.product_features set swap_family='crisps_chips', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0096: tortillachips zijn chips, geen brood'
where barcode in ('7311312006967');

update public.product_features set swap_family='savory_spreads', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0096: sandwich spread / sandwichvulling is broodbeleg, geen belegd broodje'
where barcode in ('8715700421049','8715700421056','7311360000085');

update public.product_features set swap_family='sauces_dips', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0096: sandwichaugurken, saladedressing en taco-saus zijn condimenten'
where barcode in ('4012200401149','8713883199960','8719587020579');

update public.product_features set swap_family='fish_seafood', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0096: zalm-sandwichplakken zijn gerookte zalm, geen broodje'
where barcode in ('8710400383956');

update public.product_features set swap_family=null, classification_status='review_required',
  classification_confidence=0.3, classified_at=now(), mapping_version=1,
  classification_reason='audit1_0096: "Brood spread" onduidelijk (zoet of hartig broodbeleg)'
where barcode in ('8718907267434');

-- R51/R51b/R52: regelwortel-fixes, volledige functie hieronder.
-- POSTFLIGHT: select count(*) from product_features where classification_reason like 'audit1_0096%'; -- 197
-- ROLLBACK: herstel via _snapshot_0096_before (volledige beide families).

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

  if n ~* 'smeerkaas|cream cheese spread|roomkaas smeerbaar|streich\M|bruschetta spread' then
    return 'savory_spreads';
  elsif n ~* 'pindakaas|peanut butter|amandelpasta|notenpasta|cashewpasta|hazelnootpasta|pistachepasta|pistachio paste|beurre de cacahu[eè]te|manteiga de amendoim|erdnusscreme|cr[eè]me de cacahu[eè]tes|pinda.{0,3}pasta'
        -- R19 (0086): repen/muesli/granola/ijs/balls/bunnies/bakes uitsluiten.
        and n !~* '\mbar\M|\mreep\M|eiwitreep|muesli|granola|ice ?cream|roomijs|\mballs\M|\mbake\M|bunnies|fudge|filled' then
    return 'nut_butters';
  elsif n ~* 'hummus|houmous|humus\M|hoemoes' then
    return 'hummus_legume_spreads';
  elsif n ~* 'nutella|chocopasta|choco.?pasta' or c ~* 'chocolate.?spread|cocoa.and.hazelnut' then
    return 'chocolate_spreads';
  elsif n ~* '\mjam\M|confiture|marmelade|fruitspread|vruchtenspread|fruit spread' then
    return 'jams_fruit_spreads';
  elsif n ~* 'hagelslag|hagel ?slag|chocoladehagel|chocolade ?vlokken|vruchtenhagel|hagelwit|kokos ?hagel' then
    return 'sweet_spreads_other';

  elsif n ~* 'eiwitreep|protein bar' or c ~* 'protein.?bar' then
    return 'protein_bars';
  -- R48a (0095): repen met spatie ("muesli hazelnoot reep"), haver-/
  -- graanrepen en het merk B'tween (granenreep, geen candy bar).
  elsif n ~* 'mueslireep|cerealreep|granolareep|muesli.{0,16}re+p(en)?\M|granola ?bar|granola bites|havermout ?re+p(en)?|haverre+p(en)?|graanre+p(en)?'
        or c ~* 'cereal.?bar' or b ~* 'b.{0,3}tween\M' then
    return 'cereal_bars';
  elsif n ~* 'chocoladereep|candy bar' or c ~* 'chocolate.?bar' then
    return 'chocolate_bars';

  elsif c ~* 'pralines|bonbons|chocolates|filled.chocolates' or p2 ~* 'chocolate'
        or n ~* 'bonbon|praline|\mmerci\M|salmiak' then
    return 'chocolate_confectionery';
  elsif (n ~* 'drop\M|winegum|toffee|marshmallow|spekjes|schuimpjes|zuurtjes|\mlolly|fruittella|napoleon|venco|fruit roll'
         or n ~* 'gummy|gummies|wine ?gums?|fruit ?gums?|yoghurt ?gums?|liquorice|licorice'
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
  -- R29 (0090): plantaardige KAASvervangers (plakken/rasp/Violife/
  -- Soyananda/gouda-smaak) horen bij cheese_snacks, net als zuivelkaas.
  elsif b ~* 'violife|soyananda'
        or n ~* 'plantaardige (plakken|rasp)|vegan plakken|gouda.?smaak|gouda flavour|plant based alternative to|plantaardig alternatief voor (goudse )?kaas' then
    return 'cheese_snacks';
  -- R28 (0090): plantaardige KOOKroom/slagroom-alternatief is een
  -- kookingredient, geen drinkbare plantaardige zuivel.
  elsif n ~* '\mcuisine\M|kochcreme|kochsahne|keuken ?room|\mkeuken\M|fra[iî]che|whipping|zum kochen|[àa] cuisiner|slagroom|plantaardige topping|creamers?\M|creamed coconut' then
    return 'dairy_cooking_cream_non_swap';
  -- R27 (0090): kokosmelk/coconut milk (blik, kookvet ~18%) is een
  -- kookingredient; 'kokosdrink'/'coconut drink' blijft plantaardige zuivel.
  elsif n ~* 'kokosmelk|kokos ?melk|coconut milk|lait de coco'
        and n !~* 'drink|drinking|drank' and b !~* 'drinking' then
    return 'dairy_cooking_cream_non_swap';
  elsif n ~* 'havermelk|amandelmelk|sojamelk|kokosmelk|\moatly\M|\malpro\M|plantaardige melk|soja.?drink|haver.?drink|barista.{0,10}(haver|oat|soja|soy)|(haver|oat|soja|soy).{0,10}barista|(hazelnoot|cashew|amandel|noten|kokos|rijst|erwten).{0,3}drink|op basis van (amandel|soja|soya|haver|kokos|rijst|noten)|soja ?gurt|sojagurt|oat ?gurt|oatgurt' or b ~* '\malpro\M|provamel|\moatly\M|abbot kinney|vemondo' then
    return 'plant_based_dairy';
  -- R21 (0087): plantaardige yoghurt/kwark/skyr (soja/haver/amandel/alpro)
  -- is plantaardige zuivel, geen dagvers-zuivel.
  elsif (n ~* 'yoghurt|yaourt|yogur|joghurt|skyr|kwark|quark')
        and (n ~* 'plantaardig|\msoja\M|soya|\mhaver\M|amandel|op basis van|alternatief voor' or b ~* '\malpro\M') then
    return 'plant_based_dairy';
  -- R22 (0087): kefir en drinkyoghurt zijn zuiveldranken.
  elsif n ~* 'kefir|\mboire\M|drinkyog' then
    return 'dairy_drinks';
  elsif n ~* 'yoghurt|yaourt|yogur|joghurt|skyr|kwark|quark'
        and not (v_is_drink_named or n ~* 'dressing|saus|sauce|\mdip\M|biscuit') then
    return 'yoghurt_skyr_quark';
  -- R24 (0088): drankMIX/poeder/coffee-pods/maaltijddranken zijn geen
  -- kant-en-klare zuiveldrank.
  elsif (n ~* 'chocomel|karnemelk|milkshake|yogidrink|\mcafe au lait\M|caf[ée] au lait'
         or (v_is_drink_named and (p1 ~* 'dairy|milk' or n ~* 'melk|yoghurt|yogur'))
         or b ~* '\mfristi\M|\moptimel\M|\mvifit\M|chocomel|cecemel|\mhipro\M')
        and n !~* 'mix voor|\mpoeder\M|poudre|powder|dolce gusto|capsule|drinkmaaltijd|meal replacement' then
    return 'dairy_drinks';
  -- R25 (0088): kant-en-klare drinkmelk (naam eindigt op 'melk') is een
  -- zuiveldrank. Plantaardige melk is al eerder afgevangen; poeder/mix/
  -- koffiemelk uitgesloten. 'melkchocolade' eindigt niet op 'melk' -> veilig.
  elsif n ~* 'melk\M' and n !~* '\mpoeder\M|poudre|powder|mix voor|koffiemelk|melkpoeder' then
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
  elsif (b ~* '\mbueno\M|kit ?kat|\mtwix\M|\mlion\M|\mmars\M|snickers|bounty|knoppers|milky ?way|kinder country|kinder maxi|\mtronky\M'
         or n ~* 'kit ?kat|\mtronky\M')
        and n !~* 'glac[eé]\M|\mijs\M|ice ?cream|sorbet' then
    return 'chocolate_bars';
  -- R10 (0079): stroopwafels/zoete wafels expliciet naar koek (gaven null).
  elsif p2 ~* 'biscuits|cookies' or n ~* '\mkoek|koek\M|cookie|jan hagel|sprits|kletsmajoor|picolient|speculaas|\mkrans|biscuit|stroop ?wafel|stroopkoek|luikse wafel|suikerwafel|eierwafel|\mgaufre|kruidnoten|pepernoten|krakeling|d[uú]mkes|koffie ?wafel|caf[eé] noir' then
    return 'cookies_biscuits';
  elsif n ~* 'cracker|beschuit|rice cake|kn[aä]cke ?br[oö]?[dt]|kn[aä]ck\M|oerkn[aä]ck|melba ?toast|biscotte|crispbread|knusperbrot|krokante? toast|toastjes|grissini|bread ?stick|broodstengel|soepstengel|soep ?bolletjes|crouton|zwieback|pain croquant|petits pains grill|tartine croustillante|thin crisp|\mpicos\M'
        or n ~* 'rijstwafel|rijswafel|maiswafel'
        or c ~* 'cracker' then
    return 'crackers_rice_cakes';

  -- R48 (0095): mueslibrood/-bol/-koek/-reep is bakkerij of reep, geen
  -- ontbijtgranola.
  elsif n ~* '\mgranola\M|muesli'
        and n !~* 'brood\M|\mbol\M|bollen|koek|\mreep\M|repen|\mbar\M|bites' then
    return 'granola_muesli';
  -- R49 (0095): havermout/havervlokken/brinta/ontbijtpap/porridge/oats
  -- classificeerden helemaal niet; repen zijn hier uitgesloten.
  elsif (p2 ~* 'breakfast cereal'
         or n ~* 'corn ?flakes|ontbijtgranen|cruesli|havermout|havervlokken|\mbrinta\M|ontbijtpap|porridge|\moats\M|gepofte')
        and n !~* '\mre+p(en)?\M|\mbar\M|\mkoek' then
    return 'breakfast_cereals';
  -- R51 (0096): 'broodje' is in het NL zowel een KAAL broodje als een
  -- BELEGD broodje. Alleen kant-en-klaar belegd hoort hier; kale broodjes
  -- en tortilla-wraps gaan naar bread_bakery.
  elsif (n ~* '\msandwich\M|clubsandwich|belegd broodje|\mwrap\M'
         or n ~* 'broodje (kaas|kip|ham|rookworst|mozzarella|tonijn|zalm|gezond|frikandel)')
        and n !~* 'spread|dressing|\msaus\M|sauce|slices|plakken|tortilla|piadine|extra thin|flatbread|augurk' then
    return 'sandwiches_wraps';
  elsif n ~* 'brood\M|broodje|tortilla|piadine|naan\M|\mpita\M|croissant|stokbrood|bolletje|baguette|focaccia' or p2 ~* '\mbread\M' then
    return 'bread_bakery';

  elsif n ~* 'droge worst|beef jerky|[ck]abanoss?i|kabanos\M|snackworst|biltong|\mbifi\M|knakworst|\mknaks\M|cocktailworst|bockworst|aperitiefsalami' then
    return 'meat_snacks';
  -- R18 (0085): maaltijden/pizza/soep/smeersalades met ham/salami in de
  -- naam zijn geen vleeswaren-beleg.
  elsif (n ~* '\mham\M|salami|cervelaat|rookvlees|\mpat[ée]\M|leverworst|kipfilet|achterham|vleeswaren|boterhamworst|tostiham|boerenpat[ée]|fleischsalat|\mfuet\M|bresaola|bresola|pancetta|\mamericain\M|\msalam\M|grillworst'
         or p2 ~* 'processed meat')
        and n !~* 'pizza|quiche|nasi|soup|croissant|tagliatelle|tortellini|rookworst|fleischsalat|\msalade\M|chips|\mwok\M|ovenpasta' then
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
  -- R45 (0094): 'olive' in huile d'olive / sardines a l'huile d'olive is
  -- het olie-woord, geen olijvenpotje.
  elsif n ~* 'olijven|\molive\M|olives'
        and n !~* 'olie\M|\moil\M|huile|sardines|\mthon\M|tonijn|filets?\M|\mbrood\M|bread' then
    return 'sauces_dips';
  -- R17 (0084): grillworst/dips/maaltijden/spreads met 'kaas' in de naam
  -- zijn geen kaas.
  elsif (p2 ~* '\mcheese\M' or n ~* '\mkaas\M|\mcheese\M')
        and n !~* 'grillworst|\mworst\M|\mdip\M|pizza|salade|spread|carpaccio|girasoli|mac.{0,4}cheese|macaroni|schnitzel|\mrondo\M|\mfilet\M|muffin|zoutjes|snackmix|nachos|flips|crispers' then
    return 'cheese_snacks';

  -- R20 (0086): roomboter-BAKKERIJ (krakeling/dumkes/cupcake/bollen/pastei/
  -- focaccia/kaasvlinder/cacaoboter) is geen smeerbare boter.
  elsif (n ~* 'boter\M|\mmargarine\M|\mhalvarine\M') and not (n ~* 'aardappel|frites|friet|krokett|croquett|krakeling|d[uú]mkes|cupcake|\mbollen\M|puntjes|pastei|krentenbol|focaccia|kaasvlinder|marmer|stroopkoek|cacao ?boter') then
    return 'butter_margarine';

  -- R30 (0091): cocktailSAUS, kookpudding met rum en kookwijn/mirin zijn
  -- geen alcoholische dranken.
  elsif (n ~* 'bier|\mwijn\M|wodka|whisky|whiskey|\mrum\M|\mgin\M|likeur|prosecco|cava\M|alcoholvrij|alkoholfrei|\mradler\M|\mpils\M|\mlager\M|\mipa\M|weizen|weissbier|tripel' or p1 ~* 'alcoholic')
        and n !~* 'saus|sauce|pudding|mirin|kookwijn|azijn' then
    return 'alcohol_drinks';

  elsif n ~* 'red bull|monster energy|\maa\M drink|energy ?drink|rockstar' then
    return 'energy_drinks';
  elsif n ~* 'isostar|gatorade|powerade|sportdrank|aquarius' then
    return 'sports_drinks';
  -- R34 (0092): 'clear whey'/eiwitlimonade/preworkout zijn poeders, geen
  -- kant-en-klare frisdrank.
  elsif n ~* 'clear whey|clear protein|eiwit ?limonade|protein lemonade|protein ice ?tea|preworkout|powertabs|recovery drink' then
    return 'supplements_powders';
  -- R32 (0092): kant-en-klare melkkoffie (caffè latte, ijskoffie, ice
  -- cappuccino) is een zuiveldrank; koffiePADS/capsules blijven hot_beverages.
  elsif n ~* 'caff[eè] ?latte|caffe drink|ice ?coffee|ijskoffie|ijskoude|ice ?cappucc?ino|ice mocha|caramel macchiato|macchiato'
        and n !~* 'pads|capsule|senseo|oplos|\mmix\M' then
    return 'dairy_drinks';
  elsif v_is_light_zero and (n ~* '\mcola\M|frisdrank|\msoda\M|limonade|fanta|sprite|\m7up\M|tonic|bitter lemon|ice.{0,2}tea|ijsthee|fuze ?tea|rivella|sisi\M' or p2 ~* 'sweetened beverages') then
    return 'soft_drinks_light_zero';
  elsif n ~* '\mcola\M|frisdrank|\msoda\M|limonade|fanta|sprite|\m7up\M|tonic|bitter lemon|ice.{0,2}tea|ijsthee|fuze ?tea|rivella|sisi\M'
        or p2 ~* 'sweetened beverages' then
    return 'soft_drinks_regular';
  -- R36 (0092): 'sinaasappelsap'/'appelsap' e.d. eindigen op 'sap' zonder
  -- woordgrens ervoor; 'op sap' (blikfruit), siroop en saus uitgesloten.
  elsif (n ~* '\msap\M|sap\M|juice' or c ~* 'juice')
        and n !~* 'op sap|siroop|\msaus\M|sausje' then
    return 'fruit_juices';
  -- R37 (0093): koffiemelk/koffiecreamer is koffieroom, geen warme drank.
  elsif n ~* 'koffiemelk|koffie ?melk|koffiecreamer|koffie ?creamer|coffee creamer|koffieroom' then
    return 'dairy_cooking_cream_non_swap';
  elsif n ~* 'koffie|\mcoffee\M|\mcafe\M|cappuccino|espresso|latte\M|\mthee\M|\mtea\M' or p2 ~* 'coffee and tea' then
    return 'hot_beverages';
  -- R31 (0091): 'in water' ingeblikt voedsel (bonen, sardines) en
  -- bereidingsmixen ('water toevoegen') zijn geen drinkwater.
  elsif (n ~* '\mwater\M|bronwater|mineraalwater' or p2 ~* 'waters and flavored waters')
        and not v_is_drink_named
        and n !~* '\mbeans\M|bonen|sardines|tonijn|soep|soup|toevoegen|\mvoeg\M|in water\M' then
    return 'water';

  -- R15 (0083): kruidnoten/dranken/cremes/gebak/salades met noot-namen zijn
  -- geen noten; choco-omhulde noten horen bij chocolade (data-verankerd).
  elsif (p2 ~* '\mnuts\M' or n ~* 'noten|zaden|amandelen|cashew|walnoot|hazelnoot|pistache|pinda|peanut|pecan|macadamia|pitten|pijnboompit|zonnebloempit|pompoenpit')
        and not (n ~* 'pasta|cr[eè]me|\mdrink\M|drank|vlaai|donut|baklava|kadayif|kruidnoten|pepernoten|burger|salade|pesto|olie\M|reep\M|chocolade|chocolate|stroopwafel|saus|sauce|sat[eé]\M|satay|rotsje|\mkaas\M') then
    return 'nuts_seeds';

  -- R40 (0093): soepGROENTE, soepstengels/-croutons, soepballetjes en
  -- verspakketten zijn ingredienten, geen kant-en-klare soep.
  -- Tevens: 'bouillon(blokjes)' bevat geen soep/soup en werd door geen
  -- enkele regel geclassificeerd; bereid is het soep -> hier ondergebracht.
  elsif (n ~* 'soep|\msoup\M|bouillon|\mbrodo\M' or p2 ~* '\msoup\M')
        and n !~* 'soepgroente|soepgroenten|soepstengel|soep ?stengel|crouton|soepballetjes|soep ?balletjes|verspakket|groentepakket' then
    return 'soups';
  -- R41 (0094): mayonaise en mayo-varianten horen in mayonnaise_sauces.
  elsif n ~* 'mayonaise|mayonnaise|mayonesa|\mmayo\M|yogonaise|halvanaise|mayolijn' then
    return 'mayonnaise_sauces';
  -- R42 (0094): 'in tomatensaus' ingeblikte bonen/vis/vlees, maaltijden,
  -- verspakketten en olijfolie zijn geen saus of dip.
  elsif (n ~* '\mdip\M|saus|sauce|dressing|ketchup|\mpesto\M|mosterd|mustard|\msenf\M|moutarde|sambal|ketjap|azijn|vinegar|passata|tomatenpuree|\msalsa\M|chutney|tapenade|guacamole|tzatziki|aioli|allioli|piccalilly|\msugo\M' or p2 ~* 'sauce|dressing')
        and not (n ~* 'boter|butter|\molie\M|olive oil|huile d.olive|olijfolie')
        and n !~* 'bonen in|beans in|haricots|filets?\M|sardines|\mthon\M|tonijn|\mworst\M|balletjes|rendang|ravioli|medaglioni|gyoza|maaltijd|verspakket|pizzadeeg|grissini|sausage roll|tagliatelle|rauwkost' then
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
