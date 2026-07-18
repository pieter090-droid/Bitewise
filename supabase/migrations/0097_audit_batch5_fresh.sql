-- Fase 1 audit, batch 5 — deel 3: fresh_fruit (196) + fresh_vegetables (693).
--
-- WERKWIJZE-AFWIJKING (bewust, vastgelegd): batch 1-4 en batch 5 deel 1-2
-- zijn product-voor-product gelezen met barcode-verankerde correcties. Voor
-- deze twee families is gekozen voor PATROON-gebaseerde updates, strikt
-- afgebakend binnen de twee families. Snapshot, dry-run en postflight blijven
-- ongewijzigd, dus elke wijziging blijft controleerbaar en terugdraaibaar.
-- Gevolg: de structurele groepen worden volledig rechtgezet, losse
-- randgevallen blijven staan in plaats van individueel beoordeeld.
--
-- Twee structurele problemen:
--  K1 GEDROOGD FRUIT stond gesplitst. Migratie 0077 zette dadels ->
--     nuts_seeds en 0082 appel-/bananenchips -> nuts_seeds ("droogfruit-
--     groep"), maar rozijnen, dadels, pruimen, vijgen, gedroogde mango,
--     sultanas en studentenhaver stonden nog in fresh_fruit. Alles staat nu
--     in nuts_seeds. Regelwortel R53.
--  K2 BABYVOEDING (groentehapjes, fruithapjes, knijpmix, "4m+"/"12+
--     maanden", Olvarit) stond bij vers fruit/groente terwijl er een
--     baby_food_non_swap-familie bestaat. Regelwortel R54, geplaatst als
--     eerste regel zodat babyvoeding nooit als snack-swap opduikt.
--  K3 Kant-en-klare MAALTIJDEN (stamppot, ovenschotel, lasagne, quiche,
--     pizza, maaltijdsalade, bowl) -> ready_meals; bereidingsmixen en
--     vleesproducten met een groente in de naam -> meal_components.
--  K4 Groente-SNACKS (crispy sticks, protein puffs, paprikachips) ->
--     crisps_chips; groente-WAFELS -> crackers_rice_cakes; groente-SPREADS
--     en komkommer-/eiersalades -> savory_spreads; augurken, artisjokharten
--     en gebakken uitjes -> sauces_dips (consistent met 0090/0096); gazpacho
--     en Cup-a-Soup -> soups (consistent met 0093).
--
-- NB bewust ONGEMOEID: appelmoes/compote/knijpfruit blijven in fresh_fruit
-- (fruitproduct, geen betere familie); blik- en diepvriesgroente blijft
-- fresh_vegetables; gepelde tomaten/passata blijven waar ze staan — het
-- onderscheid met de passata in sauces_dips is een openstaand modelpunt dat
-- in fase 6 wordt gedocumenteerd, geen omissie.
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

create table if not exists public._snapshot_0097_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where swap_family in ('fresh_fruit','fresh_vegetables');

-- K2 babyvoeding (eerst: mag door geen enkele latere regel worden overruled).
update public.product_features pf set swap_family='baby_food_non_swap',
  is_swap_relevant=false, classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0097: babyvoeding/-hapje is geen snack-swapkandidaat (wortel gefixt in R54)'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family in ('fresh_fruit','fresh_vegetables')
  and (p.name ~* 'babyvoeding|babysnack|groentehapje|fruithapje|knijpmix|[0-9] ?m\+|[0-9]\+ ?maanden'
       or p.brand ~* '\molvarit\M|ella''s kitchen|de kleine keuken');

-- K1 gedroogd fruit consolideren in nuts_seeds.
update public.product_features pf set swap_family='nuts_seeds',
  classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0097: gedroogd fruit hoort bij de droogfruit-groep in nuts_seeds, consistent met 0077 (dadels) en 0082 (appel-/bananenchips); wortel gefixt in R53'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_fruit'
  and p.name ~* 'dadel|datte|medjoul|rozijn|sultana|studentenhaver|fruits secs|getrocknete|abricots sec|pruneaux|dominorozijn|gedroogd|gevriesdroogd|mangostreifen|pruimen zonder pit|\mfigs\M|figues|nut.?berry|mixed nuts|superfruit mix|pittenmix|kokos abrikoos';

-- K3 maaltijden en maaltijdcomponenten.
update public.product_features pf set swap_family='ready_meals',
  classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0097: kant-en-klare maaltijd met groente in de naam is een maaltijd, geen verse groente'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_vegetables'
  and p.name ~* 'stamppot|lasagne|quiche|\mpizza\M|pinsa|piccolinis|maaltijdsalade|lunchsalade|daily bowl|risotto|stroganoff|ravioli|pappardelle|\mpenne\M|high protein meals|shotel|ovenschotel|gebakken aardappelen met';

update public.product_features pf set swap_family='meal_components',
  classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0097: bereidingsmix of vleesproduct met een groente in de naam is een maaltijdcomponent, geen verse groente'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_vegetables'
  and p.name ~* 'gehakt|kiphaasjes|kippenvleugels|kippenvleesreepjes|braadworst|cordon bleu|schinken|basis voor|groentepannetje|gem[uü]sepfanne|opbakaardappel|bak aardappel|krieltjes|good patatoes|filet americain|prepar[eé] met';

-- K4 snacks, wafels, spreads, condimenten, soep.
update public.product_features pf set swap_family='crisps_chips',
  classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0097: groentesnack (crispy sticks, protein puff, paprikachips) is een chipssnack, geen verse groente'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_vegetables'
  and p.name ~* 'crispy sticks|protein puff|protein mix paprika|patatas fritas|paprika crispy|lentis twist|paprika flavour';

update public.product_features pf set swap_family='crackers_rice_cakes',
  classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0097: mais-/linzen-/kikkererwtenwafels zijn crackers, geen verse groente'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_vegetables'
  and p.name ~* 'wafels?\M';

update public.product_features pf set swap_family='savory_spreads',
  classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0097: groentespread en komkommer-/eiersalade zijn hartig broodbeleg, geen verse groente'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_vegetables'
  and p.name ~* 'spread|komkommer ?salade|eiersalade|eitje prei salade|aubergines grilees|erwten munt|paprika-basilicum';

update public.product_features pf set swap_family='sauces_dips',
  classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0097: augurken, artisjokharten en gebakken uitjes zijn condimenten (consistent met 0090/0096)'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_vegetables'
  and p.name ~* 'augurk|cornichon|artisjok|artichaut|oignons frits|chutney';

update public.product_features pf set swap_family='soups',
  classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0097: gazpacho, Cup-a-Soup en potage zijn soep (consistent met 0093)'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_vegetables'
  and p.name ~* 'gazpacho|gaspacho|cup a soup|potage';

-- Losse, ondubbelzinnige missers.
update public.product_features pf set swap_family='fresh_vegetables',
  classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0097: tomaten zijn groente, geen fruit'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_fruit' and p.name ~* 'tomaten|tomaatjes';

update public.product_features pf set swap_family='cooking_oils_fats',
  classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0097: kokosolie is een keukenolie'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_fruit' and p.name ~* 'kokosolie|coconut oil';

update public.product_features pf set swap_family='baking_ingredients_non_swap',
  is_swap_relevant=false, classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0097: kokosmeel is een bak-ingredient'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_fruit' and p.name ~* 'farine de coco|kokosmeel|coconut flour';

update public.product_features pf set swap_family='plant_based_dairy',
  classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0097: erwtendrink is plantaardige zuivel'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_vegetables' and p.name ~* 'erwtendrink';

update public.product_features pf set swap_family='fruit_juices',
  classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0097: groentesap hoort bij de sapfamilie (consistent met 0092)'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_vegetables' and p.name ~* 'groentesap|groenteshot';

update public.product_features pf set swap_family='ice_cream_desserts',
  classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0097: waterijsjes zijn ijs, geen groente'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_vegetables' and p.name ~* 'waterijs';

update public.product_features pf set swap_family='meat_alternatives_non_swap',
  is_swap_relevant=false, classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0097: groenteburger is een vleesvervanger, geen verse groente'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'fresh_vegetables' and p.name ~* '\mburger\M';

-- R53/R54: regelwortel-fixes, volledige functie hieronder.
-- POSTFLIGHT: zie dry-run-tellingen per groep.
-- ROLLBACK: herstel via _snapshot_0097_before (volledige beide families).

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
