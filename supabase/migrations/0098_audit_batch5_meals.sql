-- 0098 — Legacy-audit fase 1, batch 5 deel 4 (LAATSTE deel van fase 1):
-- meal_components (570) + ready_meals (103) + cooking_oils_fats (101).
--
-- WERKWIJZE: net als 0097 patroon-gebaseerd (regex-groepen over de
-- familiedump) in plaats van product-voor-product; op verzoek van de
-- gebruiker versneld. Snapshot + dry-run + postflight en "twijfel =
-- review_required" gelden onverkort.
--
-- STRUCTURELE BEVINDING: de catch-all `p1 = composite or naam ~ maaltijd|
-- salade|meal` sleepte alles wat "salade" heet naar meal_components. In het
-- Nederlands is een "salade" in een kuipje (eiersalade, tonijnsalade,
-- huzarensalade, filet americain) echter smeerbaar BROODBELEG. Wie
-- eiersalade scande kreeg lasagne en nasi als swap. R55 splitst dit.
-- Daarnaast bleven kant-en-klare composiet-gerechten (lasagne, nasi, bami,
-- ravioli, quiche, gratin) bij meal_components hangen omdat de ready_meals-
-- regel alleen 'kant-en-klaar' en 'pizza' kende (R56). Maaltijdvervangende
-- repen/shakes vielen via '\mmeal\M' ook in meal_components (R57).
--
-- ROLLBACK: herstel via _snapshot_0098_before.

create table if not exists public._snapshot_0098_before as
select pf.*
from public.product_features pf
where pf.swap_family in ('meal_components', 'ready_meals', 'cooking_oils_fats');

-- ---------------------------------------------------------------------
-- A. cooking_oils_fats — uitschieters die via "in ... olie" binnenkwamen
-- ---------------------------------------------------------------------

-- A1. Vis in olie is een visconserve, geen bakolie (spiegelt R42/R45).
update public.product_features pf
set swap_family = 'fish_seafood',
    classification_reason = 'audit1_0098: visconserve in olie, geen bakolie'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'cooking_oils_fats'
  and p.name ~* 'sardine|\mtuna\M|tonijn|\mthon\M|\mtune\M';

-- A2. Chinese paddenstoelen in chili-olie is een condiment.
update public.product_features pf
set swap_family = 'sauces_dips',
    classification_reason = 'audit1_0098: condiment/topping, geen bakolie'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'cooking_oils_fats'
  and p.name ~* 'mushrooms in chili oil';

-- A3. Holie's Crunchy bars zijn granenrepen (naam bevat 'olie' in 'Holie').
update public.product_features pf
set swap_family = 'cereal_bars',
    classification_reason = 'audit1_0098: granenreep, merknaam bevat -olie-'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'cooking_oils_fats'
  and p.name ~* 'crunchy bar';

-- A4. Oliebollenmix is een bakmix.
update public.product_features pf
set swap_family = 'baking_ingredients_non_swap',
    is_swap_relevant = false,
    classification_reason = 'audit1_0098: bakmix, geen olie'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'cooking_oils_fats'
  and p.name ~* 'oliebollen';

-- A5. Visolie/omega-capsules zijn supplementen.
update public.product_features pf
set swap_family = 'supplements_powders',
    classification_reason = 'audit1_0098: visolie-supplement, geen bakolie'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'cooking_oils_fats'
  and p.name ~* 'fish oil|artic oil|arctic oil|omega.?3';

-- A6. Smeerbare producten "met olijfolie"/"zonder palmolie" zijn margarine.
update public.product_features pf
set swap_family = 'butter_margarine',
    classification_reason = 'audit1_0098: smeerbaar vet, geen vloeibare olie'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'cooking_oils_fats'
  and p.name ~* 'smeerbaar|\msmeren\M|opgroeien zonder palmolie';

-- ---------------------------------------------------------------------
-- B. meal_components — broodsalades naar savory_spreads (R55)
-- ---------------------------------------------------------------------

