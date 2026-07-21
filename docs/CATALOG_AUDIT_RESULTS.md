# SnackSwap catalogusaudit — resultaten

## Actueel hervattingsanker

- Status: **NO-GO**
- Actieve fase: 7C — nooit-beoordeelde backlog sluiten
- Laatste afgeronde productiemigratie: 0110
- Laatste gesynchroniseerde commit: `1a28527`
- Volgende stap: de 2.344 expliciet gequarantineerde reviewrijen per cluster beoordelen

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

## Fail-closed quarantaine (0110)

De resterende 2.344 rijen zonder veilige classifieruitkomst staan sinds 0110
expliciet op `review_required` met reden `audit7_0110_pending`. Dit is een
veilig tussencheckpoint, geen inhoudelijke goedkeuring. Daardoor zijn er nu
nul producten met een lege classificatiestatus en kunnen deze rijen niet als
normale swapbron of kandidaat verschijnen.

Ook `compute_product_features()` is fail-closed gemaakt: een toekomstige scan
zonder veilige familie krijgt onmiddellijk `review_required` in plaats van
een stille NULL-status. De clusterreview promoveert hierna alleen producten
waarvoor naam, merk, categorie en/of voeding voldoende bewijs leveren.

Stand na 0110:

| Status | Aantal |
|---|---:|
| `classified` | 11.888 |
| `review_required` totaal | 3.242 |
| waarvan 0110-pending | 2.344 |
| Zonder status | 0 |

Live catalogusaudit en exacte top-3-regressie zijn na de quarantaine groen.

## Fase 7C — duidelijke vlees-, vis- en maaltijdclusters (0111)

De 2.344 quarantainerijen zijn eerst volledig gegroepeerd en de 0111-
doellijst is daarna product voor product op naam en merk gelezen. Brede
woordmatches bleken onveilig: `bacon` kwam bijvoorbeeld ook voor in brood,
groentegerechten, pasta en burgers. Die gevallen zijn vóór uitvoering
uitgesloten. Alleen 190 rijen waarvan de productvorm zelfstandig bewezen is,
zijn geclassificeerd; 2.154 twijfelgevallen blijven fail-closed pending.

| Uitkomst 0111 | Aantal |
|---|---:|
| Veilig geclassificeerd | 190 |
| Resterend `audit7_0110_pending` | 2.154 |
| Harde `invalid_*`-groepen | 0 |

De officiële Supabase-dry-run en transactionele live push zijn geslaagd. De
exacte top-3-poort signaleerde één verklaarbare wijziging bij de falafelwrap:
dertien nieuw toegelaten bapao/panini/croque-producten veranderden de top-40-
kandidatenpool, waardoor drie al bestaande sandwiches met hogere
datakwaliteit de oude top-3 vervingen. Alle zes producten en voedingswaarden
zijn gecontroleerd. Capture bevestigde dat de overige negentien fixtures
identiek bleven. De nieuwe baseline is vastgelegd.

Live verificatie na 0111: vier-doelen-sweep groen met 408 paren, waarvan 69 op
portiebasis; catalogusaudit exact 15.130 rijen met 8.656 agreements, 1.972
regelgaps, 1.450 disagreements en 3.052 reviewrijen; nul harde invarianten.

## Fase 7C — duidelijke overige supermarktclusters (0112)

Een tweede volledige naamlijstcontrole promoveerde 84 ondubbelzinnige
producten uit onder meer bakgrondstoffen, brood, zuivel, kaas, supplementen,
broodbeleg en dranken. Samengestelde namen zijn vóór uitvoering uitgesloten:
zo werd mozzarella in een complete orzomaaltijd geen kaas-snack,
`Müllermilk ... Brownie` geen gebak, gemberbier geen alcohol en vitamineshots
geen poedersupplement. Na 0112 blijven 2.070 inhoudelijk te beoordelen
quarantainerijen over.

Officiële dry-run en transactionele push: geslaagd. Exacte top-3 bleef op alle
twintig fixtures identiek. De vier-doelen-sweep bleef groen met 408 paren en
69 portievergelijkingen. De audit telt exact 15.130 rijen: 8.656 agreements,
2.056 regelgaps, 1.450 disagreements en 2.968 reviewrijen; `invalid_*` is nul.

## Fase 7C — graan, pluimvee en proteïne (0113)

De resterende graan-, pluimvee- en proteïnenamen zijn volledig uitgelezen en
per productvorm gesplitst. Droge rijst/pasta wordt geen kant-en-klare maaltijd;
proteïnerepen, -dranken, -poeders, pancakes en bowls krijgen ieder hun eigen
familie; rauwe kip, vleesbeleg, bereide componenten en gefrituurde snacks zijn
gescheiden. Vier twijfelgevallen zijn vóór uitvoering uitgesloten of
omgeleid, waaronder een maaltijdpakket met `kip` en een verkeerd gespelde
bapao.

0113 classificeerde 139 rijen; 1.931 blijven pending. Dry-run, transactionele
push, exacte top-3 en cataloguspoort zijn groen. De vier-doelen-sweep bleef
groen met 408 paren; 67 gebruikten volledige portiedata. De audit telt 8.656
agreements, 2.195 regelgaps, 1.450 disagreements en 2.829 reviewrijen, totaal
15.130 en nul `invalid_*`.

## Fase 7C — nooit-beoordeelde catalogus volledig gesloten (0114)

De laatste 1.931 generieke pendingrijen zijn definitief verantwoord. Nog 44
producten konden veilig worden geclassificeerd op de combinatie van een
specifieke broncategorie en passende naam. De overige 1.887 blijven bewust
`review_required`, buiten bron- en kandidaatselectie, met een concrete reden:

| Eindreden | Aantal |
|---|---:|
| Onvoldoende taxonomie voor veilige productvorm | 1.486 |
| Brede of strijdige broncategorie | 213 |
| Corrupte/onjuiste tekstcodering | 133 |
| Herkenbare maar niet ondersteunde productvorm | 52 |
| Samengesteld en echt ambigu | 3 |
| Categorie-bewezen geclassificeerd | 44 |
| Totaal verantwoord | 1.931 |

Hiermee is `audit7_0110_pending` exact nul. Over fase 7C zijn vanuit het
oorspronkelijke pendingsegment 457 producten geclassificeerd en 1.887 met
inhoudelijke eindreden fail-closed gebleven. Dry-run, transactie en postflight
zijn geslaagd. Exacte top-3 bleef identiek; vier-doelen-sweep groen met 408
paren en 67 portievergelijkingen. Catalogusaudit: 15.130 rijen, 8.656
agreements, 2.239 regelgaps, 1.450 disagreements, 2.785 reviewrijen en nul
`invalid_*`.

## Verificatie 0106

- migratie lokaal en remote aanwezig;
- exacte live top-3-regressie groen;
- live vier-doelen-sweep groen: 407 paren, waarvan 67 op portiebasis;
- lokale testset: 43 tests groen, twee live tests zonder sleutel overgeslagen;
- dezelfde twee live tests zijn direct daarvoor met sleutel uitgevoerd;
- `flutter analyze`: geen issues;
- commit `1a28527` gepusht naar `main`.
