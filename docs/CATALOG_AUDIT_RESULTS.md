# SnackSwap catalogusaudit — resultaten

## Actueel hervattingsanker

- Status: **NO-GO**
- Actieve fase: 7C — nooit-beoordeelde backlog sluiten
- Laatste afgeronde productiemigratie: 0109
- Laatste gesynchroniseerde commit: `1a28527`
- Volgende stap: de 2.344 `unreviewed_no_rule_match`-rijen clusteren en beoordelen

## Nulmeting 2026-07-21 vóór migratie 0107

Live `product_features_resolved`, exact geteld via PostgREST:

| Grootheid | Aantal |
|---|---:|
| Producten totaal | 15.130 |
| `classified` | 11.496 |
| `review_required` | 898 |
| Status NULL / nooit beoordeeld | 2.736 |
| Zonder swapfamilie, alle statussen | 3.621 |
| Review met familie | 13 |
| Review zonder familie | 885 |
| Resolved swap-relevant | 9.849 |
| Niet swap-relevant | 5.281 |
| Classified zonder familie | 0 |
| Relevant zonder classified-status | 0 |

De eerder genoemde 3.623 was de historische telling van rijen zonder familie.
Dat is niet hetzelfde als de echte nooit-beoordeelde backlog. Na 0106 en één
nieuwe productrij bedraagt die backlog 2.736. Reviewrijen worden niet opnieuw
als onbekend behandeld: zij blijven apart totdat hun conflict inhoudelijk is
opgelost.

## Auditgroepen na migratie 0107

Migratie 0107 maakt één materialized checkpoint over alle raw producten en
vergelijkt de opgeslagen beslissing met de actuele runtimeclassifier.

| Auditgroep | Aantal |
|---|---:|
| `unreviewed_rule_match` | 388 |
| `unreviewed_no_rule_match` | 2.348 |
| `review_required` | 898 |
| `classified_rule_agreement` | 8.345 |
| `classified_rule_disagreement` | 1.369 |
| `classified_rule_gap` | 1.782 |
| Harde `invalid_*`-groepen | 0 |

De 1.369 disagreements en 1.782 gaps komen exact overeen met de eerder
vastgelegde persistentieanalyse: veel handmatige auditbesluiten zijn bewust
specifieker dan de algemene classifier. Zij worden in fase 7D onderzocht en
niet automatisch overschreven.

Verdeling van de 388 actuele regelmatches, grootste groepen: sauces_dips 58,
ready_meals 55, dairy_drinks 50, nuts_seeds 45, bread_bakery 38,
breakfast_cereals 32, soups 29, cold_cuts 15 en cookies_biscuits 12.

Van de 2.348 rijen zonder regelmatch hebben er 1.947 ook geen bruikbare kale
categorie. Deze groep vereist naam-/merkclusters en zal bij onvoldoende
informatie expliciet op `review_required` eindigen; hij wordt niet gegokt.

## Fase 7C — actuele regelmatches gesloten (0108–0109)

Alle 388 `unreviewed_rule_match`-producten zijn op naam, merk, categorie en
voedingssignalen gelezen. Migratie 0108 heeft 386 producten classified en
twee werkelijk vage productvormen op review gezet. Brede-regelfoutpositieven
zijn barcode-verankerd omgeleid; de overige actuele regelmatches zijn
inhoudelijk bevestigd. De eerste pushpoging is volledig teruggerold doordat
een gemengde familie bewust geen smaakdefault heeft; de gecorrigeerde migratie
behoudt dan de bestaande lege array en is na een nieuwe dry-run geslaagd.

De exacte top-3-regressie vond daarna een structurele modelkwestie: drink-
bouillon werd als directe soep-swap gerankt. Migratie 0109 splitst alle
duidelijke bouillon, broth, stock, fond en fumet af naar de nieuwe niet-
relevante familie `broths_bouillon_non_swap`. De runtimeclassifier heeft nu
77 branches en het familiemodel 63 families (50 relevant, 13 niet relevant).

Postflight na 0109:

| Auditgroep | Aantal |
|---|---:|
| `unreviewed_no_rule_match` | 2.344 |
| `review_required` | 898 |
| `classified_rule_agreement` | 8.656 |
| `classified_rule_disagreement` | 1.450 |
| `classified_rule_gap` | 1.782 |
| `unreviewed_rule_match` | 0 |
| Harde `invalid_*`-groepen | 0 |

Live controles: exacte top-3 groen; vier-doelen-sweep groen met 408 paren,
waarvan 68 op portiebasis; catalogusaudit groen en exact 15.130 unieke rijen.

## Verificatie 0106

- migratie lokaal en remote aanwezig;
- exacte live top-3-regressie groen;
- live vier-doelen-sweep groen: 407 paren, waarvan 67 op portiebasis;
- lokale testset: 43 tests groen, twee live tests zonder sleutel overgeslagen;
- dezelfde twee live tests zijn direct daarvoor met sleutel uitgevoerd;
- `flutter analyze`: geen issues;
- commit `1a28527` gepusht naar `main`.
