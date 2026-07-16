-- Fase 1 audit, batch 1 (zoet) — deel 6 (slot): leesronde cookies_biscuits
-- (599). Elk product individueel gelezen. Laatste familie van batch 1.
--
-- Hoofdbevindingen:
--  K1 42 fruit/noten/granen-REPEN (nakd, Holie's chewy/crunchy, Zonnatura,
--     Castus, BE-KIND, 4GOLD, Bolletje repen, ...) -> cereal_bars.
--  K2 43 gebak-producten (tompouce, donuts, roze koek, soesjes, spekkoek,
--     stollen, muffins, brownies, Balconi snackcakes, panforte, custard-
--     cakes, boterkoek, baklava, cannoli, eclairs) -> cakes_pastries.
--  K3 11 candybars (KitKat, Twix koekrepen, Kinder Tronky, B'tween x3,
--     Tunnock's, Nucao, Korona caramel/pinda bars) -> chocolate_bars;
--     regelwortel R9: merkcheck gehesen tot voor de koekregel.
--  K4 10 tabletten/pralines/figuren (Ferrero Rocher, Milka & Daim, Zaans
--     huisje x3, schoko-taler, jelly beanies) -> chocolate_confectionery.
--  K5 14 mais/rijst/linzen/kikkererwten-wafels + Snack a Jack + choco rice
--     cakes + crousty roll + taralli/aperitiefbiscuits -> crackers_rice_cakes
--     (regel bestond al; legacy-rijen).
--  K6 4 kaasbiscuits (Buiteman, palmiers, Jumbo milde kaas) -> cheese_snacks.
--  K7 9 bakmixen/cookie dough om af te bakken/chocolate chips/oliebollenmix
--     -> baking_ingredients_non_swap (is_swap_relevant=false).
--  K8 3 whey-poeders -> supplements_powders; 7 proteine-cookies/-bars
--     (XXL, Myprotein, More, Decathlon, Plenny) -> protein_bars; eiwit-oats
--     -> breakfast_cereals; Holie's granola -> granola_muesli.
--  K9 5 broodbeleg-items (cookies&cream spread, schuddebuikjes, strooi-
--     speculaas, speculaas op brood, Vlugge Japie kokosbrood) ->
--     sweet_spreads_other; Monin cookie-siroop -> honey_syrups; 4 mochi ->
--     candy_sweets; Twix glace + Cookie Gelati -> ice_cream_desserts.
--  K10 11 x review_required (hash muffin, speculoos crunchy [spread of
--     koek?], onleesbare namen "Spul"/"Vbbb"/"TEDO STACK", cappuccino met
--     biscuit, vegan hazelnootreep, Zonnatura choco-items, Action brownie).
--  NB ontbijtkoek/kruidkoek/peperkoek-groep (~30) blijft bewust in
--     cookies_biscuits: consistente koek-groep, onderling goede swaps.
--     Macarons/makronen/meringues blijven eveneens (droog koekje-achtig).
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

create table if not exists public._snapshot_0079_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  '3608394307247','8718858937134','5060088707685','5060088705087','5060088705148',
  '5060088704783','8718858932900','8718858932924','8710482534895','5000159532921',
  '8711812425913','8710508923177','8711812420680','8718906577114','4058172390081',
  '5707653009446','8718907520515','3800225477895','8718215837992','8711812407711',
  '8710863806092','8711812415426','8711812415709','8719979204266','20397272',
  '8711812438166','5412158006073','87304565','8721161523857','8721161523871',
  '8721398329000','8721161523864','8720256082996','8721161523888','11202743',
  '8721161523161','8720256082750','8721161523826','5430002742908','5430002742526',
  '5430002742892','5430002742595',
  '5411823029089','3428420053203','20616373','8715108199670','8710739487356',
  '8710624334055','3178530404333','8718452355167','2271715001585','2153984001506',
  '8718452429677','20048280','8436546520672','8719587250501','8721245434390',
  '8718796097334','8718907408301','8718265162761','8718452592838','8718989959197',
  '8718452423576','4056489792840','8718452407910','8718265097049','47000193',
  '8718907558143','8719587268285','4056489512868','3560070759927','8001585008872',
  '8001585008865','8001585001071','8001585010424','5900864735108','8711654005205',
  '8711654005182','8710624854508','8718906754386','8002590055462','8002590055455',
  '3017760290692','7613287523396','8718906342750',
  '7613036748612','5000189974593','8000500384794','8713500013105','8713500080893',
  '8713500013570','5000159606134','5010975075076','4260500650044','8719324585071',
  '8719324585415',
  '8000500009673','4065019086755','7622300419394','9300617065722','8718754740739',
  '8710400066965','8718907269254','8718907269278','8711823193481','8718989022570',
  '5000159484695','87333985',
  '8718907057752','8718907468312','8710871402880','8718906445338','3380380070280',
  '8711812424626','8718452856107','8710624938895','8710398523365','8719979203535',
  '8606012185067','8717496903716','4068706089152','8710624988319',
  '8710873997179','0799181903490','8710873998763','8718452922796',
  '00678515','8718774040468','4015637824130','8718452885374','4335619317239',
  '8718907400701','8718452396696','8710479307105','8718907400763',
  '8718774052379','8719214560867','8682696610187',
  '5056555208106','8719881021760','3608390891580','5059883484488','4255719314337',
  '8719327489413','8720165350025',
  '8720986893800','8721161523246','0051770051365',
  '4068428058696','8710482532112','8710624409326','8710624221454','4056489547594',
  '8717624007699','8717624007668','4711931037091','4714221131219',
  '8594018432424','5410126016949','4065019030864','8717953200914','10027110',
  '87328677','8711812417352','8718907921282','8711812422141','8711812421113',
  '8719979203894'
);

