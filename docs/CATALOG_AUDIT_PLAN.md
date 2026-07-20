# SnackSwap catalogusaudit — fase 7

## Doel

Deze audit sluit de catalogus volledig. Iedere rij in `products` krijgt een
expliciete uitkomst: betrouwbaar geclassificeerd, bewust non-swap via een
niet-relevante familie, of `review_required`. Een lege status is nooit een
besluit.

## Volgorde

1. Reconcileer Git, migraties en live database.
2. Leg een reproduceerbare nulmeting vast.
3. Sluit eerst alle nooit-beoordeelde rijen.
4. Hercontroleer daarna alle bestaande classificaties.
5. Test vervolgens ieder relevant product voor alle vier doelen.
6. Borg begrijpelijke UI-uitkomsten en permanente releasepoorten.
7. Certificeer alleen bij volledig bewijs.

## Beslisuitkomsten

- `classified`: de beschikbare productdata ondersteunt één familie.
- niet-relevante familie: bewust buiten het swapmodel; resolved relevantie is
  false.
- `review_required`: informatie is onvoldoende of tegenstrijdig. Het product
  doet niet mee als normale bron of kandidaat.

## Migratieprotocol

Iedere datamigratie bevat een snapshot, wordt eerst met de officiële Supabase-
dry-run gecontroleerd en krijgt transactionele postflightasserties. `products`
blijft raw. Algemene regels worden vóór barcode-uitzonderingen onderzocht en
tegen de hele catalogus gecontroleerd.

## Auditgroepen

De materialized view `catalog_classification_audit` berekent per checkpoint
voor iedere raw productrij ook de uitkomst van de actuele
`compute_swap_family()`. Na iedere classificatiemigratie wordt hij expliciet
ververst; tellingen lezen daarna één vast auditmoment in plaats van tijdens
iedere query opnieuw duizenden regels uit te voeren:

- `unreviewed_rule_match`: nooit beoordeeld, huidige regel kent een familie;
- `unreviewed_no_rule_match`: nooit beoordeeld en nog geen regeldekking;
- `review_required`: al bewust apart gezet;
- `classified_rule_agreement`: opslag en actuele regel zijn gelijk;
- `classified_rule_disagreement`: opslag wijkt af, vaak door handaudit;
- `classified_rule_gap`: handmatig geclassificeerd maar geen actuele regel;
- `invalid_*`: harde datamodelovertreding; moet altijd nul zijn.

Een disagreement of gap is een onderzoekssignaal, geen automatische fout. De
handmatige audit kan specifieker zijn dan een generaliseerbare regel.

## Definitie van klaar

- nul producten zonder classificatiestatus;
- nul classified producten zonder familie;
- nul relevante reviewproducten;
- nul relevante producten uit een niet-relevante familie;
- nul onverklaarde lege resultaten in de volledige vier-doelenmatrix;
- nul doelrichtings-, doeltekst-, zoet/hartig- of portiegrondslagfouten;
- alle tests werkelijk uitgevoerd, inclusief live tests met sleutel;
- lokaal, `origin/main`, migratiehistorie en productie aantoonbaar gelijk;
- begrijpelijk audit- en releaseverslag met exacte aantallen.
