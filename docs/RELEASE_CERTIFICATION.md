# SnackSwap releasecertificering

## Huidige beslissing

**GO — fase 7 is volledig gecertificeerd op 2026-07-21.**

De beslissing rust op de volledige live catalogus en vier doelen, niet op een
steekproef. Alle live tests zijn met sleutel uitgevoerd en niet overgeslagen.

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
| Live regressies | groen, niet overgeslagen | top-3, sweep, catalogusaudit en beide volledige matrices groen |
| Releasebuild | groen | web release + Wasm dry-run groen |
| Git/database/deployment gelijk | ja | database t/m 0115; Pages draait checkpoint `0c36c13` |

## Definitieve aantallen

| Grootheid | Aantal |
|---|---:|
| Producten totaal | 15.130 |
| `classified` | 11.987 |
| `review_required` met concrete fail-closed beslissing | 3.143 |
| Swap-relevante bronproducten | 10.298 |
| Classified non-swapproducten | 1.689 |
| Directe bron/doel-runs | 41.192 |
| Directe topparen | 202.831 |
| Cross-family bron/doel-runs | 41.192 |
| Cross-family paren | 36.043 |
| Verklaard leeg: scorepoort | 167 |
| Verklaard leeg: geen niet-slechtere doelskandidaat | 62 |
| Onverklaard leeg | 0 |

De GitHub Pages-workflow voor `0c36c13` is succesvol afgerond. De live bundle
bevat aantoonbaar de nieuwe tekst `Nog geen veilige swap`. Lokale analyse,
43 niet-live tests, workflow-YAML-validatie en de releasebuild zijn groen;
de vijf live gates zijn daarna samen met publieke deploymentsleutel groen.
