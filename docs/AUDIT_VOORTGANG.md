# Audit-voortgang: zesfasenplan naar testklare database

> Dit bestand is de hervattings-ankerplaats. Bij onderbreking (usage limit,
> sessie-einde): lees dit bestand en ga verder bij de eerste onafgevinkte stap.
> Autorisatie: gebruiker heeft op 2026-07-14 volledige autonome uitvoering
> van alle 6 fases goedgekeurd (db push + git commit/push zonder tussenkomst),
> binnen de vaste vangrails: products blijft raw, snapshot + dry-run +
> postflight per migratie, twijfel = review_required, geen AI/API-calls.

## Fase 1 — Legacy-audit alle swap-families
- [x] Batch 1: zoet — chocolate_bars, chocolate_confectionery, chocolate_spreads,
      candy_sweets, cookies_biscuits, cakes_pastries, ice_cream_desserts,
      sweet_spreads_other, honey_syrups, jams_fruit_spreads
      (migraties 0074-0080, 448 correcties, regelwortels R1-R10)
- [x] Batch 2: hartig — crisps_chips, popcorn, nuts_seeds, crackers_rice_cakes,
      fried_snacks, meat_snacks, cheese_snacks, cold_cuts
      (migraties 0081-0085, 289 correcties, regelwortels R11-R18b)
- [x] Batch 3: zuivel/spreads — yoghurt_skyr_quark, dairy_desserts, dairy_drinks,
      plant_based_dairy, savory_spreads, nut_butters, hummus_legume_spreads,
      butter_margarine
      (migraties 0086-0090, 214 correcties, regelwortels R19-R29)
- [x] Batch 4: dranken/overig — soft_drinks_regular, soft_drinks_light_zero,
      fruit_juices, hot_beverages, water, energy_drinks, sports_drinks,
      alcohol_drinks, smoothies, soups, sauces_dips, mayonnaise_sauces
      (migraties 0091-0094, 317 correcties, regelwortels R30-R46)
- [x] Batch 5: maaltijd/vers/rest — bread_bakery, sandwiches_wraps,
      breakfast_cereals, granola_muesli, cereal_bars, protein_bars,
      supplements_powders, fresh_fruit, fresh_vegetables, ready_meals,
      meal_components, cooking_oils_fats + alle non-swap families
      (migraties 0095-0098, 651 correcties, regelwortels R47-R57)
- Werkwijze per batch: dump alle producten -> 3 checks (naam-splits,
  rauw-signalen, kcal/suiker-uitschieters) -> handmatige leesronde ->
  correctie-migratie (barcode-verankerd, snapshot, dry-run, postflight,
  commit+push). Regex-wortels meteen meefixen in compute_swap_family().

## Fase 2 — Smaakprofiel-defaults per familie
- [x] Profieltabel opstellen (alleen ondubbelzinnige families)
      -> public.swap_family_profile_defaults, 48 families (migratie 0099)
- [x] Migratie: NULL-velden vullen, AI-waarden nooit overschrijven
      (migratie 0099, ai_overwritten=0)

## Fase 3 — Model-vangrails (app, 3 losse commits)
- [x] 3a: hartig-vs-zoet-blokkade in "Andere opties"
- [x] 3b: strengere cross-family-poort (>=2 assen of 1 fors zonder verslechtering)
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
- 2026-07-16 (vervolg): candy_sweets gelezen. Migratie 0077: 14 correcties
  (quiche uit snoep, wafeltjes/mergpijpen -> gebak, dadels -> droogfruit,
  Dextro/Lucovitaal -> functioneel, sprinkles -> bakingrediënt, 5 review).
  VOLGENDE STAP batch 1: leesronde chocolate_confectionery (~415), daarna
  cookies_biscuits (593) — daarmee is batch 1 (zoet) compleet.
