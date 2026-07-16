-- Fase 1 audit, batch 1 (zoet) — deel 2: handmatige leesronde van de kleine
-- zoete families: chocolate_bars (67), chocolate_spreads (55),
-- sweet_spreads_other (69), honey_syrups (95), jams_fruit_spreads (104).
-- Elk product individueel gelezen; correcties barcode-verankerd.
--
-- Hoofdbevindingen:
--  T1 Chocoladetablet-consistentie: chocolate_bars is in dit model de
--     candy-bar-familie (Mars/Snickers/Twix/Bueno; runtime-regel matcht
--     'chocoladereep|candy bar' en het merk-vangnet). Pure tablets zonder
--     "reep" in de naam classificeert de runtime via p2~chocolate als
--     chocolate_confectionery. 31 tablets (Lindt Excellence, Tony's, Milka
--     tablet, Vivani, Ritter, Alter Eco, ...) verhuizen daarheen zodat de
--     familie-indeling overeenkomt met wat de regel voor nieuwe scans doet.
--  T2 Chocolade-koekjes zaten in chocolate_bars (Filet Bleu petit beurre,
--     Filipinos, Sondey Schokobutterkeks, Jumbo chocolade biscuits).
--  T3 R3-restanten in honey_syrups: honing-gearomatiseerde niet-siropen
--     (gerookte zalm "Honey Roast", geitenkaas honing, honing-BBQ-noten,
--     pretzels, kant-en-klare maaltijd, mosterd) en blikfruit "op siroop"
--     (7x) -> fresh_fruit. Regel-exclusie verder aangescherpt.
--  T4 De Ruijter hagel/vlokken-restanten in chocolate_spreads en
--     chocopasta's in sweet_spreads_other over-en-weer rechtgezet.
--  T5 Hartige jams (chilijam, vijgenchutney) -> sauces_dips.
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

-- Stap 1: snapshot.
create table if not exists public._snapshot_0075_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  '3046920010047','3700214618578','3700214619391','4056489719588','3477730007079',
  '20815356','4044889000610','4044889000733','4044889002119','4044889001013',
  '3046920022606','3046920028363','3046920028370','3046920029759','3046920010856',
  '3046920022095','4000417119704','40896243','8034055710777','3395328120910',
  '8718754740524','8710871400787','7622202273476','7622202370564','5410081206201',
  '8720701148765','8719956493638','8717677336036','8717677335565','8710400066958',
  '4056489762720',
  '3556940811789','3556940811673','8436048965513','8718452352098','20026554',
  '5712840020067','8000500416938','4044889002225','7771711000841',
  '8710496978951','17104968','8710496977817','8718906823778',
  '8718452449897','8710573742819','20266929',
  '00437622','5949040205158','8718989045661','8718452967704','5400141627336',
  '6150829595561','8710398534903','8721082847117','8715551423131','3302950003504',
  '8714700999916','8718906962620','8718265773349','8710400006961','8718989958367',
  '8718989000974','8710871403405','8718452650071','8710400013648','8721077490243',
  '8720195573524','20310073','4250519679815',
  '5065019406262','8718907466875'
);

-- Stap 2: R3-exclusie in compute_swap_family() verder aanscherpen. Alleen de
-- honing/siroop-tak wijzigt t.o.v. 0074; volledige herdefinitie voor
-- consistentie is niet nodig -- we vervangen de functie integraal met exact
-- de 0074-versie waarin uitsluitend de honey-exclusie is uitgebreid.
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

-- Stap 3: correcties.

-- T1: 31 pure chocoladetablets -> chocolate_confectionery.
update public.product_features set swap_family='chocolate_confectionery', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: chocoladetablet zonder reep-naam -> chocolate_confectionery (consistent met runtime-regel; chocolate_bars = candy bars)'
where barcode in (
  '3046920010047','3700214618578','3700214619391','4056489719588','3477730007079',
  '20815356','4044889000610','4044889000733','4044889002119','4044889001013',
  '3046920022606','3046920028363','3046920028370','3046920029759','3046920010856',
  '3046920022095','4000417119704','40896243','8034055710777','3395328120910',
  '8718754740524','8710871400787','7622202273476','7622202370564','5410081206201',
  '8720701148765','8719956493638','8717677336036','8717677335565','8710400066958',
  '4056489762720');

-- T2: chocolade-koekjes -> cookies_biscuits.
update public.product_features set swap_family='cookies_biscuits', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: chocolade-biscuit (petit beurre/Filipinos/butterkeks) is koek, geen chocoladereep'
where barcode in ('3556940811789','3556940811673','8436048965513','8718452352098','20026554');

