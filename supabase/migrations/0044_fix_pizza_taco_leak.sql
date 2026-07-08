-- Fase 1A correctie #4 (laatste ronde van deze verificatiecyclus). "Tonijn
-- Pizza" (bereide pizza, geen rauwe vis) en "Rundergehakt Taco" (taco als
-- gerechtnaam, consistent behandeld als maaltijd-signaal net als de andere
-- gerechtnamen in dit traject) glipten er nog doorheen.

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
  and pf.matched_rule_id in (6,7)
  and p.name ~* '\mpizza\M|\mtaco\M|burrito|quesadilla|\mburger\M';

update public.swap_family_rules set
  exclude_patterns = exclude_patterns || array['\mpizza\M','\mtaco\M','burrito','quesadilla','\mburger\M'],
  updated_at = now(), rule_version = rule_version + 1
where rule_id in (6,7);

-- POSTFLIGHT (definitieve, brede eindcontrole):
-- select count(*) from product_features pf join products p on p.barcode=pf.barcode
--   where pf.matched_rule_id is not null and pf.matched_rule_id not in (1,4)
--   and p.name ~* 'ovenschotel|\msoep\M|salade|\mmaaltijd\M|stamppot|lasagne|\mcurry\M|\mwok\M|\mbowl\M|kant.?en.?klaar|poke|
--     \mpasta\M|spaghetti|macaroni|penne|noedel|tagliatelle|fusilli|linguine|farfalle|pappardelle|ravioli|gnocchi|fettuccine|
--     aardappel|slagroom|\mroom\M|couscous|paella|risotto|quiche|\mpizza\M|\mtaco\M|burrito|quesadilla|\mburger\M|pannenkoek';
--   -- moet nu 0 zijn

-- ROLLBACK: restore-update kan herhaald worden vanuit _snapshot_0040_before;
-- exclude_patterns-toevoeging op rule_id 6/7 terugdraaien met array_remove.