- 2026-07-16 (vervolg): chocolate_confectionery (414) gelezen. Migratie 0078:
  72 correcties (45 drop/salmiak/pastille/turron -> candy_sweets [legacy
  liquorice-lek, o.a. de "Suikervrij muntendrop" uit de Chokotoff-casus],
  20 hagelslag/vlokken -> sweet_spreads_other [R1-legacy], chocolate drink ->
  dairy_drinks, rice drink -> plant_based_dairy, couverture -> baking,
  praline-croissant -> bread_bakery, KitKat matcha -> chocolate_bars,
  2 review_required). Geen nieuwe regelfixes nodig (R1/R2 dekten de wortels
  al). VOLGENDE STAP batch 1: leesronde cookies_biscuits (593) — laatste
  familie van batch 1 (zoet).
- 2026-07-16 (vervolg): cookies_biscuits (599) gelezen. Migratie 0079: 168
  correcties (42 repen -> cereal_bars, 43 gebak -> cakes_pastries, 11
  candybars -> chocolate_bars, 10 tabletten/pralines -> confectionery, 14
  wafels/aperitief -> crackers, 4 kaasbiscuits -> cheese_snacks, 9 bakmixen
  -> baking, 3 whey -> supplements, 7 proteine-koeken -> protein_bars,
  broodbeleg -> spreads, mochi -> candy, 11 review). Regelfixes R9 (candybar-
  merkcheck voor de koekregel, met ijs-exclusie) en R10 (stroopwafel/zoete
  wafels gaven null, nu koek) met 8 unittests groen. Migratie 0080:
  invariant-fix, 57 rijen *_non_swap kregen is_swap_relevant=false.
  BATCH 1 (ZOET) COMPLEET: 0074-0080, 448 datacorrecties, wortels R1-R10.
  VOLGENDE STAP: batch 2 (hartig) — crisps_chips, popcorn, nuts_seeds,
  crackers_rice_cakes, fried_snacks, meat_snacks, cheese_snacks, cold_cuts:
  eerst checks A/B/C, dan leesrondes per familie.
- 2026-07-16 (vervolg): batch 2 gestart. Check A (naam-splits) gedraaid;
  leesronde meat_snacks (14) + popcorn (36) + fried_snacks (92) klaar.
  Migratie 0081: 31 correcties (20 gepaneerde vis -> fish_seafood, 6
  schnitzel/kipburger -> meal_components, 2 Croky snacksmaak-chips ->
  crisps_chips, popcorn chicken/feuilletes/mini-frikandellen ->
  fried_snacks). Regelfixes R11 (naam-visregel voor fried-regel), R12
  (kip-exclusie popcorn), R13 (smaak-exclusie fried); 10 unittests groen.
  VOLGENDE STAP batch 2: leesronde crisps_chips (268, incl. check A-punt
  aardappelpartjes) + crackers_rice_cakes (240), daarna nuts_seeds (304,
  incl. kruidnoten), cheese_snacks (504), cold_cuts (413).
- 2026-07-16 (vervolg): leesronde crisps_chips + crackers_rice_cakes klaar.
  Migratie 0082: 65 correcties (27 diepvriesfriet -> meal_components [OFF-
  categorie chips-and-fries lekte, wortel R14 friet/chocochips-exclusie in
  chipsregel], 14 zoutjes/kroepoek/flips van crackers -> crisps, 5 kaas-
  biscuits -> cheese_snacks, 5 rijstzoutjes/toast/pretzel -> crackers, 5
  appel/banaanchips -> nuts_seeds droogfruit, 3 chocochips -> baking,
  Evergreen -> cookies, Ristorante pizza -> ready_meals, dip -> sauces, 3
  review). 7 unittests groen. VOLGENDE STAP batch 2: leesronde nuts_seeds
  (304, incl. kruidnoten-splits), daarna cheese_snacks (504), cold_cuts
  (413) — daarmee is batch 2 (hartig) compleet.
