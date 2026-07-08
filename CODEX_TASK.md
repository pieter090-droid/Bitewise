# SnackSwap: doel-gebaseerde swap-scoring — taak voor Codex

Dit document is de opdracht voor de volgende bouwfase van de SnackSwap-module
in de Bitewise-app (Flutter + Supabase, project-ref `ulgfgawoulkyumfzqgrc`).

**Taakverdeling — belangrijk, lees dit eerst:**
- **Claude (Anthropic) is verantwoordelijk voor de Supabase-database**: schema,
  migraties, classificatie-regels (`swap_family`/`swap_family_mapping`),
  datakwaliteit, en waar nodig een kleine AI-classificatiebatch (Anthropic
  Batch API) voor producten die de regels niet kunnen classificeren. Claude
  controleert en houdt de database volledig kloppend, gebaseerd op de mappen
  in `supabase/migrations/` en de bestaande edge functions.
- **Codex bouwt de Flutter-app-kant**: de nieuwe doel-gebaseerde scoring en UI
  hieronder beschreven.
- **Raak als Codex geen Supabase-migraties/schema aan** — als je een nieuw veld
  nodig denkt te hebben dat nog niet bestaat, meld dat in je samenvatting i.p.v.
  zelf een migratie te schrijven, zodat er geen dubbel werk of conflicterende
  wijzigingen ontstaan.

## Huidige staat (niet wijzigen tenzij nodig)

**Database:**
- `product_features.swap_family` is de primaire matchsleutel voor kandidaten
  (met `snack_type`/`category_cluster` als vangnetten voor producten zonder
  `swap_family`). Alle andere classificatievelden (`category_cluster`,
  `snack_type`, `product_form`, `consumption_mode`, `secondary_consumption_modes`,
  `usage_context`) worden deterministisch afgeleid uit `swap_family_mapping`
  (tabel: swap_family -> alle andere velden + `related_families` text[]).
- `products` heeft per-100g voedingswaarden (`kcal_100g`, `sugar_100g`,
  `protein_100g`, `fiber_100g`, `salt_100g`, `saturated_fat_100g`) ÉN
  per-portie waarden (`serving_quantity`, `serving_size`, `kcal_serving`,
  `proteins_serving`, `sugars_serving`, `fiber_serving`, `salt_serving`,
  `saturated_fat_serving` -- deze laatste is nieuw, automatisch berekend).
  **Portiedata is maar voor ~55% van de swap-relevante producten gevuld** --
  ALTIJD NULL-veilig terugvallen op per-100g-vergelijking als portiedata
  ontbreekt, nooit ontbrekend behandelen als 0 of als mismatch.
- **Belangrijke datawaarschuwing**: `serving_quantity`/`serving_size` is niet
  altijd een realistische portie (bv. een snee brood) -- bij sommige
  producten staat hier het HELE verpakkingsgewicht (voorbeeld: "Speciaal
  Bakkers Brood" heeft `serving_quantity=900` gram). Bouw een sanity-check:
  als `serving_quantity` implausibel groot is voor het `swap_family` (bv.
  >150g voor `bread_bakery`), val terug op per-100g-vergelijking.

**Relevante Dart-bestanden:**
- `lib/features/snackswap/domain/swap_score_result.dart` (SwapScoreResult/SwapGoal)
- `lib/features/snackswap/application/swap_score_calculator.dart` (huidige, ene uniforme formule)
- `lib/features/snackswap/application/rule_based_swap_provider.dart` (kandidaten ophalen + groeperen)
- `lib/features/snackswap/presentation/swap_screen.dart` (UI)
- `lib/features/snackswap/data/snackswap_service.dart` (Supabase-queries)

## Gewenste nieuwe flow

1. Gebruiker scant/kiest een product.
2. App toont: **"Wat voor swap zoek je?"** met 4 knoppen: Meer eiwit / Minder
   kcal / Minder suiker / Beste overall swap.
3. Na keuze: zoek kandidaten binnen `swap_family` = bronproduct.swap_family
   ("directe swaps"). "Andere opties" = `related_families` uit
   `swap_family_mapping`, met vergelijkbare `product_form`/`consumption_mode`.
4. Reken per PORTIE (met terugval per-100g, zie datawaarschuwing hierboven).
5. Per gekozen doel een eigen scoreformule (zie hieronder), inclusief
   minimale-verbeteringsdrempel en harde penalty's -- kandidaten die de
   drempel niet halen worden niet getoond (of alleen onder "Andere opties").
6. Toon per suggestie: score, `reason_codes`, en een leesbare Nederlandse
   `user_reason`-zin (bv. "Dit blijft gewoon brood, maar bevat meer eiwit per
   sneetje zonder veel meer kcal").

## De 4 formules (exacte specificatie, alles NULL-veilig)

**meer_eiwit:**
- Vereist: ≥20% meer eiwit per portie OF ≥2g meer eiwit per portie (absoluut)
- Harde penalty's: kcal >15% omhoog, suiker >20% omhoog, zout >20% omhoog
- Score = 45% eiwitwinst_per_portie + 25% eiwitdichtheid (eiwit/kcal×100)
  + 10% vezelwinst + 10% kcal-behoud + 10% suiker/zout/verzfat-behoud

**minder_kcal:**
- Vereist: ≥10% minder kcal per portie OF ≥25 kcal minder (absoluut)
- Harde penalty's: eiwit >30% omlaag, vezels >30% omlaag, suiker >20% omhoog
- Score = 60% kcal-reductie + 15% eiwit-behoud + 10% vezel-behoud
  + 15% suiker/zout/verzfat-behoud

**minder_suiker:**
- Vereist: ≥20% minder suiker per portie OF ≥2g minder suiker (absoluut)
- Harde penalty's: kcal >15% omhoog, verzadigd vet >20% omhoog
- Score = 65% suikerreductie + 15% kcal-behoud + 10% eiwit/vezelwinst
  + 10% verzfat/zout-behoud

**beste_overall:**
- Categorie-specifieke gewichten per `category_cluster` (de bestaande
  Nederlandse waarden: `zoet`/`drank`/`zuivel`/`hartig`/`fruit_groente`/
  `maaltijd`/`overig` -- NIET de Engelse namen). Voorbeeld: dranken wegen
  suiker/kcal zwaar, hartige snacks wegen zout zwaar, zuivel weegt eiwit
  zwaar, brood/graan weegt vezels zwaar.
- Score = categorie-specifieke voedingsscore + similarity_score
  (swap_family/product_form/consumption_mode-match) + databeschikbaarheid − penalty's

## Niet-onderhandelbare principes

- NULL-veilig overal: ontbrekende data = neutraal/overslaan, nooit als 0 of
  als mismatch behandelen.
- Geen destructieve wijzigingen aan de database vanuit de app-kant.
- `flutter analyze` moet 0 errors blijven na elke wijziging.
- Test met echte voorbeelden (Nutella `3017620429484`, en zoek zelf een
  brood- en cola-voorbeeld) tegen de live Supabase-database voordat je iets
  als klaar beschouwt.

## Leverbaar

- Nieuwe/aangepaste Dart-bestanden voor de 4 formules + per-portie-logica.
- Nieuwe UI voor de doelkeuze-flow.
- Korte samenvatting van wat is gewijzigd en wat nog open staat (incl. of je
  ergens een nieuw databaseveld nodig dacht te hebben, zodat Claude dat kan
  toevoegen).
