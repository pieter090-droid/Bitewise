-- Fase 1B, stap 3: fish_seafood-regel (rule_id 7) uitgebreid met
-- wrap/sandwich/broodproduct-uitsluitingen, zodat producten zoals "Eggwrap
-- gerookte zalm" niet opnieuw fout naar fish_seafood classificeren bij een
-- toekomstige (her)classificatierun. Nederlandse samengestelde woorden
-- (bv. "Eggwrap") worden bewust zonder \m/\M woordgrens-anker toegevoegd,
-- zodat het patroon ook binnen een compound word matcht.
--
-- Dry-run (voor toepassing) bevestigde:
-- - de 4 rollback-producten (Eggwrap gerookte zalm, Gerookte Zalm Wrap,
--   Wrap gerookte zalm, Zalm Sandwich Plakken) zouden niet opnieuw matchen
-- - tonijn/tonijnstukken/horsmakreel in water blijven fish_seafood
-- - rauwe/losse visproducten (zalmfilet, kabeljauwfilet, garnalen,
--   pangasiusfilet, makreelfilets) blijven fish_seafood
-- - reeds bestaande maaltijd-uitsluitingen (pizza/wrap/bowl/wok/pasta enz.,
--   toegevoegd in 0041-0044) blijven intact

update public.swap_family_rules set
  exclude_patterns = exclude_patterns || array[
    'wrap', 'eggwrap', 'sandwich', 'broodje', 'brood',
    'baguette', 'bagel', 'panini', 'toast'
  ],
  updated_at = now(),
  rule_version = rule_version + 1
where rule_id = 7;
