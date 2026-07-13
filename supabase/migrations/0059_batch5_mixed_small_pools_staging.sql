-- VOORSTEL — NOG NIET UITGEVOERD. Wacht op expliciet akkoord vóór
-- `supabase db push`. Batch 5, tweede deelbatch: handmatige (niet-API)
-- beoordeling van 162 producten uit de kleinere resterende pnns-pools
-- (Appetizers, Dairy desserts, Dressings and sauces, Fish and seafood-
-- restant, Legumes-restant, Milk and yogurt, Offals, Plant-based milk
-- substitutes, Salty and fatty products, Soups, Sweets, Teas, Waters).
--
-- Dit schrijft UITSLUITEND naar `swap_family_staging`. Geen wijziging aan
-- `product_features`/`product_features_resolved` -- coverage-cijfers
-- veranderen pas bij een aparte, gereviewde promotie-migratie.
--
-- Noemenswaardige bevindingen tijdens deze beoordeling:
--  - Milk and yogurt-pool is grotendeels room/crème fraîche/slagroom
--    (kookingrediënt), geen bestaande swap-familie hiervoor -- voorlopig
--    "dairy_cooking_cream_non_swap" (nieuwe naam, moet bij promotie nog
--    als swap_family_mapping-rij worden toegevoegd).
--  - Salty and fatty products-pool is bijna volledig ingelegde
--    augurken/kappertjes/zoetzuur -- condimenten, geen duidelijke
--    swap-kandidaat, daarom overwegend null.
--  - "Chokotoff" (bekend Belgisch toffee-snoepmerk) en "Zure Matten"
--    zijn duidelijke gemiste candy_sweets-items tussen de rauwe-suiker-
--    ruis in de Sweets-pool.
--  - Kombucha heeft geen exacte bestaande familie (geen hot_beverages,
--    geen soft_drinks) -- bewust null gelaten, niet gegokt.

insert into public.swap_family_staging
  (barcode, suggested_swap_family, confidence, reasoning, batch_label)
