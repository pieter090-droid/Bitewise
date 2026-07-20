# Bitewise SnackSwap — datamodel, classificatie en scorelogica

Dit document beschrijft de productieketen na migratie 0105. De uitvoerbare
code en de database blijven de bron van waarheid; dit document legt uit hoe
de onderdelen samenwerken en hoe wijzigingen gecontroleerd moeten worden.

## 1. Keten van scan naar swaps

```text
Open Food Facts
  -> Edge Function lookup_product
  -> products (raw brondata)
  -> products_compute_features (classificatie voor werkelijk nieuwe rijen)
  -> products_z_apply_new_scan_guardrails (profieldefaults + voedingsconflicten)
  -> product_features (vastgelegde classificatie en afgeleide kenmerken)
  -> product_features_resolved (join met swap_family_mapping)
  -> SnackSwapService (doelbewuste kandidaatselectie)
  -> SwapScoreCalculator (uitsluiten, scoren, rangschikken)
  -> RuleBasedSwapProvider (Directe swaps en Andere opties)
  -> Flutter-UI
```

`products` blijft raw: auditmigraties corrigeren uitsluitend afgeleide data in
`product_features`. Een herscan of OFF-sync mag een handmatig beoordeelde rij
niet opnieuw classificeren. Migraties 0102 en 0103 borgen dat
`swap_family`, relevantiestatus, modelvelden en bewuste uitsluitingen een
aanraking van `products` overleven.

## 2. Classificatie: runtime en manifest

`public.compute_swap_family(name, category, categories_tags, pnns1, pnns2,
brand)` is de uitvoerbare bron van waarheid. Het is een PL/pgSQL-keten met
first-match-wins-semantiek. De actuele definitie komt uit migratie 0098 en
heeft na migratie 0109 77 geordende branches. De historische labels R1–R57 benoemen
auditfixes; zij zijn niet hetzelfde als het aantal runtimebranches.

`public.swap_family_rules` is vanaf migraties 0104/0105 een reproduceerbaar
manifest van die functie:

- één actieve rij per runtimebranch;
- `branch_order` 1–77 is de werkelijke evaluatievolgorde;
- `condition_sql` bevat de exacte PL/pgSQL-conditie;
- `source_function_hash` koppelt alle rijen aan één functiedefinitie;
- `classification_status` volgt `is_swap_relevant_default` van de familie;
- oude handmatige subsetregels blijven alleen inactief bestaan vanwege
  historische `matched_rule_id`-verwijzingen.

Na iedere wijziging aan `compute_swap_family()` moet
`refresh_swap_family_rule_manifest()` worden aangepast als het verwachte
branchaantal wijzigt, en daarna worden uitgevoerd. Een onvolledig manifest
faalt transactioneel.

## 3. Familiemodel

`swap_family_mapping` bevat 63 families: 50 swap-relevant en 13 bewust niet
swap-relevant. De tabel bepaalt cluster, producttype, vorm, consumptiewijze,
verwante families en de standaardrelevantie.

Swap-relevante families per cluster:

- Zoet: `breakfast_cereals`, `cakes_pastries`, `candy_sweets`,
  `cereal_bars`, `chocolate_bars`, `chocolate_confectionery`,
  `chocolate_spreads`, `cookies_biscuits`, `granola_muesli`,
  `honey_syrups`, `jams_fruit_spreads`, `sweet_spreads_other`.
- Hartig: `butter_margarine`, `cold_cuts`, `crackers_rice_cakes`,
  `crisps_chips`, `fried_snacks`, `hummus_legume_spreads`,
  `mayonnaise_sauces`, `meat_snacks`, `nuts_seeds`, `popcorn`,
  `sauces_dips`, `savory_spreads`.
- Zuivel: `cheese_snacks`, `dairy_desserts`, `dairy_drinks`,
  `ice_cream_desserts`, `plant_based_dairy`, `yoghurt_skyr_quark`.
- Drank: `alcohol_drinks`, `energy_drinks`, `fruit_juices`,
  `hot_beverages`, `smoothies`, `soft_drinks_light_zero`,
  `soft_drinks_regular`, `sports_drinks`, `water`.
- Fruit/groente: `fresh_fruit`, `fresh_vegetables`.
- Maaltijd: `bread_bakery`, `meal_components`, `ready_meals`,
  `sandwiches_wraps`, `soups`.
- Overig: `cooking_oils_fats`, `protein_bars`, `supplements_powders`.

Bewust niet swap-relevant:

`baby_food_non_swap`, `baking_ingredients_non_swap`,
`broths_bouillon_non_swap`,
`dairy_cooking_cream_non_swap`, `fats_oils_non_swap`, `fish_seafood`,
`grain_starch_ingredients`, `legumes_non_swap`,
`meat_alternatives_non_swap`, `raw_eggs_non_swap`, `raw_meat`,
`raw_poultry` en `unknown`.

`related_families` stuurt de cross-family groep “Andere opties”. De volledige
actuele relaties staan in `swap_family_mapping`; kopieer ze niet naar code of
documentatie.

## 4. Herkomstlegenda

`classification_reason` vertelt waarom de vastgelegde classificatie bestaat.

