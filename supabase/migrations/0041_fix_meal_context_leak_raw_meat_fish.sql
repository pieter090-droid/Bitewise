-- Fase 1A correctie. Postflight na 0040 vond 7 producten die ondanks de
-- "geen pasta/aardappel/room"-scope tóch geraakt waren: rule_id 6
-- (raw_meat) en 7 (fish_seafood) hadden geen maaltijd-context-uitsluiting,
-- dus "Romige Pasta Met Zalm", "Jumbo Tagliatelle Pasta met Zalm en
-- Roomsaus", "Gebakken Aardappelen Met Varkenshaas..." enz. werden onterecht
-- fish_seafood/raw_meat (rauw product) i.p.v. met rust gelaten -- exact de
-- valkuil die de scope-restrictie probeerde te voorkomen.
--
-- Stap 1: deze 7 rijen terugzetten naar hun exacte staat van vóór 0040,
-- via de snapshot-tabel (barcode-voor-barcode, alleen de daadwerkelijk
-- geraakte rijen).
update public.product_features pf set
  swap_family = s.swap_family,
  is_swap_relevant = s.is_swap_relevant,
  classification_status = null,
  classification_confidence = null,
  classification_reason = null,
  matched_rule_id = null,
  rule_version = null,
  mapping_version = null,
  source_fingerprint = null,
  classified_at = null
from public._snapshot_0040_before s
join public.products p on p.barcode = s.barcode
where pf.barcode = s.barcode
  and p.name ~* '\mpasta\M|spaghetti|macaroni|penne|noedel|aardappel|slagroom'
  and p.name !~* 'kipfilet|chicken breast|chicken fillet|hÃ¤hnchenbrust|hÃ¼hnerbrust|blanc de poulet';

-- Stap 2: regels 6 en 7 bijwerken met de ontbrekende maaltijd-context-
-- uitsluiting (dezelfde soort woorden als rule_id 1 al voor kipfilet had).
update public.swap_family_rules set
  exclude_patterns = array['\msoep\M','ovenschotel','salade','\mmaaltijd\M','stamppot','lasagne','\mcurry\M','\mwok\M',
    '\mpasta\M','spaghetti','macaroni','penne','noedel','tagliatelle','fusilli','linguine','farfalle','aardappel','\mrijst\M'],
  updated_at = now(), rule_version = rule_version + 1
where rule_id = 6;

update public.swap_family_rules set
  exclude_patterns = array['ovenschotel','salade','sushi','pat[ée]\M',
    '\mpasta\M','spaghetti','macaroni','penne','noedel','tagliatelle','fusilli','linguine','farfalle','courgette.{0,3}spaghetti'],
  updated_at = now(), rule_version = rule_version + 1
where rule_id = 7;

-- POSTFLIGHT: select count(*) from product_features pf join products p on p.barcode=pf.barcode
--   where pf.matched_rule_id is not null and p.name ~* '\mpasta\M|spaghetti|macaroni|penne|noedel|aardappel|slagroom'
--   and p.name !~* 'kipfilet|chicken breast|chicken fillet|hÃ¤hnchenbrust|blanc de poulet';
--   -- moet nu 0 zijn

-- ROLLBACK: de rule_version-ophoging en exclude_patterns-wijziging op
-- rule_id 6/7 zijn de enige schemawijziging hier; de eerdere restore-update
-- kan herhaald worden vanuit dezelfde snapshot-tabel indien nodig.
