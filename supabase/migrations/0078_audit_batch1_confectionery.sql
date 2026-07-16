-- Fase 1 audit, batch 1 (zoet) — deel 5: leesronde chocolate_confectionery
-- (414). Elk product individueel gelezen.
--
-- Hoofdbevindingen:
--  K1 45 drop/salmiak/lakrits/pastille-producten (Venco, Klene, Panda,
--     Bülow, Anis de Flavigny, ...) zaten hier via het oude liquorice-
--     categorielek (regel al gefixt in 0074/R2; dit zijn de legacy-rijen).
--     -> candy_sweets. Hieronder ook de "Suikervrij muntendrop" die als
--     Chokotoff-swap in de app verscheen: functioneel prima suggestie,
--     maar hoort formeel in candy_sweets.
--  K2 20 hagelslag/vlokken-producten (De Ruijter, Venz, Jumbo, AH) ->
--     sweet_spreads_other (R1-legacy).
--  K3 Diversen: chocolate drink -> dairy_drinks; rice drink ->
--     plant_based_dairy; witte couverture -> baking; cacao nibs en
--     cannabis-chocolade -> review_required; praline-croissant ->
--     bread_bakery (croissant-regel); KitKat matcha -> chocolate_bars
--     (merk-regel); turron -> candy (precedent 0059).
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

create table if not exists public._snapshot_0078_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  '8713576162042','8714200216445','4001686216019','8714200217022','8714200214618',
  '8714200218234','8714200220077','8718906340558','8714200207931','8714200219644',
  '8714200218159','5710858001276','7037710037883','5711812913024','5711812913031',
  '8713600099047','5711812912973','5711812912980','8723400798897','0075172079123',
  '0075172079734','0075172078966','5710858000781','5711812913079','8713800257766',
  '8714200220060','8710452212518','4056489154549','8718907382656','7718922382656',
  '5711812913093','87138108','8719700460688','8723400777540','8713800255427',
  '8714200213147','4001686343050','8719700009337','9002859066047','8716257552507',
  '3360101900102','3360101220101','3360100380103','8710998504665','8433329093446',
  '8710496977671','8715700119441','8710496977626','8710496978975','8710496977695',
  '8715700119403','8710496035036','8718452611447','8718452611775','8710391937350',
  '8710391936421','8718906839434','8718906839397','8715700127927','8710496976766',
  '8715700119465','8718265809970','8718452147755','8718452359608','8710391937411',
  '7622210313218','8713965500158','4044889002232','8718452550678','7107719207959',
  '2289118001903','42370437'
);

update public.product_features set swap_family='candy_sweets', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0078: drop/salmiak/lakrits/pastille/babbelaar/turron is snoep, geen bonbon (legacy liquorice-lek, regel gefixt in 0074/R2)'
where barcode in (
  '8713576162042','8714200216445','4001686216019','8714200217022','8714200214618',
  '8714200218234','8714200220077','8718906340558','8714200207931','8714200219644',
  '8714200218159','5710858001276','7037710037883','5711812913024','5711812913031',
  '8713600099047','5711812912973','5711812912980','8723400798897','0075172079123',
  '0075172079734','0075172078966','5710858000781','5711812913079','8713800257766',
  '8714200220060','8710452212518','4056489154549','8718907382656','7718922382656',
  '5711812913093','87138108','8719700460688','8723400777540','8713800255427',
  '8714200213147','4001686343050','8719700009337','9002859066047','8716257552507',
  '3360101900102','3360101220101','3360100380103','8710998504665','8433329093446');

update public.product_features set swap_family='sweet_spreads_other', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0078: hagelslag/vlokken/sprinkles is broodbeleg-strooisel (R1-legacy)'
where barcode in (
  '8710496977671','8715700119441','8710496977626','8710496978975','8710496977695',
  '8715700119403','8710496035036','8718452611447','8718452611775','8710391937350',
  '8710391936421','8718906839434','8718906839397','8715700127927','8710496976766',
  '8715700119465','8718265809970','8718452147755','8718452359608','8710391937411');

update public.product_features set swap_family='dairy_drinks', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0078: chocolate drink is een drank, geen bonbon'
where barcode in ('7622210313218');

update public.product_features set swap_family='plant_based_dairy', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0078: rice drink is een plantaardige drank, geen chocolade'
where barcode in ('8713965500158');

update public.product_features set swap_family='baking_ingredients_non_swap', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0078: witte couverture is bakchocolade (consistent met 0074/0075)'
where barcode in ('4044889002232');

update public.product_features set swap_family='bread_bakery', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0078: praline-croissant is viennoiserie (croissant-regel stuurt naar bread_bakery)'
where barcode in ('2289118001903');

update public.product_features set swap_family='chocolate_bars', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0078: KitKat is een candy bar (merk-vangnet)'
where barcode in ('42370437');

update public.product_features set swap_family=null, classification_status='review_required',
  classification_confidence=0.3, classified_at=now(), mapping_version=1,
  classification_reason='audit1_0078: producttype onduidelijk (rauwe cacaonibs snack-of-ingredient; cannabis-chocolade buiten regulier swapmodel)'
where barcode in ('8718452550678','7107719207959');

-- POSTFLIGHT: select count(*) from product_features where classification_reason like 'audit1_0078%'; -- 72
-- ROLLBACK: herstel via _snapshot_0078_before.