- 2026-07-16 (vervolg): leesronde nuts_seeds (309) klaar. Migratie 0083: 65
  correcties (14 choco-tabletten/pralines/chocopinda's -> confectionery, 7
  kruidnoten/stroopwafels -> cookies, 7 gebak -> cakes, 6 meerzadenbrood ->
  bread, 3 notendranken -> plant_based_dairy, 2 cashewpasta -> nut_butters,
  5 maaltijden -> ready_meals, pesto -> sauces, repen -> protein/cereal
  bars, walnootolie -> oils, hazelnootburger -> meat_alternatives, 4
  review). Regelfixes R15 (noten-exclusies + pinda/pitten in notenregel),
  R15b (kruidnoten/pepernoten in koekregel), R16 (notendranken naar
  plant_based_dairy); 8 unittests groen. VOLGENDE STAP batch 2: leesronde
  cheese_snacks (504), daarna cold_cuts (413) — slot van batch 2.
- 2026-07-16 (vervolg): leesronde cheese_snacks (509) klaar; familie is de
  facto de kaasfamilie (kaas, geraspt, verse kazen, kaasbiscuits en kaas-
  vervangers blijven bewust). Migratie 0084: 60 correcties (16 grillworst/
  carpaccio -> cold_cuts, 12 mac&cheese/pizza/salades -> ready_meals, 7
  gefrituurde kaassnacks -> fried, 5 flips/nacho's -> crisps, 3 zoutjes ->
  crackers, 3 dips -> sauces, 4 spreads -> savory_spreads, 3 vega-
  schnitzels -> meat_alternatives, 4 review). Regelfixes R17 (kaasregel-
  exclusies) en R17b (grillworst in vleeswarenregel); 8 unittests groen.
  VOLGENDE STAP batch 2: leesronde cold_cuts (413) — slot van batch 2.
- 2026-07-16 (vervolg): leesronde cold_cuts (429) klaar. Migratie 0085: 68
  correcties (22 snackworsten [Bifi, kabanossi, knak-/bock-/cocktailworst]
  -> meat_snacks, 20 rookworsten/verse componenten -> meal_components, 12
  maaltijden -> ready_meals, 2 Cup-a-Soup -> soups, 3 smeersalades ->
  savory_spreads, croissant -> bread, hamchips -> crisps, frikandellen ->
  fried, wok pieces -> meat_alternatives, 3 review). Regelfixes R18
  (vleeswaren-exclusies) en R18b (meat_snacks-regel uitgebreid); 10 unit-
  tests groen. Vegan beleg blijft bewust in cold_cuts.
  BATCH 2 (HARTIG) COMPLEET: 0081-0085, 289 correcties, wortels R11-R18b.
  VOLGENDE STAP: batch 3 (zuivel/spreads) — yoghurt_skyr_quark,
  dairy_desserts, dairy_drinks, plant_based_dairy, savory_spreads,
  nut_butters, hummus_legume_spreads, butter_margarine: eerst omvang +
  check A, dan leesrondes per familie.
- 2026-07-16 (vervolg): batch 3 gestart. Leesronde 4 kleine families
  (butter_margarine 66, hummus 62, nut_butters 165, savory_spreads 56) klaar.
  Migratie 0086: 26 correcties (12 roomboter-bakkerij -> brood/gebak/koek/
  kaas/baking, 11 peanut-butter-repen/muesli/ijs -> protein_bars/granola/
  ice_cream/confectionery/cereal, 2 hummus-chips/bowl -> crisps/ready_meals,
  artisjok -> sauces). Regelfixes R19 (nut_butters-regel sluit reep/ijs/bake
  uit — stond vóór protein_bars), R20 (boterregel sluit bakkerij uit), R20b
  (focaccia -> bread, krakeling/dumkes -> cookies); 10 unittests groen.
  VOLGENDE STAP batch 3: leesronde yoghurt_skyr_quark (474), daarna
  dairy_drinks (204), dairy_desserts (197), plant_based_dairy (195).
- 2026-07-16 (vervolg): leesronde yoghurt_skyr_quark (474) klaar; grote,
  coherente zuivelfamilie. Migratie 0087: 31 correcties (14 plantaardige
  yoghurt/kwark/skyr -> plant_based_dairy, 5 kefir/drinkyoghurt ->
  dairy_drinks, 4 fruitbiscuits -> cookies, 2 kwarkcake-bakmix -> baking,
  2 muesli/topping -> granola, yoghurt-gums -> candy, yoghurtijs -> ijs,
  rijstwafels -> crackers, 1 review). Regelfixes R21 (plantaardige zuivel
  vóór yoghurtregel), R22 (kefir/à boire -> dairy_drinks), R23 (yoghurt-gums
  in candy), biscuit-exclusie in yoghurtregel; 13 unittests groen. Yoghurt+
  granola-bekers en geiten-/schapenyoghurt blijven bewust. VOLGENDE STAP
  batch 3: leesronde dairy_drinks (204+), daarna dairy_desserts (197),
  plant_based_dairy (195+).