values
-- Appetizers
('8719587016367','meal_components',0.50,'Onigiri (rijstbal met vulling), kant-en-klaar snackgerecht.','batch5_mixed_pools'),
('8901552026413','fried_snacks',0.65,'Samosa is een gefrituurd/gebakken snackgerecht, vergelijkbaar met kroket/loempia.','batch5_mixed_pools'),
('8718907888981',null,0.30,'Tapas-schotel, te divers/onduidelijk qua samenstelling om te classificeren.','batch5_mixed_pools'),
('8710624671143',null,0.30,'Onduidelijk producttype ("Sticks gezouten"), kan divers zijn.','batch5_mixed_pools'),
-- Dairy desserts
('4100290079727','dairy_desserts',0.60,'Zuiveldessert met eiwitten, smaak salted caramel — herkenbaar zuiveldessert.','batch5_mixed_pools'),
-- Dressings and sauces
('8901047610578','sauces_dips',0.55,'Butter chicken saus (Kohinoor is een sausmerk), pnns bevestigt Dressings and sauces.','batch5_mixed_pools'),
-- Fish and seafood (restant, sushi expliciet uitgesloten in 0056)
('8719587113936','meal_components',0.50,'Sushi, kant-en-klaar gerecht, geen rauwe/conserven vis.','batch5_mixed_pools'),
('8713576271928','fish_seafood',0.55,'Zeewier voor sushi, grondstof, consistent met bestaande fish_seafood-precedent.','batch5_mixed_pools'),
('8717228618321','meal_components',0.45,'Sushi-blokjes, kant-en-klaar gerecht.','batch5_mixed_pools'),
-- Legumes (restant, expliciet uitgesloten in 0056 wegens mogelijk swap-relevant)
('8719587085097','legumes_non_swap',0.50,'Bonen-maismix, blik/conserven peulvruchtenmix.','batch5_mixed_pools'),
('5013665115090','nut_butters',0.50,'Whole Earth is een pindakaasmerk; "Crunch Dark roasted" wijst op grove pindakaas.','batch5_mixed_pools'),
('8719587349823','nuts_seeds',0.50,'Geroosterde/gekruide bonen-snack, vergelijkbaar met geroosterde noten/zaden-snacks.','batch5_mixed_pools'),
('8719587085066','fresh_vegetables',0.55,'Edamame, zelfde behandeling als de eerdere Vegetables-batch.','batch5_mixed_pools'),
('8718907037570','nuts_seeds',0.45,'Vermoedelijk geroosterde bonen-snackmix (Japanse stijl).','batch5_mixed_pools'),
('6956098200188','nuts_seeds',0.50,'Geroosterde erwten-snack, vergelijkbaar met geroosterde noten/zaden.','batch5_mixed_pools'),
-- Milk and yogurt
('8718265486447','dairy_cooking_cream_non_swap',0.55,'Verse slagroom, kookingrediënt zonder bestaande swap-familie.','batch5_mixed_pools'),
('8718166012158',null,0.35,'Lactosevrije halfvolle melk, geen duidelijke bestaande familie voor gewone drinkmelk.','batch5_mixed_pools'),
('8712800145257','dairy_cooking_cream_non_swap',0.55,'Slagroom, kookingrediënt.','batch5_mixed_pools'),
('4036300220530','dairy_cooking_cream_non_swap',0.55,'Crème fraîche, kookingrediënt.','batch5_mixed_pools'),
('8710624356859','dairy_cooking_cream_non_swap',0.55,'Crème fraîche, kookingrediënt.','batch5_mixed_pools'),
('4062800011743','dairy_cooking_cream_non_swap',0.50,'Lactosevrije kookroom.','batch5_mixed_pools'),
('8710400325239','dairy_cooking_cream_non_swap',0.55,'Crème fraîche, kookingrediënt.','batch5_mixed_pools'),
('8718452407187','dairy_cooking_cream_non_swap',0.55,'Crème fraîche light, kookingrediënt.','batch5_mixed_pools'),
('5410488140351','dairy_cooking_cream_non_swap',0.50,'Gezoete room, kookingrediënt.','batch5_mixed_pools'),
('8718265828001','fresh_fruit',0.40,'Naam suggereert verse granaatappel(pitjes), waarschijnlijk verkeerd gecategoriseerd onder Milk and yogurt.','batch5_mixed_pools'),
('8718907211352','dairy_cooking_cream_non_swap',0.55,'Geslagen room, kookingrediënt.','batch5_mixed_pools'),
('8716200085175',null,0.35,'Gecondenseerde melk, bak-/kookingrediënt, geen duidelijke bestaande familie.','batch5_mixed_pools'),
('4010318011267',null,0.35,'Lactosevrije houdbare melk, geen duidelijke bestaande familie.','batch5_mixed_pools'),
('7310865690685','yoghurt_skyr_quark',0.50,'Kefir, gefermenteerd zuivelproduct dicht bij yoghurt/kwark-categorie.','batch5_mixed_pools'),
('8718452237852','dairy_cooking_cream_non_swap',0.60,'"Kook zuivel", expliciet kookingrediënt.','batch5_mixed_pools'),
('8718452237869','dairy_cooking_cream_non_swap',0.60,'Kookroom, expliciet kookingrediënt.','batch5_mixed_pools'),
('8718907209229','dairy_cooking_cream_non_swap',0.60,'Kookroom houdbaar, expliciet kookingrediënt.','batch5_mixed_pools'),
('8718907490214','dairy_cooking_cream_non_swap',0.60,'"Kookzuivel", expliciet kookingrediënt.','batch5_mixed_pools'),
('30028777','dairy_cooking_cream_non_swap',0.55,'Volle room, kookingrediënt.','batch5_mixed_pools'),
('3451790196447','dairy_cooking_cream_non_swap',0.55,'Volle vloeibare room, kookingrediënt.','batch5_mixed_pools'),
('3451790196577','dairy_cooking_cream_non_swap',0.55,'Volle room voor bereiding, kookingrediënt.','batch5_mixed_pools'),
('3161910340130','dairy_cooking_cream_non_swap',0.55,'Lichte room, kookingrediënt.','batch5_mixed_pools'),
('3451790887260','dairy_cooking_cream_non_swap',0.55,'Lichte room, kookingrediënt.','batch5_mixed_pools'),
('8718989029883',null,0.35,'Lactosevrije halfvolle melk, geen duidelijke bestaande familie.','batch5_mixed_pools'),
('8718166012110',null,0.35,'Lactosevrije halfvolle melk, geen duidelijke bestaande familie.','batch5_mixed_pools'),
('8710624357900','dairy_cooking_cream_non_swap',0.55,'Verse slagroom, kookingrediënt.','batch5_mixed_pools'),
('4056489840657','dairy_cooking_cream_non_swap',0.55,'Crème fraîche, kookingrediënt.','batch5_mixed_pools'),
('4056489109594','dairy_cooking_cream_non_swap',0.50,'Room (Fins "kerma"), kookingrediënt.','batch5_mixed_pools'),
('4056489567714','dairy_cooking_cream_non_swap',0.50,'Slagroom in spuitbus, kookingrediënt/topping.','batch5_mixed_pools'),
('87153569','dairy_cooking_cream_non_swap',0.60,'"Room Culinair", expliciet kookingrediënt.','batch5_mixed_pools'),
('4333465097190','dairy_cooking_cream_non_swap',0.55,'Slagroom (Duits "Schlagsahne"), kookingrediënt.','batch5_mixed_pools'),
('4056489145479','dairy_cooking_cream_non_swap',0.55,'Slagroom, kookingrediënt.','batch5_mixed_pools'),
('8716376000910','dairy_cooking_cream_non_swap',0.55,'Slagroom, kookingrediënt.','batch5_mixed_pools'),
('8718907490184','dairy_cooking_cream_non_swap',0.55,'Slagroom 35% vet, kookingrediënt.','batch5_mixed_pools'),
('8710400079521','dairy_cooking_cream_non_swap',0.55,'Verse crème fraîche, kookingrediënt.','batch5_mixed_pools'),
('8710400079552','dairy_cooking_cream_non_swap',0.55,'Verse room, kookingrediënt.','batch5_mixed_pools'),
('8710624216443','dairy_cooking_cream_non_swap',0.55,'Verse slagroom, kookingrediënt.','batch5_mixed_pools'),
('8710400079545','dairy_cooking_cream_non_swap',0.50,'Verse sour cream, kookingrediënt.','batch5_mixed_pools'),
('8718452407170','dairy_cooking_cream_non_swap',0.50,'Verse zure room, kookingrediënt.','batch5_mixed_pools'),
('8710624356873','dairy_cooking_cream_non_swap',0.50,'Zure room, kookingrediënt.','batch5_mixed_pools'),
-- Offals
('8710889044300','raw_meat',0.50,'Rauwe bloedworst om te bakken, vergelijkbaar met raw_meat-precedent (zelf te bereiden vleesproduct).','batch5_mixed_pools'),
-- Plant-based milk substitutes
('8023678162360','plant_based_dairy',0.50,'Amandeldrink (Isola Bio), bestaande plant_based_dairy-familie, gemist door regex (geen "melk"/"drink"-woord in naam).','batch5_mixed_pools'),
('8718907824811','plant_based_dairy',0.70,'Amandeldrink, bevat "drink" maar mist blijkbaar door taal-variant in regex.','batch5_mixed_pools'),
('8718907291927','plant_based_dairy',0.65,'Barista amandel(drink), andere woordvolgorde dan bestaande regex.','batch5_mixed_pools'),
('8428532230078','plant_based_dairy',0.55,'Franse amandeldrink.','batch5_mixed_pools'),
('5411788003377','plant_based_dairy',0.55,'Franse sojadrink.','batch5_mixed_pools'),
('8718976020145','plant_based_dairy',0.50,'Kokosmelk-drink.','batch5_mixed_pools'),
('5411188109235','plant_based_dairy',0.65,'Biologische amandeldrink (Provamel).','batch5_mixed_pools'),
('5411188111252','plant_based_dairy',0.60,'Franse benaming voor sojamelk (Alpro).','batch5_mixed_pools'),
('8023678161387','plant_based_dairy',0.60,'Sojamelk (Isola Bio).','batch5_mixed_pools'),
('5411188513490','plant_based_dairy',0.65,'Sojadrink naturel (Provamel).','batch5_mixed_pools'),
-- Salty and fatty products (grotendeels ingelegde condimenten, geen duidelijke swap-kandidaat)
('8711271110887',null,0.35,'Zoetzure augurk — condiment, twijfelachtig swap-kandidaat.','batch5_mixed_pools'),
('8718452577385',null,0.35,'Zoetzure uitjes — condiment.','batch5_mixed_pools'),
('23076945',null,0.35,'Zoetzure uitjes — condiment.','batch5_mixed_pools'),
('8710605030594',null,0.35,'Atjar tjampoer, Indonesisch zoetzuur groentemengsel, condiment.','batch5_mixed_pools'),
('8712100648038',null,0.35,'Atjar tjampoer, condiment.','batch5_mixed_pools'),
('8710400008682',null,0.35,'Zure augurken, condiment.','batch5_mixed_pools'),
('8711271105005',null,0.35,'Augurkplakjes, condiment.','batch5_mixed_pools'),
('8718452686285',null,0.35,'Augurkblokjes zoetzuur, condiment.','batch5_mixed_pools'),
('8029689005146',null,0.35,'Kappertjes in azijn, condiment.','batch5_mixed_pools'),
('8711271110092',null,0.35,'Cornichons, condiment.','batch5_mixed_pools'),
('0887267000031','fresh_vegetables',0.55,'Kimchi, consistent met eerdere kimchi-classificatie in de Vegetables-batch.','batch5_mixed_pools'),
('4056489577997',null,0.30,'Sushi-gember, garnering, geen zelfstandig swap-product.','batch5_mixed_pools'),
('4012200417409',null,0.35,'Zoetzure augurk met honing, condiment.','batch5_mixed_pools'),
('8718907028271',null,0.35,'Ingelegde jalapeño, condiment/topping.','batch5_mixed_pools'),
('8718452965700',null,0.35,'Zoetzure augurken, condiment.','batch5_mixed_pools'),
('8410010876199',null,0.35,'Kappertjes, condiment.','batch5_mixed_pools'),
('8710400195214',null,0.35,'Kappertjes, condiment.','batch5_mixed_pools'),
('8710624289270',null,0.35,'Kappertjes, condiment.','batch5_mixed_pools'),
('8718452570270',null,0.35,'Kappertjes in azijn, condiment.','batch5_mixed_pools'),
('20004330',null,0.35,'Zoetzure augurken (Spaans), condiment.','batch5_mixed_pools'),
('8718531643178',null,0.30,'Ingelegde knoflook, condiment.','batch5_mixed_pools'),
('8711271109201',null,0.35,'Zoetzure augurken, condiment.','batch5_mixed_pools'),
('8710400168478',null,0.35,'Zoetzure cocktailaugurken, condiment.','batch5_mixed_pools'),
('8710400008675',null,0.35,'Zure augurken, condiment.','batch5_mixed_pools'),
('8718452407576',null,0.35,'Zure augurken, condiment.','batch5_mixed_pools'),
('8718452191093',null,0.35,'Fijne zure augurk, condiment.','batch5_mixed_pools'),
-- Soups
('8720182885463','soups',0.60,'Pompoensoep, herkenbaar soepproduct.','batch5_mixed_pools'),
('4048885045798',null,0.20,'Bouillon, bewust buiten scope gehouden.','batch5_mixed_pools'),
('3760052239533','soups',0.65,'Gazpacho, koude soep, herkenbaar soepproduct.','batch5_mixed_pools'),
('20645342','soups',0.65,'Gazpacho, koude soep.','batch5_mixed_pools'),
('8411026031008','soups',0.65,'Gazpacho, koude soep.','batch5_mixed_pools'),
('8720182118714','soups',0.60,'Tomatensoep met vermicelli, herkenbaar soepproduct.','batch5_mixed_pools'),
('3422440002623','soups',0.55,'Velouté (gladde groentesoep).','batch5_mixed_pools'),
('8718989023041',null,0.20,'Naam is een productcode ("NL 1104"), geen inhoudelijke informatie beschikbaar.','batch5_mixed_pools'),
('4030011420203','soups',0.45,'Vermoedelijk courgettesoep, lagere zekerheid door naam.','batch5_mixed_pools'),
('3760052232275','soups',0.60,'Soep, herkenbaar soepproduct.','batch5_mixed_pools'),
('3760052237126','soups',0.60,'Thaise soep.','batch5_mixed_pools'),
('3760052232299','soups',0.55,'Generieke naam "Soupes Bio", maar pnns bevestigt soep.','batch5_mixed_pools'),
('8718989020651','soups',0.45,'Vermoedelijk tomatensoep, generieke naam, lagere zekerheid.','batch5_mixed_pools'),
('8720182681904','soups',0.60,'Pompoenvelouté, herkenbaar soepproduct.','batch5_mixed_pools'),
-- Sweets (mix van honing/echte snoep en rauwe suiker/bakingrediënten)
('8710400136880','honey_syrups',0.70,'Vloeibare bloemenhoning, bestaande honey_syrups-familie.','batch5_mixed_pools'),
('7630486403045',null,0.35,'Suikervervanger (stevia-achtig), geen duidelijke bestaande familie.','batch5_mixed_pools'),
('8710437003223',null,0.35,'Basterdsuiker, bakingrediënt.','batch5_mixed_pools'),
('5400230201904',null,0.30,'Vermoedelijk suikerklontjes, onduidelijke naam.','batch5_mixed_pools'),
('8710624287276','honey_syrups',0.70,'Bloemenhonig, bestaande honey_syrups-familie.','batch5_mixed_pools'),
('7630030392443',null,0.35,'Suikersticks bij koffie, bakingrediënt-achtig.','batch5_mixed_pools'),
('4056489609438',null,0.35,'Bruine suiker, bakingrediënt.','batch5_mixed_pools'),
('3564700659076',null,0.35,'Rietsuiker, bakingrediënt.','batch5_mixed_pools'),
('5410081210154','candy_sweets',0.75,'Chokotoff is een bekend Belgisch toffee-snoepmerk, duidelijke swap-kandidaat gemist door regex.','batch5_mixed_pools'),
('8710267730504',null,0.30,'Kokosbloesemsuiker, bakingrediënt.','batch5_mixed_pools'),
('8720674320373',null,0.30,'Dextrose/druivensuiker, ingrediënt/supplement-achtig.','batch5_mixed_pools'),
('4388840220038','jams_fruit_spreads',0.50,'Vermoedelijk aardbeienjam (Duitse "Extra"-jam-aanduiding).','batch5_mixed_pools'),
('8721077490182','candy_sweets',0.55,'Keelpastilles/snoepjes met eucalyptus-mentholsmaak.','batch5_mixed_pools'),
('8710437008419',null,0.35,'Kaneelsuiker, bakingrediënt/topping.','batch5_mixed_pools'),
('8721425780040','honey_syrups',0.60,'Honing (lavendel), bestaande honey_syrups-familie.','batch5_mixed_pools'),
('5055738249950',null,0.30,'Kokosbloemsuiker, bakingrediënt.','batch5_mixed_pools'),
('8710400258490',null,0.30,'Kristalsuiker, bakingrediënt.','batch5_mixed_pools'),
('8710437002165',null,0.30,'Kristalsuiker, bakingrediënt.','batch5_mixed_pools'),
('8710437002172',null,0.30,'Kristalsuiker, bakingrediënt.','batch5_mixed_pools'),
('4056489372134',null,0.30,'Kristalsuiker, bakingrediënt.','batch5_mixed_pools'),
('8710437003216',null,0.30,'Lichte basterdsuiker, bakingrediënt.','batch5_mixed_pools'),
('8713406140363','honey_syrups',0.65,'Honing (Frans "Miel"), bestaande honey_syrups-familie.','batch5_mixed_pools'),
('8710497963284','candy_sweets',0.60,'Mini schuimsnoepjes ("spek"), herkenbaar snoepproduct.','batch5_mixed_pools'),
('8714384017531',null,0.30,'Palmsuiker, bakingrediënt.','batch5_mixed_pools'),
('8710437004626',null,0.30,'Poedersuiker, bakingrediënt.','batch5_mixed_pools'),
('4006040104384',null,0.30,'Rapadura rietsuiker, bakingrediënt.','batch5_mixed_pools'),
('8710437009621',null,0.30,'Ruwe rietsuiker, bakingrediënt.','batch5_mixed_pools'),
('20081065',null,0.15,'Quiche, totaal mismatch met pnns-categorie Sweets — waarschijnlijk datakwaliteitsprobleem.','batch5_mixed_pools'),
('3263850011313',null,0.30,'Rietsuikerpoeder, bakingrediënt.','batch5_mixed_pools'),
('8710437000031',null,0.30,'Suiker, bakingrediënt.','batch5_mixed_pools'),
('8710466004802',null,0.30,'Vanillesuiker, bakingrediënt.','batch5_mixed_pools'),
('8710391937343','candy_sweets',0.45,'Vermoedelijk chocolade-kokos strooisel/snoepproduct, onzeker.','batch5_mixed_pools'),
('8710437009461',null,0.30,'Kristalsuiker, bakingrediënt.','batch5_mixed_pools'),
('5701181875153','candy_sweets',0.60,'Zoethoutstok met cacaovulling, herkenbaar snoepproduct.','batch5_mixed_pools'),
('20559199','candy_sweets',0.70,'Zure matten, herkenbaar zuur snoepproduct.','batch5_mixed_pools'),
-- Teas and herbal teas and coffees
('8718781830069',null,0.30,'Onduidelijk producttype, merk "Aspire" niet herkend.','batch5_mixed_pools'),
('8718907437905','hot_beverages',0.55,'Avondthee-melange, herkenbaar theeproduct.','batch5_mixed_pools'),
('5600787049213',null,0.40,'Kombucha, gefermenteerde theedrank — geen exacte bestaande familie.','batch5_mixed_pools'),
('8711000287941','hot_beverages',0.55,'Thee met smaak gekarameliseerde peer (Pickwick).','batch5_mixed_pools'),
('26033440','hot_beverages',0.55,'Cafeïnevrije koffiecapsules.','batch5_mixed_pools'),
('4008137002948','hot_beverages',0.50,'Duitse afslank-/dieetthee.','batch5_mixed_pools'),
('8722700210641','hot_beverages',0.40,'Vermoedelijk muntthee, onzekere naam.','batch5_mixed_pools'),
('8718452126378',null,0.30,'Onduidelijk of dit thee of frisdrank is (appel-peer).','batch5_mixed_pools'),
('8711000870228','hot_beverages',0.50,'IJskoffie-variant, koffieproduct.','batch5_mixed_pools'),
('6095438053029',null,0.40,'Kombucha, geen exacte bestaande familie.','batch5_mixed_pools'),
('9008700193634',null,0.40,'Kombucha, geen exacte bestaande familie.','batch5_mixed_pools'),
('8711812411251',null,0.40,'Kombucha, geen exacte bestaande familie.','batch5_mixed_pools'),
('6009880817641','hot_beverages',0.45,'IJsthee (rooibos), lagere zekerheid door "glacé" (koud, mogelijk eerder soft_drinks).','batch5_mixed_pools'),
('8718452402861',null,0.30,'Onduidelijk of dit theekruid of losse specerij is (kaneel).','batch5_mixed_pools'),
('8051763003250','hot_beverages',0.55,'Perziksmaak thee (Italiaans).','batch5_mixed_pools'),
('5060229013941','hot_beverages',0.60,'Earl Grey thee, herkenbaar theeproduct.','batch5_mixed_pools'),
('8711812419660','hot_beverages',0.60,'Groene thee citroen.','batch5_mixed_pools'),
('8711812407995','hot_beverages',0.55,'Cafeïnevrije thee.','batch5_mixed_pools'),
('8718906948280',null,0.35,'Verse ijsthee, grensgeval tussen hot_beverages en soft_drinks.','batch5_mixed_pools'),
-- Waters and flavored waters
('8718452538010','soft_drinks_light_zero',0.55,'Vitaminewater zero, framboos-granaatappel smaak.','batch5_mixed_pools'),
('8718452461912','soft_drinks_regular',0.55,'Vitaminewater, framboos-granaatappel smaak.','batch5_mixed_pools');

-- POSTFLIGHT (read-only):
-- select count(*) from swap_family_staging where batch_label='batch5_mixed_pools'; -- moet 162 zijn
-- select coalesce(suggested_swap_family,'NULL') as fam, count(*), round(avg(confidence),2) from swap_family_staging where batch_label='batch5_mixed_pools' group by 1 order by 2 desc;
-- select count(*) from product_features; -- moet ongewijzigd blijven

-- ROLLBACK:
-- delete from public.swap_family_staging where batch_label='batch5_mixed_pools';
