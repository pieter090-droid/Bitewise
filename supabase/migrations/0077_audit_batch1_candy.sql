-- Fase 1 audit, batch 1 (zoet) — deel 4: leesronde candy_sweets (322).
-- Elk product individueel gelezen. Geen regelwijzigingen nodig; alle
-- fouten zijn productspecifiek (geen patroon dat nieuwe scans raakt).
--
-- Bevindingen: quiche lorraine (!) zat in snoep; boterwafeltjes en
-- mergpijpen zijn gebak/koek; dadels zijn droogfruit; Dextro Energy en
-- Lucovitaal zijn functionele sportproducten; Wilton sprinkles is
-- taartdecoratie (bakingrediënt); 5 producten met onduidelijk type
-- (Lotao Kiss-serie, gembersliertjes, vage naam) -> review_required.
-- Kauwgom en keelpastilles blijven bewust in candy_sweets (suikervrij
-- snoepgoed; als swap-suggestie is "kauwgom i.p.v. snoep" juist zinvol).
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

create table if not exists public._snapshot_0077_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  '8721245020746','8710624331818','5745000657513','8718452962969',
  '8713713079820','4046802271428','4046802252168','0070896174406',
  '00233057','2000000021149','2000000021146','2000000021150',
  '8718161358473','8717703312546'
);

update public.product_features set swap_family='cookies_biscuits', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0077: boterwafeltjes zijn koekjes, geen snoep'
where barcode in ('8721245020746');

update public.product_features set swap_family='cakes_pastries', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0077: mergpijpen zijn gebak (consistent met Gulden Krakeling-precedent)'
where barcode in ('8710624331818');

update public.product_features set swap_family='nuts_seeds', classification_confidence=0.55, classified_at=now(),
  classification_reason='audit1_0077: dadels zijn droogfruit-snack (consistent met a&c-dadels-precedent)'
where barcode in ('5745000657513');

update public.product_features set swap_family='ready_meals', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0077: quiche lorraine is een kant-en-klare maaltijd, geen snoep'
where barcode in ('8718452962969');

update public.product_features set swap_family='protein_bars', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0077: Lucovitaal high protein crunchy is een functionele eiwitsnack'
where barcode in ('8713713079820');

update public.product_features set swap_family='supplements_powders', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0077: Dextro Energy druivensuikertabletten zijn een sportsupplement (consistent met energiegel-precedent)'
where barcode in ('4046802271428','4046802252168');

update public.product_features set swap_family='baking_ingredients_non_swap', classification_confidence=0.6, classified_at=now(),
  classification_reason='audit1_0077: Wilton sprinkles is taartdecoratie, een bakingrediënt'
where barcode in ('0070896174406');

update public.product_features set swap_family='chocolate_bars', classification_confidence=0.5, classified_at=now(),
  classification_reason='audit1_0077: toffee biscuit chocolate bars zijn candy bars (Twix-achtig)'
where barcode in ('00233057');

update public.product_features set swap_family=null, classification_status='review_required',
  classification_confidence=0.3, classified_at=now(), mapping_version=1,
  classification_reason='audit1_0077: producttype onduidelijk (Lotao Kiss-serie, gembersliertjes-ingrediënt, of onbruikbare naam)'
where barcode in ('2000000021149','2000000021146','2000000021150','8718161358473','8717703312546');

-- POSTFLIGHT: select count(*) from product_features where classification_reason like 'audit1_0077%'; -- 14
-- ROLLBACK: herstel via _snapshot_0077_before.