update public.product_features pf
set swap_family = 'savory_spreads',
    classification_reason = 'audit1_0098: NL kuipsalade = smeerbaar broodbeleg'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'meal_components'
  and (p.name ~* '(ei|eier|eieren|tonijn|zalm|krab|surimi|huzaren|rundvlees|beenham|kerrie|selderij|selderie|sellerie|vis|garnalen|truffel|noordzee)[- ]?salade'
       or p.name ~* 'filet americain|\mamericain\M|russisch ei|russish ei|gevulde? eit?jes? salade|saladespecialiteit|vissaladeschotel|eiersalade|tonijnsalade|zalmsalade|rundvleessalade|huzarensalade|kipsalade|surimi salade')
  and p.name !~* 'maaltijdsalade|salade ?bowl|verspakket|dressing|\msaus\M|maaltijd';

-- ---------------------------------------------------------------------
-- C. meal_components — kant-en-klare gerechten naar ready_meals (R56)
-- ---------------------------------------------------------------------

update public.product_features pf
set swap_family = 'ready_meals',
    classification_reason = 'audit1_0098: kant-en-klaar composiet-gerecht'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'meal_components'
  and (p.name ~* '\mpizza\M|pizzetta|piccolinis|flammekueche|stromboli'
       or p.name ~* 'lasagne|lasagna|nasi goreng|bami goreng|stoommaaltijd|maaltijdsalade|burrito|quiche|gratin|ovenpasta|mac ?.n.? ?cheese|macaroni ?& ?cheese|paella|tagliatelle|ravioli|tortellini|risotto|jambalaya|goulash|gulaschtopf|pokebowl|poke ?bowl|tteokbokki|onigiri|maaltijdloempia|verse maaltijd|vriesverse maaltijd|comfort bowl|lunch bowl|chickenbowl|pastabowl|hongaarse|rendang|babi pangang|kipschotel|bonenschotel|groenteschotel|koude schotel|curry madras|korma curry|teriyaki noodles|smokey cajun')
  and p.name !~* 'verspakket|roerbakmix|maaltijdmix|kruidenmix|pizzadeeg|pizzabodem|pizzasaus|\mmeel\M|pakket|basis voor';

-- ---------------------------------------------------------------------
-- D. meal_components — overige families
-- ---------------------------------------------------------------------

-- D1. Soepen en bouillons.
update public.product_features pf
set swap_family = 'soups',
    classification_reason = 'audit1_0098: soep/bouillon'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'meal_components'
  and p.name ~* '\msoupe\M|\mpotage\M|\msoep\M|tom kha kai|bone broth|bouillon|\mzurek\M|harira|miso'
  and p.name !~* 'soepballetjes|soep balletjes|soepballen';

-- D2. Maaltijdvervangers (R57).
update public.product_features pf
set swap_family = 'supplements_powders',
    classification_reason = 'audit1_0098: maaltijdvervanger, geen maaltijd'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'meal_components'
  and p.name ~* 'meal ?replacement|drinkmaaltijd|maaltijdshake|meal ?bar|\mmodifast\M|repas [aà] boire|smaak diet';

-- D3. Babyvoeding (R54-precedent).
update public.product_features pf
set swap_family = 'baby_food_non_swap',
    is_swap_relevant = false,
    classification_reason = 'audit1_0098: babyvoeding'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'meal_components'
  and (p.name ~* '\molvarit\M|maaltijdhapje|maaltijd hapje|\d+ ?m\+|\d+\+ ?maanden'
       or p.brand ~* '\molvarit\M');

-- D4. Verse groenten, kruiden en salademixen zonder beleg.
update public.product_features pf
set swap_family = 'fresh_vegetables',
    classification_reason = 'audit1_0098: verse/bewerkte groente, geen maaltijd'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'meal_components'
  and p.name ~* 'peterselie|ijsbergsla|wokgroenten|gehakte spinazie|spinazie, fijn gehakt|rauwkost|\mkimchi\M|champignons .{0,3}la grecque|zeewiersalade|coleslaw|macédoine de légumes|mac.doine de l.gumes';

-- D5. Vers fruit.
update public.product_features pf
set swap_family = 'fresh_fruit',
    classification_reason = 'audit1_0098: vers fruit'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'meal_components'
  and p.name ~* 'fruitsalade|golden banana|\mmarrons\M';

-- D6. Tortilla-wraps zijn bakkerijproduct (R51b-precedent).
update public.product_features pf
set swap_family = 'bread_bakery',
    classification_reason = 'audit1_0098: bakkerijproduct (R51b-precedent)'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'meal_components'
  and p.name ~* 'tortilla wraps|tortilla sans|oven bread|pastry swirl|pizzabodem|pizzadeeg';

