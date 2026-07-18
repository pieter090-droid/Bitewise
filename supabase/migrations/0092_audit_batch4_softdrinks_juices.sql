-- Fase 1 audit, batch 4 (dranken/overig) — deel 2: leesronde
-- soft_drinks_regular (435) + fruit_juices (160). Elk product individueel
-- gelezen. soft_drinks_regular was de meest vervuilde drankfamilie: de
-- OFF-categorie 'sweetened beverages' sleepte alles wat zoet en vloeibaar is
-- hierheen.
--
-- Hoofdbevindingen:
--  K1 42 ZUIVELdranken -> dairy_drinks: chocolademelk/Cecemel/Chocovit,
--     Fristi/Vifit/Optimel/Melkunie-drinks, HiPro/Milbona protein drinks,
--     kefir, Milkis, en 16 kant-en-klare MELKKOFFIES (Emmi Caffè Latte,
--     Douwe Egberts ice cappuccino, ijskoffie, Starbucks macchiato).
--     Regelwortels R33 (drankmerken Fristi/Optimel/Vifit/Chocomel/HiPro) en
--     R32 (RTD-melkkoffie; koffiePADS blijven hot_beverages).
--  K2 14 koffie/thee-BEREIDINGEN (Senseo-pads, matcha-latte-mixen, Yogi
--     Tea, Pukka, oplosthee, cacao latte) -> hot_beverages.
--  K3 12 eiwitPOEDERS ('clear whey', eiwitlimonade, preworkout, powertabs,
--     recovery drink) -> supplements_powders. Regelwortel R34.
--  K4 9 alcoholvrije bieren/radlers (Heineken 0.0, Affligem 0,0, Jever Fun,
--     Bavaria Fruity rosé) -> alcohol_drinks, consistent met 0091.
--     Regelwortel R35 (alcoholvrij/radler/pils/lager/IPA/weizen/tripel).
--  K5 10 energydrinks (Bullit, Rodeo, Celsius, Perfect Ted, Rockstar,
--     Carlito's, Red Bull) -> energy_drinks; 7 sportdranken (AA ISO,
--     Decathlon Iso, Kruidvat isotonic, AH sportdrank) -> sports_drinks.
--  K6 3 plantaardig (Alpro Caffè/soya vanille, Jumbo erwtendrank) ->
--     plant_based_dairy; 7 groente-/fruitsappen en -shots -> fruit_juices.
--  K7 losse missers: 4 snoep/kauwgom met cola-smaak -> candy_sweets,
--     stroopwafel -> cookies_biscuits, sinas/cola-ijsje ->
--     ice_cream_desserts, bouillon -> soups, groentepan -> meal_components,
--     dadel-/chocoladesiroop -> honey_syrups, appelstroop x2 ->
--     sweet_spreads_other.
--  K8 fruit_juices: 6 fruitCONSERVEN/knijpfruit (ananas op sap, aardbeien
--     op sap, knijpfruit, fruithapje) -> fresh_fruit; 6 flesjes
--     KOOKcitroensap -> sauces_dips; Fanta Orange no sugar ->
--     soft_drinks_light_zero.
--
-- NB limonadeSIROOP-concentraten (Karvan Cévitam, Raak, AH vruchtensiroop)
-- blijven bewust in de frisdrankfamilies: de drankcategorie klopt. Dat een
-- concentraat per 100 ml niet 1-op-1 met kant-en-klaar te vergelijken is,
-- wordt in fase 3c (portie-bewust scoren) opgelost, niet door de familie te
-- forceren. Ice tea blijft frisdrank; kombucha/aloe vera ook.
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

create table if not exists public._snapshot_0092_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  '8712800002130','8712800187653','5413471095928','4065019026386','4065019028908',
  '87124910','8712800196457','5410438040731','8712800034841','8712800148494',
  '8718166008335','8712800035718','8712800002697','8712800140566','8712800035657',
  '8712800035732','8718166007949','8712800011484','4056489723240','4056489723233',
  '8713788123848','8713788123381','8713788123664','8720589887886','5060337222808',
  '7610900237654','7610900138906','7610900198924','7610900138890','7610900239139',
  '7610900238613','7610900056262','8711000261514','8711000675298','8711000261491',
  '8718452638239','8718452390977','2003020017247','8718906696891','8718906696914',
  '4100290025564','8720663431134',
  '8711812407773','4047046008436','4047046005008','5060941970492','5900649083097',
  '8713576001105','8888296051119','4012433011689','4012824600287','4012824600317',
  '4012824600294','5063270111512','8713576001099','9004380071507',
  '8719881031813','8720986894555','8720986895422','8720986895026','8721515020957',
  '8718444868071','8719881008921','8720674454917','8719881036696','5055950627475',
  '7612100026748','8717953212382',
  '5411098731663','8712000059309','8712000057428','8712000039967','87232479',
  '4008948191015','8714800047050','8711406344538','8718907626187',
  '8722200962828','9008703000762','8711900013992','6430056289878','5060941970287',
  '5070000222417','8710398521712','8718858610884','90453618','90453458',
  '8722200962842','3583787691113','5070003170838','8720674365343','8718907384810',
  '8718907384797','8718906768109',
  '5411188129332','5411188115533','8718452876365',
  '8718907924085','8711812112769','8718452275328','8718907924337','8719587322673',
  '8718906674028','4008799101416',
  '8723400939580','4001686370766','8713800257445','4001686347560',
  '8718989950514','8718265511378','4000345051466','3083680041911',
  '8710742021783','8413412209978','8718906644557','8710742023480',
  '20829520','8710400005155','8718452856725','8710400665533','8710400665519',
  '8718452190713','8718906416529','8718265745797','8020542110113','8718976016162',
  '8718976016353','8717496906687','5000112646184'
);

