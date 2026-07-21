# SnackSwap releasecertificering

## Huidige beslissing

**NO-GO — fase 7 loopt.**

Dit document wordt pas op GO gezet wanneer de volledige catalogus- en
swapmatrixgates zijn gehaald. Een groene steekproef geldt niet als bewijs voor
de hele catalogus.

## Vereist eindbewijs

| Controle | Vereiste uitkomst | Actueel |
|---|---:|---:|
| Producten zonder status | 0 | 0 |
| Classified zonder familie | 0 | 0 |
| Relevant zonder classified-status | 0 | 0 |
| Nog inhoudelijk te beoordelen 0110-reviewrijen | 0 | 1.931 |
| Onverklaarde lege bron/doel-runs | 0 | nog niet gemeten |
| Doelrichtingsfouten | 0 | nog niet catalogusbreed gemeten |
| Onjuiste doelteksten | 0 | nog niet catalogusbreed gemeten |
| Persistentieverschillen | 0 | opnieuw meten na backfill |
| Live regressies | groen, niet overgeslagen | 0113-checkpoint groen |
| Releasebuild | groen | opnieuw uitvoeren bij eindgate |
| Git/database/deployment gelijk | ja | database t/m 0113; Git-checkpoint volgt |

De uiteindelijke tabel bevat daarnaast exacte aantallen classified, non-swap,
review_required, relevante producten, bron/doel-runs, kandidaatparen en alle
verklaarde lege uitkomsten.