| Patroon | Herkomst en betekenis |
|---|---|
| `live_trigger_compute_swap_family` | Nieuwe scan, automatisch door de runtimeketen; regelconfidence 0,70. |
| `live_trigger_nutrition_guardrail:*` | Fase 5 heeft een nutritioneel conflict veilig opgelost, bijvoorbeeld zero-frisdrank of bronwater. |
| `live_trigger_nutrition_conflict:*` | Naam, familie en voeding spreken elkaar tegen of bewijs ontbreekt; status wordt `review_required`. |
| `legacy_existing_valid_family_status_backfill` | Bestaande familie uit vóór de audit, later van status voorzien. |
| `batch1_*` t/m `batch5_*` | Regel-/stagingbatches 0051–0070; reden vermeldt batch of individuele motivering. |
| `batch5_promotion_r1:*` | Handmatig beoordeelde stagingpromotie met motivering per product. |
| `correction_00XX:*` | Barcode-verankerde correctie van een concrete fout. |
| `audit1_00XX:*` | Fase-1-familieaudit; bevat doorgaans productgroep, besluit en historische R-regel. |
| `audit1_0102:*` | Tegenstrijdige eerdere beslissingen; bewust naar review gezet. |
| `review_required` | Status, geen redenpatroon: product doet niet mee totdat een mens het conflict beslecht. |
| NULL | Nooit beoordeeld of nog door geen regel gedekt; niet stilzwijgend interpreteren als “goed”. |

`classification_status` is beslissend: alleen `classified` kan in de resolved
view swap-relevant worden. `review_required` en bewuste uitsluitingen worden
niet als kandidaat getoond. `matched_rule_id` kan bij oude tabelgestuurde
classificaties gevuld zijn; runtimeclassificaties gebruiken de functie en
hebben daarom doorgaans geen betrouwbare losse rule-id.

## 5. Profieldefaults en nieuwe scans

`swap_family_profile_defaults` bevat 48 ondubbelzinnige familieprofielen.
Migratie 0099 vulde uitsluitend NULL/lege velden; AI-waarden zijn niet
overschreven. Gemengde families en ambigue velden blijven bewust NULL.

De tweede producttrigger uit 0101:

1. leest rechtstreeks uit deze tabel;
2. vult alleen nog lege smaak-, textuur- en momentvelden;
3. gebruikt kcal, suiker en zoetstoffensignalen om nutritionele
   familieconflicten af te vangen;
4. kiest bij twijfel `review_required`;
5. herclassificeert alleen rijen met live-triggerherkomst, nooit audit-/AI-
   of handmatige beslissingen.

## 6. Kandidaatselectie en scoring

De app gebruikt geen SQL-score. `SnackSwapService` haalt kandidaten op en
`SwapScoreCalculator` berekent de productiescore in Dart.

Kandidaatselectie:

- eerst dezelfde `swap_family`, daarna `snack_type`, `category_cluster` en
  uiteindelijk kale categorie als fallback;
- de pool begint met maximaal 40 hoogkwalitatieve kandidaten;
- voor een gekozen doel wordt de pool aangevuld met aantoonbaar betere
  kandidaten op kcal, suiker of eiwit, zodat datakwaliteit de doelas niet
  blind maakt;
- kandidaten moeten `classified` en resolved swap-relevant zijn.

Score:

- doelmatch 30%;
- voedingsverbetering 25%;
- dagcontext 15%;
- gelijkenis 15%;
- bewerkingskwaliteit 10%;
- datakwaliteit 5%.

Vangrails:

- gelijkenis onder 45 sluit uit;
- een kandidaat die op de gekozen doelas achteruitgaat wordt uitgesloten;
- bij porties wordt de doelas zowel per portie als per 100 g gecontroleerd;
- portiedata wordt alleen gebruikt wanneer beide kanten geldige
  portiegrootte plus kcal/suiker/eiwit per portie hebben, anders valt de hele
  vergelijking terug op 100 g;
- zoet-hartigconflicten worden in “Andere opties” geblokkeerd;
- cross-family vereist twee assen met minstens 10% winst, of één as met
  minstens 25% winst zonder bekende verslechtering boven 10%;
- reden- en doeltekst wordt alleen getoond als de beloofde as werkelijk wint.

## 7. Controleprotocol

Voor iedere classificatie- of triggerwijziging:

1. snapshot vóór datamutaties;
2. officiële `supabase db push --dry-run`;
3. wijziging transactioneel pushen;
4. `supabase/phase5_intake_check.sql` uitvoeren;
5. `supabase/phase5_persistence_check.sql` uitvoeren;
6. `supabase/phase6_documentation_check.sql` uitvoeren;
7. live regressietests mét `LIVE_SUPABASE_ANON_KEY` draaien;
8. `flutter analyze` en de gewone tests draaien;
9. migratiehistorie, gitstatus en rowcounts controleren.

De live tests slaan zichzelf zonder key over. Een groene standaardtest is dus
geen bewijs dat live regressies zijn uitgevoerd.

Belangrijkste tests:

- `test/swap_score_calculator_test.dart`: lokale score- en vangrailtests;
- `test/live_swap_regression_test.dart`: exacte top-3 voor 20 vaste
  bronbarcodes;
- `test/live_guardrail_sweep_test.dart`: eigenschappen over alle vier doelen;
- `CAPTURE_SWAP_BASELINE=1`: print een nieuwe top-3-baseline, maar herijken
  vereist altijd menselijke beoordeling.

## 8. Wijzigingsregels

- Voeg een classificatieregel toe in `compute_swap_family()`, nooit alleen in
  het manifest.
- Plaats specifieke uitzonderingen vóór brede regels: first-match wins.
- Synchroniseer daarna het manifest en pas de 77-branch-assertie bewust aan.
- Wijzig familieprofielen in `swap_family_profile_defaults`, niet in een
  gekopieerde lijst.
- Laat twijfel op `review_required`; een lege waarde is eerlijker dan gokken.
- Mutaties aan `products` voor auditcorrecties zijn verboden: het blijft raw.
- Behandel verschuiving van een live baseline als onderzoekssignaal, niet als
  reden om automatisch de verwachte uitkomst te overschrijven.