update public.product_features set swap_family='cereal_bars', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0079: fruit-/noten-/granenreep is een cereal bar, geen koekje'
where barcode in (
  '3608394307247','8718858937134','5060088707685','5060088705087','5060088705148',
  '5060088704783','8718858932900','8718858932924','8710482534895','5000159532921',
  '8711812425913','8710508923177','8711812420680','8718906577114','4058172390081',
  '5707653009446','8718907520515','3800225477895','8718215837992','8711812407711',
  '8710863806092','8711812415426','8711812415709','8719979204266','20397272',
  '8711812438166','5412158006073','87304565','8721161523857','8721161523871',
  '8721398329000','8721161523864','8720256082996','8721161523888','11202743',
  '8721161523161','8720256082750','8721161523826','5430002742908','5430002742526',
  '5430002742892','5430002742595');

update public.product_features set swap_family='cakes_pastries', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0079: vers/zacht gebak (tompouce, donut, roze koek, soes, spekkoek, stol, muffin, brownie, snackcake) hoort in cakes_pastries'
where barcode in (
  '5411823029089','3428420053203','20616373','8715108199670','8710739487356',
  '8710624334055','3178530404333','8718452355167','2271715001585','2153984001506',
  '8718452429677','20048280','8436546520672','8719587250501','8721245434390',
  '8718796097334','8718907408301','8718265162761','8718452592838','8718989959197',
  '8718452423576','4056489792840','8718452407910','8718265097049','47000193',
  '8718907558143','8719587268285','4056489512868','3560070759927','8001585008872',
  '8001585008865','8001585001071','8001585010424','5900864735108','8711654005205',
  '8711654005182','8710624854508','8718906754386','8002590055462','8002590055455',
  '3017760290692','7613287523396','8718906342750');

update public.product_features set swap_family='chocolate_bars', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0079: candy bar (KitKat/Twix/Tronky/B-tween/Tunnocks/Nucao/Korona), consistent met merkregel; wortel gefixt in R9'
where barcode in (
  '7613036748612','5000189974593','8000500384794','8713500013105','8713500080893',
  '8713500013570','5000159606134','5010975075076','4260500650044','8719324585071',
  '8719324585415');

