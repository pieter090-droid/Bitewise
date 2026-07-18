-- Fase 1 audit, batch 4 (dranken/overig) — deel 4 (slot): leesronde
-- sauces_dips (678) + mayonnaise_sauces (62). Elk product individueel
-- gelezen. Daarmee is batch 4 compleet.
--
-- sauces_dips is bewust een brede condimentenfamilie (ketchup, mosterd,
-- pesto, pastasaus, sojasaus, sambal, azijn, dressings, dips, olijven) en is
-- in die opzet coherent. De vervuiling bestaat uit producten die het woord
-- "saus" in de naam dragen maar een heel ander product zijn:
--  K1 30 -> meal_components: 11 blikken bonen "in tomatensaus" (witte bonen,
--     kidneybonen, haricots blancs), balletjes/kip/worst in saus, rendang,
--     sajoer, verse pasta-met-saus-pakketten, pizzadeeg+saus, verspakketten.
--  K2 8 -> ready_meals: kant-en-klare schotels en maaltijdsalades met
--     dressing (pulled pork, tagliatelle zalm, gyoza met dip, butter
--     chicken).
--  K3 7 -> fish_seafood: sardines/makreel/tonijn in olijfolie of
--     tomatensaus.
--  K4 5 -> cooking_oils_fats: extra vierge olijfolie ("huile d'olive"
--     ontsnapte aan de bestaande 'olive oil'-exclusie).
--  K5 16 -> savory_spreads: Duitse "Streich"-spreads, bruschetta-spread,
--     muhammara, aubergine-/tzatzikisalade, Heks'nkaas vegan, roomkaas,
--     pestospread, tofu-spread; 4 Maza "hoemoes" -> hummus_legume_spreads
--     (Nederlandse spelling ontbrak in de regel).
--  K6 21 mayonaises die in sauces_dips stonden (Heinz, Hellmann's, Jean
--     Bâton, Mayolijn, Yogonaise, Halvanaise) -> mayonnaise_sauces, zodat de
--     mayo-familie compleet is. Regelwortel R41.
--  K7 losse missers: grissini -> crackers, olijvenbrood + sausage roll ->
--     bread_bakery, chocosaus + vanille-dessertsaus -> honey_syrups,
--     beenham met mosterdsaus -> cold_cuts, Lay's "Patatje Mayo" (chips uit
--     mayonnaise_sauces) -> crisps_chips, 2 review_required (Wilde Wietze
--     Dip, onleesbare naam).
--
-- Regelwortels: R41 (mayonaise -> mayonnaise_sauces), R42 (sauzenregel sluit
-- 'bonen in', vis, worst, maaltijd, verspakket, grissini en huile d'olive
-- uit), R43 (hoemoes in de hummusregel), R44 (Streich/bruschetta spread in
-- savory_spreads).
--
-- NB azijn, tomatenpuree/passata en olijven blijven bewust in sauces_dips:
-- het zijn condimenten en er is geen betere familie. Dat is een bewuste
-- modelkeuze, geen omissie.
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

create table if not exists public._snapshot_0094_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  '8710400238119','8712423020436','20302313','3083680010726','8719587085196',
  '8710624869533','8719587096338','8720600609008','8718452369263','8710400028598',
  '8710400005117','8710400402978','8720326114718','8718907492522','8718907976411',
  '8710296936601','4065019176722','8718452905706','8711200403455','8711200403271',
  '8710861986246','8718907085175','20362454','4335619024090','8053904630592',
  '3431590001738','20969233','5411396034374','8715700415987','8720182461551',
  '8713834128506','8718452908721','8718906432840','8718265469440','8719587054116',
  '00885584','8901047610578','8717948002455',
  '3263670237917','3263670015157','0455353063682','3263670114614','3263670041255',
  '5034210521869','8004030022010',
  '8058180791128','4056489141877','4056489269243','4056489095897','5203286121079',
  '4016249149406','4068264022226','4068706117701','4019736002598','4019736003557',
  '4016249149413','4000915108323','8718719174722','8718719175422','4718900725270',
  '8718907623056','8714685902024','8714685902123','4012359114303','8714779001862',
  '8718906724488',
  '8714779007857','8714779009967','8714779006492','8714779000704',
  '8715700117829','8722700102632','8712100592744','8718403012415','8710448697589',
  '8710448636946','8710604778732','8715700209128','8715700112930','8718403012354',
  '8715700115351','8711200384440','87221503','8710604778725','8720182323835',
  '8720791223595','8718452659296','8718907684989','4056489792130','8718452659371',
  '8717202408894','5070000210643','2272486002153','8718452794379','20184926',
  '2398948216217','8710398536471','1095019014703','8718907981187'
);

