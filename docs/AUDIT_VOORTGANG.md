# Audit-voortgang: zesfasenplan naar testklare database

> Dit bestand is de hervattings-ankerplaats. Bij onderbreking (usage limit,
> sessie-einde): lees dit bestand en ga verder bij de eerste onafgevinkte stap.
> Autorisatie: gebruiker heeft op 2026-07-14 volledige autonome uitvoering
> van alle 6 fases goedgekeurd (db push + git commit/push zonder tussenkomst),
> binnen de vaste vangrails: products blijft raw, snapshot + dry-run +
> postflight per migratie, twijfel = review_required, geen AI/API-calls.

## Fase 1 — Legacy-audit alle swap-families
- [ ] Batch 1: zoet — chocolate_bars, chocolate_confectionery, chocolate_spreads,
      candy_sweets, cookies_biscuits, cakes_pastries, ice_cream_desserts,
      sweet_spreads_other, honey_syrups, jams_fruit_spreads
- [ ] Batch 2: hartig — crisps_chips, popcorn, nuts_seeds, crackers_rice_cakes,
      fried_snacks, meat_snacks, cheese_snacks, cold_cuts
- [ ] Batch 3: zuivel/spreads — yoghurt_skyr_quark, dairy_desserts, dairy_drinks,
      plant_based_dairy, savory_spreads, nut_butters, hummus_legume_spreads,
      butter_margarine
- [ ] Batch 4: dranken/overig — soft_drinks_regular, soft_drinks_light_zero,
      fruit_juices, hot_beverages, water, energy_drinks, sports_drinks,
      alcohol_drinks, smoothies, soups, sauces_dips, mayonnaise_sauces
- [ ] Batch 5: maaltijd/vers/rest — bread_bakery, sandwiches_wraps,
      breakfast_cereals, granola_muesli, cereal_bars, protein_bars,
      supplements_powders, fresh_fruit, fresh_vegetables, ready_meals,
      meal_components, cooking_oils_fats + alle non-swap families
- Werkwijze per batch: dump alle producten -> 3 checks (naam-splits,
  rauw-signalen, kcal/suiker-uitschieters) -> handmatige leesronde ->
  correctie-migratie (barcode-verankerd, snapshot, dry-run, postflight,
  commit+push). Regex-wortels meteen meefixen in compute_swap_family().

## Fase 2 — Smaakprofiel-defaults per familie
- [ ] Profieltabel opstellen (alleen ondubbelzinnige families)
- [ ] Migratie: NULL-velden vullen, AI-waarden nooit overschrijven

## Fase 3 — Model-vangrails (app, 3 losse commits)
- [ ] 3a: hartig-vs-zoet-blokkade in "Andere opties"
- [ ] 3b: strengere cross-family-poort (>=2 assen of 1 fors zonder verslechtering)
- [ ] 3c: portie-bewust scoren (serving-data waar beide kanten die hebben)

## Fase 4 — Regressiescript
- [ ] SQL-script met ~20 vaste testbarcodes, top-3 swaps per product
- [ ] Nulmeting draaien en vastleggen

## Fase 5 — Nieuwe-scan-borging
- [ ] 5a: trigger vult familie-default smaakprofielen bij nieuwe scans
- [ ] 5b: intake-controlescript over live_trigger-aanwas

## Fase 6 — Documentatie (loopt parallel mee)
- [x] Skelet docs/SWAP_LOGIC.md
- [ ] swap_family_rules-tabel synchroniseren met werkelijke functie
- [ ] Herkomst-legenda compleet
- [ ] Eindredactie na fase 5

## Logboek
- 2026-07-14: plan gestart. Takenlijst #11-#16 aangemaakt. Skelet documenten.
- 2026-07-16: Fase 1 batch 1 (zoet) — checks A/B/C gedaan. Migratie 0074:
  79 producten gecorrigeerd, 6 regex-wortels gefixt (R1 hagelslag-varianten,
  R2 liquorice->candy, R3 stroopwafel/honingnoten uit siroop, R4 rijswafel
  uit ijs, R5 maaltijdshakes uit meal_components, R6 nieuwe familie
  baking_ingredients_non_swap). VOLGENDE STAP batch 1: handmatige leesronde
  per familie-dump (chocolate_bars -> chocolate_confectionery -> candy_sweets
  -> cookies_biscuits -> cakes_pastries -> ice_cream_desserts -> spreads/
  syrups/jams), incl. chocoladetablet-consistentiecheck in chocolate_bars.
- 2026-07-16 (vervolg): leesronde kleine zoete families klaar. Migratie 0075:
  72 correcties (31 tablets -> confectionery, koekjes uit bars, honing-
  gearomatiseerde niet-siropen uit honey_syrups incl. blikfruit-op-siroop ->
  fresh_fruit, De Ruijter hagel/vlokken rechtgezet, hartige jams -> sauzen;
  R3-exclusie aangescherpt). VOLGENDE STAP batch 1: leesronde cakes_pastries
  (135) + ice_cream_desserts (164), daarna candy_sweets (322),
  chocolate_confectionery (~415), cookies_biscuits (593).
- 2026-07-16 (vervolg): leesronde cakes+ijs klaar. Migratie 0076: 25
  correcties (bakmixen -> baking, oats -> breakfast, zalmstaart -> vis,
  whey-poeders -> supplements; regelfixes R7 cake/taart-exclusies +
  poffertjes-canoniek en R8 whey-uit-ijs, met unittests in de dry-run).
  VOLGENDE STAP batch 1: leesronde candy_sweets (322), daarna
  chocolate_confectionery (~415), cookies_biscuits (593).