update public.product_features set swap_family='dairy_drinks', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0092: zuiveldrank (chocolademelk/Fristi/Optimel/Vifit/HiPro/kefir) of kant-en-klare melkkoffie hoort in dairy_drinks, niet bij frisdrank (wortels gefixt in R32/R33)'
where barcode in (
  '8712800002130','8712800187653','5413471095928','4065019026386','4065019028908',
  '87124910','8712800196457','5410438040731','8712800034841','8712800148494',
  '8718166008335','8712800035718','8712800002697','8712800140566','8712800035657',
  '8712800035732','8718166007949','8712800011484','4056489723240','4056489723233',
  '8713788123848','8713788123381','8713788123664','8720589887886','5060337222808',
  '7610900237654','7610900138906','7610900198924','7610900138890','7610900239139',
  '7610900238613','7610900056262','8711000261514','8711000675298','8711000261491',
  '8718452638239','8718452390977','2003020017247','8718906696891','8718906696914',
  '4100290025564','8720663431134');

update public.product_features set swap_family='hot_beverages', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0092: koffie-/thee-bereiding (pads, capsules, matcha-latte-mix, oplosthee, kruidenthee) hoort in hot_beverages'
where barcode in (
  '8711812407773','4047046008436','4047046005008','5060941970492','5900649083097',
  '8713576001105','8888296051119','4012433011689','4012824600287','4012824600317',
  '4012824600294','5063270111512','8713576001099','9004380071507');

update public.product_features set swap_family='supplements_powders', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0092: clear whey / eiwitlimonade / preworkout / powertabs is een supplementpoeder, geen kant-en-klare frisdrank (wortel gefixt in R34)'
where barcode in (
  '8719881031813','8720986894555','8720986895422','8720986895026','8721515020957',
  '8718444868071','8719881008921','8720674454917','8719881036696','5055950627475',
  '7612100026748','8717953212382');

update public.product_features set swap_family='alcohol_drinks', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0092: alcoholvrij bier/radler hoort bij de bierfamilie, consistent met 0091 (wortel gefixt in R35)'
where barcode in (
  '5411098731663','8712000059309','8712000057428','8712000039967','87232479',
  '4008948191015','8714800047050','8711406344538','8718907626187');

update public.product_features set swap_family='energy_drinks', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0092: energydrink (Bullit/Rodeo/Celsius/Perfect Ted/Rockstar/Red Bull) hoort in energy_drinks'
where barcode in (
  '8722200962828','9008703000762','8711900013992','6430056289878','5060941970287',
  '5070000222417','8710398521712','8718858610884','90453618','90453458');

update public.product_features set swap_family='sports_drinks', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0092: isotone sportdrank hoort in sports_drinks'
where barcode in (
  '8722200962842','3583787691113','5070003170838','8720674365343','8718907384810',
  '8718907384797','8718906768109');

update public.product_features set swap_family='plant_based_dairy', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0092: Alpro-koffie/sojadrank en erwtendrank zijn plantaardige zuivel'
where barcode in ('5411188129332','5411188115533','8718452876365');

update public.product_features set swap_family='fruit_juices', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0092: groente-/fruitsap en -shots horen bij de sapfamilie (bietensap/tomatensap staan daar al)'
where barcode in (
  '8718907924085','8711812112769','8718452275328','8718907924337','8719587322673',
  '8718906674028','4008799101416');

update public.product_features set swap_family='candy_sweets', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0092: kauwgom/gummi/snoep met colasmaak is snoepgoed, geen frisdrank'
where barcode in ('8723400939580','4001686370766','8713800257445','4001686347560');

