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
| Nog generieke 0110-pendingrijen | 0 | 0 |
| Fase-7C-eindreview met concrete reden | gemeten | 1.887 |
| Onverklaarde lege bron/doel-runs | 0 | 0 van 41.192 directe runs |
| Doelrichtingsfouten | 0 | 0 in 202.831 directe + 36.043 cross-paren |
| Onjuiste doelteksten | 0 | 0 catalogusbreed |
| Onverklaarde persistentieverschillen | 0 | 0; 15.130 auditbesluiten vastgelegd |
| Live regressies | groen, niet overgeslagen | 0115: top-3 2x identiek; sweep groen |
| Releasebuild | groen | web release + Wasm dry-run groen |
| Git/database/deployment gelijk | ja | database t/m 0115; Git-checkpoint volgt |

De uiteindelijke tabel bevat daarnaast exacte aantallen classified, non-swap,
review_required, relevante producten, bron/doel-runs, kandidaatparen en alle
verklaarde lege uitkomsten.
