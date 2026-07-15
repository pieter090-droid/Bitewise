# Bitewise SnackSwap — datamodel en swap-logica

> Doel van dit document: een externe ontwikkelaar of reviewer kan hiermee de
> volledige keten begrijpen — van rauwe productdata tot de swap-suggestie in
> de app — zonder migratiebestanden te hoeven lezen. Bijgewerkt per fase van
> het auditplan (zie docs/AUDIT_VOORTGANG.md).

## 1. De keten in één oogopslag

```
Open Food Facts ──(Edge Function: lookup-product)──> products  (RAW, wordt nooit gemuteerd door migraties)
                                                        │ trigger: compute_product_features()
                                                        ▼
                                              product_features    (afgeleide velden + classificatie)
                                                        │ view-join met swap_family_mapping
                                                        ▼
                                          product_features_resolved  (leeslaag voor de app)
                                                        │
                                     Flutter-app: SnackSwapService (kandidaten) +
                                     SwapScoreCalculator (score) + provider (groepen)
                                                        ▼
                                              Swap-suggesties in de UI
```

Kernprincipes:
- `products` is de onbewerkte bron (Open Food Facts) en blijft raw.
- Classificatie gebeurt op één plek: `compute_swap_family()` (PL/pgSQL,
  first-match-wins regelketen), plus handmatig geauditeerde per-product
  correcties. De tabel `swap_family_rules` documenteert de regels.
- `swap_family_mapping` is het familiemodel: per familie de modelvelden
  (cluster, snack_type, vorm, eetwijze), verwante families en of de familie
  swap-relevant is.
- `is_swap_relevant` wordt in de view berekend: alleen `classified`-producten
  in een swap-relevante familie doen mee als swap-kandidaat.

## 2. Het familiemodel

*(Wordt aangevuld in fase 6: volledige familietabel met betekenis,
swap-relevantie en verwantschappen.)*

- ~50 swap-relevante families (chocolate_bars, crisps_chips, yoghurt_skyr_quark, ...)
- ~10 bewust niet-swap-relevante families (raw_meat, raw_eggs_non_swap,
  baby_food_non_swap, dairy_cooking_cream_non_swap, ...): het product is
  "verklaard" maar wordt nooit als snackswap voorgesteld.
- `related_families` stuurt de "Andere opties"-groep in de app
  (bv. ijs -> zuiveltoetjes).

## 3. Hoe een product zijn classificatie krijgt (herkomst-legenda)

Elk product draagt `classification_reason`. Betekenis van de patronen:

| Patroon | Betekenis | Betrouwbaarheid |
|---|---|---|
| `live_trigger_compute_swap_family` | Automatisch bij scan, via de regelketen | regel-niveau (0.70) |
| `legacy_existing_valid_family_status_backfill` | Bestond al vóór het auditplan; status-backfill | geauditeerd in fase 1 |
| `batch3a_brand_fallback` / `batch3b_...` / `batch4a_...` / `batch4b_...` | Regex/categorie-batches (migraties 0053-0056), dry-run-getest | 0.70 |
| `batch5_promotion_r1: <motivering>` | Handmatige beoordeling per product (staging -> promotie, migratie 0070); motivering per product leesbaar | 0.5-0.85 per product |
| `correction_00XX: <motivering>` | Barcode-verankerde correctie met bewijs (migraties 0071+) | hoog |
| `review_required` + reden | Bewust onbeslist: naam geeft onvoldoende signaal; NOOIT gegokt | n.v.t. (geen swap-kandidaat) |

Audit-trail: elke migratie heeft een `_snapshot_00XX_before`-tabel (exacte
rollback mogelijk) en staat genummerd in git (`supabase/migrations/`).

## 4. Het scoremodel in de app

Bestand: `lib/features/snackswap/application/swap_score_calculator.dart`.

- Kandidaatselectie (`SnackSwapService.getCandidatesForCluster`): zelfde
  `swap_family` (top-40 op datakwaliteit); pas als dat <3 oplevert bredere
  lagen (snack_type -> category_cluster -> kale categorie).
- Score = doel-match 30% + voedingsverbetering 25% + dagcontext 15% +
  gelijkenis 15% + bewerkingsgraad 10% + datakwaliteit 5%.
- Gelijkenis < 45 = kandidaat uitgesloten.
- "Andere opties": kandidaten uit `related_families`, zelfde
  vorm/eetwijze, met aantoonbare voedingsverbetering.
- *(Fase 3 voegt toe: hartig-vs-zoet-blokkade, strengere cross-family-poort,
  portie-bewust scoren — wordt hier gedocumenteerd zodra live.)*

## 5. Auditprotocol (de vaste drie checks)

Bij elke wijziging aan classificaties, en periodiek over nieuwe scans:
1. **Naam-splits**: (bijna) identieke productnamen verspreid over meerdere
   families -> bijna altijd een fout.
2. **Rauw-signalen**: woorden als rauw/braad/à griller in een
   kant-en-klaar-familie -> bereidingsstatus-fout.
3. **Uitschieters**: kcal/suiker ver buiten de familienorm -> vaak een
   portie/garnering/kookingrediënt dat niet in de familie hoort.

Daarnaast per migratie: dry-run in teruggedraaide transactie vóór uitvoering,
postflight-queries na uitvoering, rowcount- en products-onaangeroerd-checks.

*(Fase 4 voegt het regressiescript toe; fase 5 het intake-script voor nieuwe
scans — beide komen in de repo met verwijzing hier.)*