update public.product_features set swap_family='cookies_biscuits', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0092: stroopwafel is koek, geen frisdrank'
where barcode in ('8718989950514');

update public.product_features set swap_family='ice_cream_desserts', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0092: sinas/cola-ijsje is waterijs, geen frisdrank'
where barcode in ('8718265511378');

update public.product_features set swap_family='soups', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0092: groentebouillon is soep/bouillon, geen drank'
where barcode in ('4000345051466');

update public.product_features set swap_family='meal_components', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0092: groentepan (poelee) is een maaltijdcomponent, geen drank'
where barcode in ('3083680041911');

update public.product_features set swap_family='honey_syrups', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0092: dadelsiroop en chocoladesiroop (topping) zijn voedingsstropen, geen limonadesiroop'
where barcode in ('8710742021783','8413412209978');

update public.product_features set swap_family='sweet_spreads_other', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0092: appelstroop is broodbeleg, geen drank'
where barcode in ('8718906644557','8710742023480');

update public.product_features set swap_family='fresh_fruit', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0092: fruit op sap/blikfruit en knijpfruit/fruithapje zijn fruitproducten, geen sap (precedent 0075)'
where barcode in (
  '20829520','8710400005155','8718452856725','8710400665533','8710400665519',
  '8718452190713');

update public.product_features set swap_family='sauces_dips', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0092: flesje citroensap/limoensap is een kookzuur/condiment, geen drinksap'
where barcode in (
  '8718906416529','8718265745797','8020542110113','8718976016162','8718976016353',
  '8717496906687');

update public.product_features set swap_family='soft_drinks_light_zero', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0092: Fanta Orange no sugar is een zero-frisdrank, geen vruchtensap'
where barcode in ('5000112646184');

-- R32/R33/R34/R35/R36: regelwortel-fixes, volledige functie hieronder.
-- POSTFLIGHT: select count(*) from product_features where classification_reason like 'audit1_0092%'; -- 129
-- ROLLBACK: herstel via _snapshot_0092_before.

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
  elsif n ~* 'pindakaas|peanut butter|amandelpasta|notenpasta|cashewpasta|hazelnootpasta|pistachepasta|pistachio paste|beurre de cacahu[eè]te|manteiga de amendoim|erdnusscreme|cr[eè]me de cacahu[eè]tes|pinda.{0,3}pasta'
        -- R19 (0086): repen/muesli/granola/ijs/balls/bunnies/bakes uitsluiten.
        and n !~* '\mbar\M|\mreep\M|eiwitreep|muesli|granola|ice ?cream|roomijs|\mballs\M|\mbake\M|bunnies|fudge|filled' then
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
  elsif (b ~* '\mbueno\M|kit ?kat|\mtwix\M|\mlion\M|\mmars\M|snickers|bounty|knoppers|milky ?way|kinder country|kinder maxi|b.{0,3}tween\M|\mtronky\M'
         or n ~* 'kit ?kat|\mtronky\M')
        and n !~* 'glac[eé]\M|\mijs\M|ice ?cream|sorbet' then
    return 'chocolate_bars';
  -- R10 (0079): stroopwafels/zoete wafels expliciet naar koek (gaven null).
  elsif p2 ~* 'biscuits|cookies' or n ~* '\mkoek|koek\M|cookie|jan hagel|sprits|kletsmajoor|picolient|speculaas|\mkrans|biscuit|stroop ?wafel|stroopkoek|luikse wafel|suikerwafel|eierwafel|\mgaufre|kruidnoten|pepernoten|krakeling|d[uú]mkes' then
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
  elsif n ~* '\mbrood\M|croissant|stokbrood|bolletje|baguette|focaccia' or p2 ~* '\mbread\M' then
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
  elsif n ~* 'olijven|\molive\M|olives' then
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
  elsif v_is_light_zero and (n ~* '\mcola\M|frisdrank|\msoda\M|limonade|fanta|sprite|\m7up\M|tonic|bitter lemon|ice.?tea|rivella|sisi\M' or p2 ~* 'sweetened beverages') then
    return 'soft_drinks_light_zero';
  elsif n ~* '\mcola\M|frisdrank|\msoda\M|limonade|fanta|sprite|\m7up\M|tonic|bitter lemon|ice.?tea|rivella|sisi\M'
        or p2 ~* 'sweetened beverages' then
    return 'soft_drinks_regular';
  -- R36 (0092): 'sinaasappelsap'/'appelsap' e.d. eindigen op 'sap' zonder
  -- woordgrens ervoor; 'op sap' (blikfruit), siroop en saus uitgesloten.
  elsif (n ~* '\msap\M|sap\M|juice' or c ~* 'juice')
        and n !~* 'op sap|siroop|\msaus\M|sausje' then
    return 'fruit_juices';
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