update public.product_features set swap_family='meal_components', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0094: ingeblikte bonen/vlees "in tomatensaus" en verse pasta-/verspakketten zijn maaltijdcomponenten, geen saus (wortel gefixt in R42)'
where barcode in (
  '8710400238119','8712423020436','20302313','3083680010726','8719587085196',
  '8710624869533','8719587096338','8720600609008','8718452369263','8710400028598',
  '8710400005117','8710400402978','8720326114718','8718907492522','8718907976411',
  '8710296936601','4065019176722','8718452905706','8711200403455','8711200403271',
  '8710861986246','8718907085175','20362454','4335619024090','8053904630592',
  '3431590001738','20969233','5411396034374','8715700415987','8720182461551');

update public.product_features set swap_family='ready_meals', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0094: kant-en-klare schotel of maaltijdsalade met dressing is een maaltijd, geen saus (wortel gefixt in R42)'
where barcode in (
  '8713834128506','8718452908721','8718906432840','8718265469440','8719587054116',
  '00885584','8901047610578','8717948002455');

update public.product_features set swap_family='fish_seafood', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0094: sardines/makreel/tonijn in olie of tomatensaus is ingeblikte vis (wortel gefixt in R42)'
where barcode in (
  '3263670237917','3263670015157','0455353063682','3263670114614','3263670041255',
  '5034210521869','8004030022010');

update public.product_features set swap_family='cooking_oils_fats', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0094: extra vierge olijfolie is een keukenolie ("huile d''olive" ontbrak in de olie-exclusie; wortel gefixt in R42)'
where barcode in (
  '8058180791128','4056489141877','4056489269243','4056489095897','5203286121079');

update public.product_features set swap_family='savory_spreads', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0094: hartige smeerspread (Streich, bruschetta, muhammara, aubergine-/tzatzikisalade, Heks''nkaas, pestospread) is broodbeleg, geen saus (wortel gefixt in R44)'
where barcode in (
  '4016249149406','4068264022226','4068706117701','4019736002598','4019736003557',
  '4016249149413','4000915108323','8718719174722','8718719175422','4718900725270',
  '8718907623056','8714685902024','8714685902123','4012359114303','8714779001862',
  '8718906724488');

update public.product_features set swap_family='hummus_legume_spreads', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0094: "hoemoes" is de Nederlandse spelling van hummus (wortel gefixt in R43)'
where barcode in ('8714779007857','8714779009967','8714779006492','8714779000704');

update public.product_features set swap_family='mayonnaise_sauces', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0094: mayonaise/yogonaise/halvanaise/mayolijn hoort in de mayonaisefamilie (wortel gefixt in R41)'
where barcode in (
  '8715700117829','8722700102632','8712100592744','8718403012415','8710448697589',
  '8710448636946','8710604778732','8715700209128','8715700112930','8718403012354',
  '8715700115351','8711200384440','87221503','8710604778725','8720182323835',
  '8720791223595','8718452659296','8718907684989','4056489792130','8718452659371');

update public.product_features set swap_family='crackers_rice_cakes', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0094: grissini zijn broodstengels, geen saus (wortel gefixt in R42)'
where barcode in ('8717202408894');

update public.product_features set swap_family='bread_bakery', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0094: olijvenbrood en sausage roll zijn bakkerijproducten, geen saus (wortel gefixt in R42)'
where barcode in ('5070000210643','2272486002153');

update public.product_features set swap_family='honey_syrups', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0094: chocolade-/vanilledessertsaus is een zoete topping, geen hartige saus'
where barcode in ('8718452794379','20184926');

update public.product_features set swap_family='cold_cuts', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0094: gegaarde beenham met mosterdsaus is vleeswaren, geen saus'
where barcode in ('2398948216217');

update public.product_features set swap_family='crisps_chips', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0094: Lay''s "Patatje Mayo" is chips, geen mayonaise'
where barcode in ('8710398536471');

update public.product_features set swap_family=null, classification_status='review_required',
  classification_confidence=0.3, classified_at=now(), mapping_version=1,
  classification_reason='audit1_0094: producttype onduidelijk (Wilde Wietze Dip; onleesbare productnaam)'
where barcode in ('1095019014703','8718907981187');

-- R41-R46: regelwortel-fixes, volledige functie hieronder.
-- POSTFLIGHT: select count(*) from product_features where classification_reason like 'audit1_0094%'; -- 99
-- ROLLBACK: herstel via _snapshot_0094_before.

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
  elsif p2 ~* 'biscuits|cookies' or n ~* '\mkoek|koek\M|cookie|jan hagel|sprits|kletsmajoor|picolient|speculaas|\mkrans|biscuit|stroop ?wafel|stroopkoek|luikse wafel|suikerwafel|eierwafel|\mgaufre|kruidnoten|pepernoten|krakeling|d[uú]mkes|koffie ?wafel|caf[eé] noir' then
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