update public.product_features set swap_family='chocolate_confectionery', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0079: tablet/praline/chocoladefiguur hoort in chocolate_confectionery'
where barcode in (
  '8000500009673','4065019086755','7622300419394','9300617065722','8718754740739',
  '8710400066965','8718907269254','8718907269278','8711823193481','8718989022570');

update public.product_features set swap_family='ice_cream_desserts', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0079: ijsproduct (Twix glace, cookie gelati), geen koekje'
where barcode in ('5000159484695','87333985');

update public.product_features set swap_family='crackers_rice_cakes', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0079: mais-/rijst-/peulvruchtwafel of aperitiefbiscuit hoort in crackers_rice_cakes (regel bestond al; legacy-rij)'
where barcode in (
  '8718907057752','8718907468312','8710871402880','8718906445338','3380380070280',
  '8711812424626','8718452856107','8710624938895','8710398523365','8719979203535',
  '8606012185067','8717496903716','4068706089152','8710624988319');

update public.product_features set swap_family='cheese_snacks', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0079: hartig kaasbiscuit hoort in cheese_snacks'
where barcode in ('8710873997179','0799181903490','8710873998763','8718452922796');

update public.product_features set swap_family='baking_ingredients_non_swap', is_swap_relevant=false, classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0079: bakmix/afbak-cookiedough/bakchocolade is een ingredient, geen kant-en-klare snack'
where barcode in (
  '00678515','8718774040468','4015637824130','8718452885374','4335619317239',
  '8718907400701','8718452396696','8710479307105','8718907400763');

update public.product_features set swap_family='supplements_powders', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0079: whey-poeder met koeksmaak is een supplement (consistent met 0076)'
where barcode in ('8718774052379','8719214560867','8682696610187');

update public.product_features set swap_family='protein_bars', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0079: proteine-cookie/-bar/maaltijdreep is functionele sportvoeding (consistent met 0077)'
where barcode in (
  '5056555208106','8719881021760','3608390891580','5059883484488','4255719314337',
  '8719327489413','8720165350025');

update public.product_features set swap_family='breakfast_cereals', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0079: eiwit-oats is een ontbijtgraan (consistent met 0076)'
where barcode in ('8720986893800');

update public.product_features set swap_family='granola_muesli', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0079: losse granola hoort in granola_muesli'
where barcode in ('8721161523246');

update public.product_features set swap_family='honey_syrups', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0079: Monin koffiesiroop met koeksmaak is een siroop'
where barcode in ('0051770051365');

update public.product_features set swap_family='sweet_spreads_other', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0079: broodbeleg (spread, strooispeculaas, schuddebuikjes, kokosbrood) hoort in sweet_spreads_other'
where barcode in (
  '4068428058696','8710482532112','8710624409326','8710624221454','4056489547594');

update public.product_features set swap_family='candy_sweets', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0079: mochi/daifuku is een zoete rijstsnack (snoepgoed), geen koekje'
where barcode in ('8717624007699','8717624007668','4711931037091','4714221131219');

update public.product_features set swap_family=null, classification_status='review_required',
  classification_confidence=0.3, classified_at=now(), mapping_version=1,
  classification_reason='audit1_0079: producttype onduidelijk uit naam/merk (cannabis-item, spread-of-koek, onleesbare naam of ambigu reepproduct)'
where barcode in (
  '8594018432424','5410126016949','4065019030864','8717953200914','10027110',
  '87328677','8711812417352','8718907921282','8711812422141','8711812421113',
  '8719979203894');

-- R9: regelwortel-fix, volledige functie hieronder.
-- POSTFLIGHT: select count(*) from product_features where classification_reason like 'audit1_0079%'; -- 168
-- ROLLBACK: herstel via _snapshot_0079_before.

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
