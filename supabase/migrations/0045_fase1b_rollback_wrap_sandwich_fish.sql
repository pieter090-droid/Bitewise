-- Fase 1B, stap 2: rollback van 4 bevestigde fish_seafood-fouten.
-- Deze 4 producten zijn wrap/sandwich/broodproducten die ten onrechte naar
-- fish_seafood zijn geclassificeerd (matched_rule_id 7). Preflight bevestigde
-- exact deze 4 barcodes hebben een oude waarde in _snapshot_0040_before.
-- Alleen deze 4 exacte barcodes worden geraakt (geen pattern-match), om
-- vergelijkbare maar niet-onderzochte producten (bv. "Wraphapjes Met Zalm",
-- "Kabeljauwburger") buiten scope te houden. `products` wordt niet aangeraakt.

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
where pf.barcode = s.barcode
  and pf.barcode in (
    '8718907493789', -- Eggwrap gerookte zalm
    '8710442478528', -- Gerookte Zalm Wrap
    '8710400336938', -- Wrap gerookte zalm
    '8710400383956'  -- Zalm Sandwich Plakken
  );