- 2026-07-16 (vervolg): leesronde dairy_drinks (204) klaar; coherente
  drankfamilie. Migratie 0088: 12 correcties (2 koffiemelk ->
  dairy_cooking_cream_non_swap, 3 drankmix/Dolce-Gusto-pods -> hot_beverages,
  whey 300g -> supplements, melkpoeder -> baking, Duo Penotti Milkshake ->
  chocolate_spreads, 4 meal-replacement drinks -> review). Regelfix R24
  (dairy_drinks-regel sluit mix/poeder/pods/maaltijddrank uit) + R25 (NIEUWE
  drinkmelk-regel: naam eindigend op 'melk' -> dairy_drinks; dekkingslek
  gedicht, want plain melk werd door geen regel geclassificeerd — 'melk-
  chocolade'/melkpoeder/mix veilig uitgesloten). 9 unittests groen. VOLGENDE
  STAP batch 3: leesronde dairy_desserts (197), daarna plant_based_dairy
  (195+, incl. de instroom uit R16/R21).
- 2026-07-16 (vervolg): leesronde dairy_desserts (197) klaar; familie was
  fors vervuild via legacy-AI. Migratie 0089: 82 correcties (40 plantaardige
  desserts/yoghurt -> plant_based_dairy, 36 dairy yoghurt/skyr/kwark [FAGE/
  Activia/Oikos/Hipro-beker/biogarde/hangop/Kvarg/Sterke Start] ->
  yoghurt_skyr_quark, 3 Actimel/Vifit -> dairy_drinks, koffiemelk -> cream,
  slasaus -> sauces, ProActiv -> review). Regelfix R26 (plant-merken Alpro/
  Provamel/Oatly/Abbot Kinney/Vemondo + 'op basis van X' / 'soja/oat gurt'
  -> plant_based_dairy); 9 unittests groen. Echte vla/mousse/pudding/
  tiramisu/crème brûlée blijven bewust; ambigue eennaam-bekers ongemoeid.
  VOLGENDE STAP batch 3 (slot): leesronde plant_based_dairy (nu ~275+ na de
  instroom uit R16/R21/R26).
- 2026-07-16 (vervolg): leesronde plant_based_dairy (249) klaar. Migratie
  0090: 63 correcties (16 plantaardige kaasvervangers [Violife/Soyananda/
  plakken/rasp] -> cheese_snacks, Pa'lais -> savory_spreads, 21 plantaardige
  kookroom [cuisine/kochcreme/keukenroom/fraiche/whipping/topping/creamers]
  -> dairy_cooking_cream_non_swap, 25 blik-kokosmelk -> idem). Regelfixes
  R29 (plantaardige kaas -> cheese_snacks), R28 (plantaardige kookroom),
  R27 (kokosmelk zonder 'drink' -> kookroom; kokosDRINK blijft plantaardig);
  10 unittests groen.
  BATCH 3 (ZUIVEL/SPREADS) COMPLEET: 0086-0090, 214 correcties, R19-R29.
  VOLGENDE STAP: batch 4 (dranken/overig) — soft_drinks_regular,
  soft_drinks_light_zero, fruit_juices, hot_beverages, water, energy_drinks,
  sports_drinks, alcohol_drinks, smoothies, soups, sauces_dips,
  mayonnaise_sauces: eerst omvang, dan leesrondes per familie.
- 2026-07-16 (vervolg): batch 4 gestart (2119 producten, in 4 delen).
  Deel 1: leesronde alcohol_drinks (77) + energy_drinks (28) +
  sports_drinks (13) + smoothies (51) + water (76) + soft_drinks_light_zero
  (60) klaar; de drankfamilies zelf zijn schoon. Migratie 0091: 15
  correcties (5 producten die alleen "water" in de naam hadden: bonen ->
  meal_components, sardines -> vis, tomatensoep -> soups, sate-mix ->
  sauces, Oat&Go -> breakfast; 4 via alcoholwoord: 2 whisky-cocktailsaus +
  mirin -> sauces, kookpudding rum -> dairy_desserts; 4 zero-energydrinks
  -> energy_drinks; 2 "basis voor smoothie" -> fresh_fruit). Regelfixes R30
  (alcoholregel sluit saus/pudding/mirin/kookwijn uit) en R31 (waterregel
  sluit 'in water'/bonen/sardines/soep/'water toevoegen' uit); 10 unittests
  groen. VOLGENDE STAP batch 4 deel 2: soft_drinks_regular (435) +
  fruit_juices (160), incl. consistente behandeling van limonadeSIROOP-
  concentraten (Karvan Cevitam/Raak, ook die in light_zero).
- 2026-07-16 (vervolg): deel 2 klaar — soft_drinks_regular (435) +
  fruit_juices (160). soft_drinks_regular was de meest vervuilde
  drankfamilie (OFF-categorie 'sweetened beverages' trok alles zoet+vloeibaar
  aan). Migratie 0092: 129 correcties (42 zuiveldranken incl. 16 RTD-
  melkkoffies -> dairy_drinks, 14 koffie/thee-bereidingen -> hot_beverages,
  12 eiwitpoeders -> supplements, 9 alcoholvrije bieren -> alcohol, 10
  energydrinks + 7 sportdranken, 3 plantaardig, 7 groente-/fruitsappen, 4
  snoep, 6 fruitconserven/knijpfruit -> fresh_fruit, 6 kookcitroensap ->
  sauces, plus losse missers). Regelfixes R32 (RTD-melkkoffie ->
  dairy_drinks, pads blijven hot_beverages), R33 (drankmerken Fristi/
  Optimel/Vifit/Chocomel/HiPro), R34 (clear whey/eiwitlimonade ->
  supplements), R35 (alcoholvrij/radler/pils/lager/IPA) en R36 (NIEUW
  dekkingslek gedicht: 'sinaasappelsap'/'appelsap' matchten niet op
  '\msap\M'; 'op sap'/siroop/saus uitgesloten). 18 unittests groen.
  Limonadesiroop blijft bewust frisdrank; het concentraat-vs-kant-en-klaar
  probleem hoort bij fase 3c (portie-bewust scoren).
  VOLGENDE STAP batch 4 deel 3: hot_beverages (272+) + soups (218+).
- 2026-07-16 (vervolg): deel 3 klaar — hot_beverages (286) + soups (220);
  beide families in de kern schoon. Migratie 0093: 74 correcties (23 RTD-
  melkkoffies -> dairy_drinks, 8 koffiemelk/creamer -> cooking cream, 7
  koffie/thee-poeders -> supplements, 9 kant-en-klare ijsthees -> frisdrank/
  zero, 3 koffiekoekjes -> cookies, 11 soepgroente/verspakketten ->
  fresh_vegetables, 4 soepballetjes + 2 peterselie -> meal_components, 3
  soepstengels/croutons -> crackers, sushi-gember -> sauces, bakcacao ->
  baking, Stelz -> alcohol, 1 review). Regelfixes R37 (koffiemelk ->
  cooking cream), R38 (koffiewafel/Cafe Noir -> koek), R39 ('iced tea'/
  ijsthee/fuze tea; 'ice.?tea' ving alleen "ice tea"), R40 (soepregel sluit
  soepgroente/-stengels/-balletjes/verspakket uit) + bouillon toegevoegd aan
  de soepregel (DERDE dekkingslek: 'bouillonblokjes' bevat geen soep/soup en
  werd door geen regel geclassificeerd). 15 unittests groen.
  VOLGENDE STAP batch 4 deel 4 (slot): sauces_dips (668+) +
  mayonnaise_sauces (61).
- 2026-07-16 (vervolg): deel 4 klaar — sauces_dips (678) +
  mayonnaise_sauces (62). Migratie 0094: 99 correcties (30 blikbonen/vlees
  "in tomatensaus" + verspakketten -> meal_components, 8 maaltijden ->
  ready_meals, 7 vis in olie -> fish_seafood, 5 olijfolie ->
  cooking_oils_fats, 16 smeerspreads -> savory_spreads, 4 hoemoes ->
  hummus, 20 mayonaises -> mayonnaise_sauces, plus grissini/brood/
  dessertsaus/beenham/chips en 2 review). Regelfixes R41 (mayonaise-regel),
  R42 (sauzenregel-exclusies), R43 (hoemoes), R44 (Streich/bruschetta
  spread), R45 (olijvenregel kaapte "huile d'olive" en "sardines a l'huile
  d'olive") en R46 (VIERDE dekkingslek: ketchup/pesto/mosterd/sambal/ketjap/
  azijn/passata/salsa/tapenade/guacamole/tzatziki classificeerden helemaal
  niet). 19 unittests groen. Azijn, tomatenpuree en olijven blijven bewust
  in sauces_dips (bewuste modelkeuze).
  BATCH 4 (DRANKEN/OVERIG) COMPLEET: 0091-0094, 317 correcties, R30-R46.
  VOLGENDE STAP: batch 5 (maaltijd/vers/rest) — bread_bakery,
  sandwiches_wraps, breakfast_cereals, granola_muesli, cereal_bars,
  protein_bars, supplements_powders, fresh_fruit, fresh_vegetables,
  ready_meals, meal_components, cooking_oils_fats + alle non-swap families.
- 2026-07-16 (vervolg): batch 5 gestart (3019 producten, in 4 delen).
  Deel 1: leesronde breakfast_cereals (150) + granola_muesli (174) +
  cereal_bars (119) + protein_bars (93) + supplements_powders (170) klaar;
  deze families zijn grotendeels bestemming van eerdere correcties en dus
  schoon. Migratie 0095: 28 correcties. CONSISTENTIEFIX: Hero B'tween stond
  gesplitst over chocolate_bars (via R9 uit 0079) en cereal_bars; B'tween is
  een granenreep, geen candy bar -> alles naar cereal_bars, merk uit R9
  (R47). Dit corrigeert een eerdere eigen beoordeling. Verder 5 mueslibrood/
  -bollen -> bread, mueslikoeken -> cookies, 6 muesli-/granolarepen ->
  cereal_bars, 2 wafels -> crackers, schnitzel -> meal_components, zaden ->
  nuts_seeds, 3 RTD-eiwitshakes -> dairy/plant, Huel-poeder + gummies ->
  supplements, carobmeel -> baking, 2 review. Regelfixes R48 (granolaregel
  sluit brood/bol/koek/reep uit; repen met spatie), R49 (VIJFDE dekkingslek:
  havermout/havervlokken/brinta/ontbijtpap/porridge/oats classificeerden
  niet; ook 'corn flakes' met spatie) en R50 (ZESDE dekkingslek: samengestelde
  '-brood'-namen zoals mueslibrood/volkorenbrood matchten niet op
  '\mbrood\M'). 8 unittests groen; postflight bevestigt btween_split=1.
  VOLGENDE STAP batch 5 deel 2: bread_bakery (502+) + sandwiches_wraps (148).
- 2026-07-16 (vervolg): deel 2 klaar — bread_bakery (507) +
  sandwiches_wraps (148). Dit legde het grootste structurele probleem van de
  audit bloot: "broodje" betekent in het NL zowel een KAAL bread roll als een
  BELEGD broodje, en de sandwich-regel matchte op 'broodje'. Daardoor stonden
  ~100 kale broodjes (kaiser/hamburger/hotdog/pita/melk/desem), zoete
  viennoiserie en hartige bakkerijsnacks bij de belegde sandwiches — wie een
  hamburgerbroodje scande kreeg belegde sandwiches als swap. Migratie 0096:
  197 correcties. Regelfix R51 (sandwiches_wraps vereist nu een BELEGD-
  signaal: 'sandwich'/'wrap'/'belegd broodje'/'broodje <vulling>'), R51b
  (broodregel vangt kale broodjes + tortilla/naan/pita) en R52 (ZEVENDE
  dekkingslek: 66 crispbread-producten — knäckebröd stond in de regel alleen
  zonder umlauts — plus melba toast, biscotte, Wasa, grissini, croutons,
  soepstengels -> crackers_rice_cakes). Verder 6 paneermeel/bakmix ->
  baking, 3 -> meal_components, vla, 2 kaasbolletjes, spreads/condimenten,
  zalmplakken, 1 review. 11 unittests groen. Postflight: sandwiches_wraps
  148 -> 33 (alleen nog echt belegd), bread_bakery 507 -> 535.
  VOLGENDE STAP batch 5 deel 3: fresh_fruit (196+) + fresh_vegetables (693+).
- 2026-07-17 (vervolg): deel 3 klaar — fresh_fruit (196) + fresh_vegetables
  (693). Vanaf hier is de werkwijze op verzoek van de gebruiker versneld:
  patroon-gebaseerde correcties (regex-groepen over de familiedump) in plaats
  van product-voor-product beoordeling. Snapshot/dry-run/postflight en
  "twijfel = review_required" blijven ongewijzigd gelden. Migratie 0097:
  156 correcties. Grootste groepen: 15 babyvoeding/knijpfruit, 38 gedroogd
  fruit (dadels, rozijnen, studentenhaver), 29 kant-en-klaarmaaltijden,
  21 meal_components, 15 hartige spreads, 13 sauzen/dips, 9 groentechips,
  5 wafels, 3 gazpacho, 2 tomatenblik. Regelfixes R53 (droogfruit
  consolideert in nuts_seeds — precedent dadels 0077 en appel-/bananenchips
  0082) en R54 (babyvoeding/-hapjes en leeftijdsaanduidingen zoals 4m+ /
  12+ maanden -> baby_food_non_swap, vóór alle snackregels). Postflight:
  touched=156, gap=0, total=15129, nonswap_ok=0.
  VOLGENDE STAP batch 5 deel 4 (laatste): meal_components (570) +
  ready_meals (103) + cooking_oils_fats (101).
- 2026-07-18: deel 4 (LAATSTE) klaar — meal_components (570) + ready_meals
  (103) + cooking_oils_fats (101). Migratie 0098: 270 correcties.
  STRUCTURELE BEVINDING: de catch-all `p1 = composite or naam ~ maaltijd|
  salade|meal` sleepte alles met "salade" in de naam naar meal_components.
  In het NL is een "salade" in een kuipje (eiersalade, tonijnsalade,
  huzarensalade, kip-kerriesalade, filet americain) echter smeerbaar
  BROODBELEG — wie eiersalade scande kreeg lasagne en nasi als swap. R55
  splitst dit (51 producten -> savory_spreads), met maaltijdsalades en
  salade bowls expliciet uitgezonderd. Tweede bevinding: de ready_meals-
  regel kende alleen 'kant-en-klaar' en 'pizza', waardoor lasagne, nasi,
  bami, ravioli, tortellini, quiche, gratin en stoommaaltijden bij de
  losse maaltijdcomponenten bleven hangen -> R56 (139 producten). R57:
  maaltijdvervangers (meal replacement bar/shake, Modifast, drinkmaaltijd)
  vielen via '\mmeal\M' ook in meal_components -> supplements_powders.
  Verder 14 soepen/bouillons, 12 verse groenten/kruiden, 7 vers fruit,
  7 visconserven "in olijfolie" uit cooking_oils_fats (spiegelt R42/R45),
  7 bakkerij (tortillawraps, pizzabodem/-deeg), 6 babyvoeding, 3 margarine,
  2 bakmix (oliebollen), 2 granenrepen (merk 'Holie'), 1 nacho's, 1 chili-
  olie-condiment, 8 supplementen, 10 te vage namen -> review_required.
  15 unittests groen (o.a. Eiersalade -> savory_spreads, Maaltijdsalade ->
  ready_meals, Verspakket Maaltijdsalade -> meal_components).
  Postflight == dry-run: touched=270, gap=3623 (ongewijzigd t.o.v.
  baseline; dit is de losstaande backlog nooit-geclassificeerde rijen),
  total=15129, view_rows=15129, nonswap_ok=0. Familietellingen na afloop:
  meal_components 352, ready_meals 271, cooking_oils_fats 85,
  savory_spreads 141.

  ### FASE 1 AFGEROND
  Migraties 0074-0098 (25 stuks), ~2.020 datacorrecties, 57 regexwortels
  (R1-R57) gefixt, 7 dekkingslekken gedicht (drinkmelk, samengestelde
  sapnamen, bouillon, ketchup/pesto/mosterd c.s., havermout/porridge,
  samengestelde '-brood'-namen, knäckebröd met umlauts) en 5 structurele
  splitsingen opgelost (B'tween candy-vs-granenreep, "broodje" kaal-vs-
  belegd, droogfruit, plantaardig-vs-zuivel, NL kuipsalade-vs-maaltijd).
  VOLGENDE STAP: fase 2 — smaakprofiel-defaults per ondubbelzinnige familie.

## Fase 2 — logboek
- 2026-07-18: migratie 0099. Uitgangspunt: 6.814 producten zonder
  is_sweet/is_salty/is_crunchy en ~6.9k met lege taste_/texture_profile en
  use_moment — precies de producten die nooit door AI-verrijking zijn
  gegaan. Voor het scoremodel betekent zo'n NULL "neutraal 50", dus die
  producten kregen willekeurige swaps.
  Aanpak: defaultprofiel per familie, maar ALLEEN waar het profiel
  ondubbelzinnig uit de familie volgt. Gemengde families krijgen bewust
  GEEN default (sauces_dips, bread_bakery, ready_meals, meal_components,
  supplements_powders, grain_starch_ingredients, alle *_non_swap): NULL is
  daar eerlijker dan een gok. Ook binnen een familie kan één veld NULL
  blijven als juist dat veld ambigu is — nuts_seeds en butter_margarine
  krijgen geen is_salty (gezouten én ongezouten), popcorn geen is_sweet/
  is_salty (zoet én zout), nut_butters/yoghurt/plantaardig/dairy_drinks
  geen is_sweet (gezoet én ongezoet), hot_beverages geen smaak-default
  (koffie, thee en chocolademelk door elkaar).
  48 families in de tabel. Gevulde gaten: is_sweet 6814 -> 4922, is_salty
  6814 -> 5228, is_crunchy 6814 -> 5172, taste 6932 -> 5520, texture
  6850 -> 5080, use_moment 6818 -> 4711. Wat overblijft zijn de bewust
  overgeslagen families plus de 3.623 rijen zonder swap_family.
  CONTROLE: ai_overwritten=0 — geen enkele bestaande waarde is aangeraakt,
  er is uitsluitend in NULL/lege velden geschreven. Postflight == dry-run.
  De defaults staan persistent in public.swap_family_profile_defaults, zodat
  fase 5a (trigger voor nieuwe scans) en fase 6 (documentatie) dezelfde bron
  gebruiken in plaats van een kopie van de lijst.

## Fase 3 — logboek
- 2026-07-19: stap 3a afgerond. `scoreCrossForm()` blokkeert nu expliciete
  zoet-hartigconflicten in "Andere opties" met reden
  `sweet_savory_conflict`. Ontbrekende profielwaarden blijven permissief:
  NULL betekent onbekend en leidt niet tot een gok. Twee regressietests
  toegevoegd; volledige SwapScore-testset: 22/22 groen.
- 2026-07-19: stap 3b afgerond. Cross-family kandidaten vereisen nu twee
  voedingsassen met minimaal 10% verbetering, of één forse verbetering van
  minimaal 25% zonder een bekende as meer dan 10% te verslechteren.
  Ontbrekende waarden tellen niet als winst of verlies. Vier poorttests
  toegevoegd; volledige SwapScore-testset: 26/26 groen.