-- D7. Nacho's zijn chips.
update public.product_features pf
set swap_family = 'crisps_chips',
    classification_reason = 'audit1_0098: tortillachips'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'meal_components'
  and p.name ~* 'nacho.?s';

-- D8. Twijfelgevallen expliciet naar review (nooit gokken).
update public.product_features pf
set classification_status = 'review_required',
    classification_reason = 'audit1_0098: naam te vaag voor familiebepaling, review'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'meal_components'
  and p.name ~* '^(Chocolate|Philip|Kip|Rundvlees|Mount Fuji|Snackbox|Borenmix|Natur campagne|Golden banana|Spiral Lollies)$';

-- ---------------------------------------------------------------------
-- E. Regelwortels R55/R56/R57 in compute_swap_family()
-- ---------------------------------------------------------------------

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

  -- R54 (0097): babyvoeding/-hapjes en leeftijdsaanduidingen (4m+, 12+
  -- maanden) zijn geen snack-swapkandidaat.
  if n ~* 'babyvoeding|babysnack|groentehapje|fruithapje|knijpmix|\d+ ?m\+|\d+\+ ?maanden|babykeks|baby ?biscuit' or b ~* '\molvarit\M' then
    return 'baby_food_non_swap';
  -- R55 (0098): NL 'salade' in een kuipje (eiersalade, tonijnsalade,
  -- huzarensalade, kip-kerriesalade, filet americain) is smeerbaar
  -- broodbeleg, geen maaltijd. Maaltijdsalades/salade bowls uitgezonderd.
  elsif (n ~* '(ei|eier|eieren|tonijn|zalm|krab|surimi|huzaren|rundvlees|beenham|kerrie|selderij|selderie|sellerie|vis|garnalen|truffel|noordzee)[- ]?salade'
         or n ~* 'filet americain|\mamericain\M|russisch ei|gevulde? eit?jes? salade|saladespecialiteit|vissaladeschotel')
        and n !~* 'maaltijdsalade|salade ?bowl|verspakket|dressing|\msaus\M|maaltijd' then
    return 'savory_spreads';
  elsif n ~* 'smeerkaas|cream cheese spread|roomkaas smeerbaar|streich\M|bruschetta spread' then
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
  elsif (p2 ~* '\mnuts\M' or n ~* 'noten|zaden|amandelen|cashew|walnoot|hazelnoot|pistache|pinda|peanut|pecan|macadamia|pitten|pijnboompit|zonnebloempit|pompoenpit|dadel|datte|medjoul|rozijn|krenten\M|sultana|studentenhaver|fruits secs|getrocknete|gedroogde? (vijg|abrikoos|mango|appel|pruim|dadel)|pruimen zonder pit|abricots sec|pruneaux')
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

  -- R56 (0098): kant-en-klare composiet-gerechten horen bij ready_meals;
  -- verspakketten/roerbakmixen/maaltijdmixen blijven meal_components.
  elsif (n ~* 'kant.?en.?klaar|magnetronmaaltijd|ovenschotel|maaltijdbox'
         or n ~* 'lasagne|lasagna|nasi goreng|bami goreng|stoommaaltijd|maaltijdsalade|burrito|quiche|gratin|ovenpasta|mac ?.n.? ?cheese|macaroni ?& ?cheese|paella|tagliatelle|ravioli|tortellini|risotto|jambalaya|goulash|pokebowl|poke ?bowl|tteokbokki|onigiri|maaltijdloempia'
         or (n ~* '\mpizza\M|pizzetta|piccolinis|flammekueche|stromboli'
             and n !~* 'pizzasaus|pizza.?saus|pizzakruiden|pizza.?kruiden|pizzadeeg|pizza.?deeg|pizzabodem|pizza.?bodem|pizzameel|pizza.?meel|\mmeel\M|farina|dippers|m[ée]lange'))
        and n !~* 'verspakket|roerbakmix|maaltijdmix|kruidenmix|\mmeel\M|pakket|basis voor' then
    return 'ready_meals';
  -- R57 (0098): maaltijdvervangers (meal replacement bar/shake,
  -- drinkmaaltijd, Modifast) zijn dieetsupplementen.
  elsif n ~* 'meal ?replacement|drinkmaaltijd|maaltijdshake|maaltijdvervang|meal ?bar|\mmodifast\M|repas [aà] boire' then
    return 'supplements_powders';
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
