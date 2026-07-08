-- Fase 1A correctie #2. Rule_id 7 (fish_seafood) miste dezelfde bredere
-- maaltijd-context-uitsluiting die rule_id 6 net kreeg in 0041 -- "Wok
-- garnalen", "Poke Bowl Zalm Wazabi", "AH Verse maaltijd pappardelle zalm",
-- "Lasagne zalm met spinazie" werden onterecht fish_seafood (rauw product).
-- Rules 6, 8, 9 zijn gecontroleerd en hebben dit lek niet.

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
  and pf.matched_rule_id = 7
  and p.name ~* 'ovenschotel|\msoep\M|salade|\mmaaltijd\M|stamppot|lasagne|\mcurry\M|\mwok\M|\mbowl\M|kant.?en.?klaar|poke';

update public.swap_family_rules set
  exclude_patterns = array['ovenschotel','salade','sushi','pat[ée]\M',
    '\mpasta\M','spaghetti','macaroni','penne','noedel','tagliatelle','fusilli','linguine','farfalle','courgette.{0,3}spaghetti',
    '\msoep\M','\mmaaltijd\M','stamppot','lasagne','\mcurry\M','\mwok\M','\mbowl\M','kant.?en.?klaar','\mpoke\M'],
  updated_at = now(), rule_version = rule_version + 1
where rule_id = 7;

-- POSTFLIGHT: select count(*) from product_features pf join products p on p.barcode=pf.barcode
--   where pf.matched_rule_id is not null and p.name ~* 'ovenschotel|\msoep\M|salade|\mmaaltijd\M|stamppot|lasagne|\mcurry\M|\mwok\M|\mbowl\M|kant.?en.?klaar|poke'
--   and pf.matched_rule_id not in (1,4); -- moet 0 zijn (1/4 zijn de kipfilet-tiers waar dit bedoeld matcht)

-- ROLLBACK: restore-update kan herhaald worden vanuit _snapshot_0040_before.
