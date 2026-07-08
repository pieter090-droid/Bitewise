-- Fase 1A correctie #3 (laatste). "Tagliatelle zalm"/"Roerbaksensatie
-- Tagliatelle met zalm" bevatten geen van de maaltijd-signaalwoorden uit de
-- vorige twee restore-stappen (geen "wok"/"bowl"/"maaltijd"/enz. -- alleen
-- de pastanaam zelf gecombineerd met een vis), dus die restores misten ze.
-- Rule_id 7's exclude_patterns bevatten inmiddels wel "tagliatelle", dus dit
-- is puur een kwestie van deze 2 resterende rijen alsnog terugzetten.

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
  and p.name ~* 'tagliatelle|pappardelle|ravioli|gnocchi|fettuccine';

-- POSTFLIGHT (brede eindcontrole, alle plausibele maaltijd/pasta-signalen
-- samen, over alle 9 regels behalve de kipfilet-tiers 1/4 waar dit bedoeld
-- matcht):
-- select count(*) from product_features pf join products p on p.barcode=pf.barcode
--   where pf.matched_rule_id is not null and pf.matched_rule_id not in (1,4)
--   and p.name ~* 'ovenschotel|\msoep\M|salade|\mmaaltijd\M|stamppot|lasagne|\mcurry\M|\mwok\M|\mbowl\M|kant.?en.?klaar|poke|
--                  \mpasta\M|spaghetti|macaroni|penne|noedel|tagliatelle|fusilli|linguine|farfalle|pappardelle|ravioli|gnocchi|fettuccine|
--                  aardappel|slagroom';
--   -- moet nu 0 zijn

-- ROLLBACK: restore-update kan herhaald worden vanuit _snapshot_0040_before.