update public.product_features set swap_family='cereal_bars', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: RAW BITE is een fruit-notenreep, geen chocoladereep'
where barcode in ('5712840020067');

update public.product_features set swap_family='protein_bars', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: Eat Natural protein fruit & nut bar is een eiwitreep'
where barcode in ('8000500416938');

update public.product_features set swap_family='baking_ingredients_non_swap', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: couverture (Vivani Kuvertüre) is bakchocolade, geen snack'
where barcode in ('4044889002225');

update public.product_features set swap_family=null, classification_status='review_required',
  classification_confidence=0.3, classified_at=now(), mapping_version=1,
  classification_reason='audit1_0075: rauwe/gebrande cacaobonen -- geen passende familie (snack of ingrediënt onduidelijk)'
where barcode in ('7771711000841');

-- T4: hagel/vlokken uit chocolate_spreads + karamelpasta -> sweet_spreads_other.
update public.product_features set swap_family='sweet_spreads_other', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: De Ruijter hagel/vlokken-producten en karamelpasta zijn broodbeleg-strooisel/zoete spread, geen chocoladepasta'
where barcode in ('8710496978951','17104968','8710496977817','8718906823778');

-- T4 omgekeerd: chocopasta''s in sweet_spreads_other -> chocolate_spreads.
update public.product_features set swap_family='chocolate_spreads', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: duo-/witte chocopasta hoort bij chocolate_spreads (consistent met alle andere chocopasta''s)'
where barcode in ('8718452449897','8710573742819','20266929');

-- T3: honing-gearomatiseerde niet-siropen uit honey_syrups.
update public.product_features set swap_family='fish_seafood', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: honey roast gerookte zalm is vis, geen siroop (R3)'
where barcode in ('00437622');

update public.product_features set swap_family='crackers_rice_cakes', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: pretzels met honing-zeezout zijn zoutjes, geen siroop (R3)'
where barcode in ('5949040205158');

update public.product_features set swap_family='cheese_snacks', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: geitenkaas met honing is kaas, geen siroop (R3)'
where barcode in ('8718989045661','8718452967704');

update public.product_features set swap_family='breakfast_cereals', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0075: Honey Bubbles is ontbijtgranen, geen siroop (R3)'
where barcode in ('5400141627336');

update public.product_features set swap_family='ready_meals', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: Fuel Your Body honey herb chicken is een kant-en-klare maaltijd (R3)'
where barcode in ('6150829595561');

update public.product_features set swap_family='nuts_seeds', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: honing-BBQ-borrelnoten/cashews zijn noten, geen siroop (R3)'
where barcode in ('8710398534903','8721082847117');

update public.product_features set swap_family='sauces_dips', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: honing-mosterd(saus) is een saus, geen siroop (R3)'
where barcode in ('8715551423131','3302950003504');

update public.product_features set swap_family='grain_starch_ingredients', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: Honig lasagne is rauwe pasta (merknaam Honig matchte de honing-regel)'
where barcode in ('8714700999916');

update public.product_features set swap_family='supplements_powders', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: multivitaminesiroop is een supplement, geen voedingssiroop'
where barcode in ('8718906962620');

update public.product_features set swap_family='fresh_fruit', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0075: blikfruit op (lichte) siroop is fruit, geen siroop -- consistent met perziken-precedent uit batch 5 (R3)'
where barcode in ('8718265773349','8710400006961','8718989958367','8718989000974','8710871403405','8718452650071','8710400013648');

update public.product_features set swap_family='candy_sweets', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0075: Anta menthol-honing-citroen zijn keelpastilles/snoep (consistent met eerder Anta-besluit)'
where barcode in ('8721077490243');

update public.product_features set swap_family=null, classification_status='review_required',
  classification_confidence=0.3, classified_at=now(), mapping_version=1,
  classification_reason='audit1_0075: bereidingsstatus/producttype onduidelijk (kipvleugels diepvries; naam "Dessert" zonder context; ESN Honey Cereal onduidelijk producttype)'
where barcode in ('8720195573524','20310073','4250519679815');

-- T5: hartige jams -> sauces_dips.
update public.product_features set swap_family='sauces_dips', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0075: chilijam/vijgenchutney is een hartige saus/condiment, geen broodjam'
where barcode in ('5065019406262','8718907466875');

-- POSTFLIGHT (read-only):
-- select count(*) from product_features where classification_reason like 'audit1_0075%'; -- 70
-- select count(*) from product_features_resolved; -- gelijk aan products
-- select count(*) from product_features where swap_family is not null and classification_status is null; -- 0

-- ROLLBACK: herstel via _snapshot_0075_before (patroon 0070-0074) en zet
-- compute_swap_family() terug naar de 0074-definitie.
