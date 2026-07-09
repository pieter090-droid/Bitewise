-- VOORSTEL — NOG NIET UITGEVOERD. Wacht op expliciet akkoord vóór
-- `supabase db push`. Dit bestand staat lokaal klaar zodat het voorstel
-- controleerbaar is, maar is niet tegen de live database gedraaid.
--
-- Batch 1 mapping-dekkingsverbetering. NIET meegenomen (expliciet
-- uitgesloten door de gebruiker): curry, pasta/rijst/aardappel, rauw
-- vlees/kip/vis, brede snoep-uitbreiding (zie apart Batch 2-voorstel in het
-- bijbehorende analyserapport, niet in deze migratie).
--
-- Alle wijzigingen zijn additief (raken alleen rijen waar swap_family nu
-- null is) BEHALVE de expliciete correctie van 6 al-bestaande, aantoonbaar
-- foutieve rijen (kaaskroket/ovenkroket die nu onder cheese_snacks/
-- crackers_rice_cakes vallen) — die correctie is bewust en apart benoemd.
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

-- Stap 1: snapshot van alle rijen die deze migratie mogelijk raakt, vóór
-- enige wijziging (permanente audit-snapshot, zelfde patroon als 0040/0047).
create table if not exists public._snapshot_0051_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  select barcode from public.products
  where name ~* 'kroket|frikandel|bitterbal|kaassouffl[ée]|bamischijf|nasischijf|loempia|\mnugget\M'
     or name ~* 'olie'
     or name ~* 'ijs'
     or name ~* 'rijstwafel|rijswafel|maiswafel'
     or name ~* 'protein.?powder|\mshake\M|creatine'
     or name ~* '\mpizza\M'
     or brand ~* '\mbueno\M|kit ?kat|\mtwix\M|\mlion\M|\mmars\M|snickers|bounty|knoppers|milky ?way|kinder country|kinder maxi'
);

-- Stap 2: nieuwe family `fried_snacks` in swap_family_mapping.
insert into public.swap_family_mapping
  (swap_family, category_cluster, snack_type, product_form, consumption_mode,
   secondary_consumption_modes, usage_context, related_families, is_swap_relevant_default)
values
  ('fried_snacks', 'hartig', 'frituursnack', 'fried_piece', 'heat_and_eat',
   '{}', array['snack'], array['meat_snacks','crisps_chips','popcorn'], true)
on conflict (swap_family) do update set
  category_cluster = excluded.category_cluster,
  snack_type = excluded.snack_type,
  product_form = excluded.product_form,
  consumption_mode = excluded.consumption_mode,
  usage_context = excluded.usage_context,
  related_families = excluded.related_families,
  is_swap_relevant_default = excluded.is_swap_relevant_default;

-- Reverse-relaties (zelfde symmetrie-aanpak als migratie 0036).
update public.swap_family_mapping set related_families = array_append(related_families, 'fried_snacks')
  where swap_family in ('meat_snacks','crisps_chips','popcorn') and not ('fried_snacks' = any(related_families));

-- Stap 3: compute_swap_family() additief uitbreiden. Elke toevoeging is
-- gemarkeerd met "-- BATCH1:". Niets aan de bestaande elsif-volgorde vóór
-- deze toevoegingen is gewijzigd, dus geen enkele bestaande, al-correcte
-- classificatie kan hierdoor omslaan (behalve de bewuste fried_snacks-
-- correctie, die in stap 5 los als UPDATE gebeurt, niet via deze functie).
create or replace function public.compute_swap_family(p_name text, p_category text, p_categories_tags text, p_pnns1 text, p_pnns2 text, p_brand text default null::text)
 returns text
 language plpgsql
 immutable
as $function$
declare
  n  text := coalesce(p_name, '');
  c  text := coalesce(p_category, '') || ' ' || coalesce(p_categories_tags, '');
  p1 text := coalesce(p_pnns1, '');
  p2 text := coalesce(p_pnns2, '');
  b  text := coalesce(p_brand, '');
  v_is_drink_named boolean;
  v_is_light_zero boolean;
begin
  v_is_drink_named := (n ~* '\mdrink\M|drank|drinkyoghurt|drinkyogur' or c ~* 'drinkable');
  v_is_light_zero  := (n ~* '\mzero\M|\mlight\M|suikervrij|no sugar|sugar.?free|\mdiet\M');

  if n ~* 'smeerkaas|cream cheese spread|roomkaas smeerbaar' then
    return 'savory_spreads';
  elsif n ~* 'pindakaas|peanut butter|amandelpasta|notenpasta|cashewpasta|hazelnootpasta|pistachepasta|pistachio paste' then
    return 'nut_butters';
  elsif n ~* 'hummus|houmous|humus\M' then
    return 'hummus_legume_spreads';
  elsif n ~* 'nutella|chocopasta|choco.?pasta' or c ~* 'chocolate.?spread|cocoa.and.hazelnut' then
    return 'chocolate_spreads';
  elsif n ~* '\mjam\M|confiture|marmelade|fruitspread|vruchtenspread|fruit spread' then
    return 'jams_fruit_spreads';
  elsif n ~* 'hagelslag' then
    return 'sweet_spreads_other';

  elsif n ~* 'eiwitreep|protein bar' or c ~* 'protein.?bar' then
    return 'protein_bars';
  elsif n ~* 'mueslireep|cerealreep|granolareep' or c ~* 'cereal.?bar' then
    return 'cereal_bars';
  elsif n ~* 'chocoladereep|candy bar' or c ~* 'chocolate.?bar' then
    return 'chocolate_bars';

  elsif c ~* 'pralines|bonbons|chocolates|filled.chocolates|liquorice|licorice' or p2 ~* 'chocolate'
        or n ~* 'bonbon|praline|\mmerci\M|salmiak' then
    return 'chocolate_confectionery';
  elsif n ~* 'drop\M|winegum|toffee|marshmallow|spekjes|schuimpjes|zuurtjes|\mlolly|fruittella|napoleon|venco|fruit roll' then
    return 'candy_sweets';

  -- BATCH1: gefrituurde/oven-snacks (kroket/frikandel/bitterbal/kaassoufflé/
  -- bamischijf/nasischijf/loempia/nuggets). Bewust vóór cheese_snacks en
  -- crackers_rice_cakes geplaatst, zodat een kaaskroket niet langer als
  -- kaasplak of cracker wordt geclassificeerd. Bare "kroket" (geen \m..\M)
  -- omdat het vaak samengesteld voorkomt (kaaskroket/rundvleeskroket).
  -- Uitsluitingen houden broodjes/wraps/maaltijden/salades/sauzen in hun
  -- eigen, al-correcte families.
  elsif n ~* 'kroket|frikandel|bitterbal|kaassouffl[ée]|bamischijf|nasischijf|loempia|\mnugget\M'
        and n !~* 'broodje|\mwrap\M|sandwich|maaltijd|kant.?en.?klaar|\msalade\M|\msaus\M' then
    return 'fried_snacks';

  elsif n ~* '\mijs\M|ice cream|sorbet|gelato' or p2 ~* 'ice cream'
        -- BATCH1: compound-fix zodat "roomijs"/"slagroomijs"/"citroenijs"/
        -- "vruchtenijs" ook matchen (geen los woord "ijs" in de naam).
        or (n ~* 'ijs' and n !~* 'ijsbergsla|amandelspijs|spijskoek|radijs|saucijs|parijs|anijs|ijsthee|rijst|prijs|wijze|vrijst') then
    return 'ice_cream_desserts';

  elsif n ~* '\msmoothie\M' then
    return 'smoothies';
  elsif n ~* 'havermelk|amandelmelk|sojamelk|kokosmelk|\moatly\M|\malpro\M|plantaardige melk|soja.?drink|haver.?drink|barista.{0,10}(haver|oat|soja|soy)|(haver|oat|soja|soy).{0,10}barista' then
    return 'plant_based_dairy';
  elsif n ~* 'yoghurt|yaourt|yogur|joghurt|skyr|kwark|quark'
        and not (v_is_drink_named or n ~* 'dressing|saus|sauce|\mdip\M') then
    return 'yoghurt_skyr_quark';
  elsif n ~* 'chocomel|karnemelk|milkshake|yogidrink|\mcafe au lait\M|caf[ée] au lait' or (v_is_drink_named and (p1 ~* 'dairy|milk' or n ~* 'melk|yoghurt|yogur')) then
    return 'dairy_drinks';
  elsif not v_is_drink_named
        and (c ~* 'tiramisu|dairy-desserts'
             or (n ~* 'pudding|mousse|\mvla\M|dessert' and (p1 ~* 'dairy|milk' or p2 ~* 'dairy|milk|dessert'))) then
    return 'dairy_desserts';

  elsif n ~* 'taart\M|\mgebak\M|cake\M|flap\M' then
    return 'cakes_pastries';
  elsif p2 ~* 'biscuits|cookies' or n ~* '\mkoek|koek\M|cookie|jan hagel|sprits|kletsmajoor|picolient|speculaas|\mkrans|biscuit' then
    return 'cookies_biscuits';
  elsif n ~* 'cracker|beschuit|rice cake|knackebrod'
        -- BATCH1: Nederlandse vocab-gaten (rijstwafel/rijswafel/maiswafel
        -- stonden nergens, alleen de Engelse "rice cake" was gedekt).
        or n ~* 'rijstwafel|rijswafel|maiswafel'
        or c ~* 'cracker' then
    return 'crackers_rice_cakes';

  elsif n ~* '\mgranola\M|muesli' then
    return 'granola_muesli';
  elsif p2 ~* 'breakfast cereal' or n ~* 'cornflakes|ontbijtgranen|cruesli' then
    return 'breakfast_cereals';
  elsif n ~* 'broodje|\mwrap\M|sandwich' then
    return 'sandwiches_wraps';
  elsif n ~* '\mbrood\M|croissant|stokbrood|bolletje|baguette' or p2 ~* '\mbread\M' then
    return 'bread_bakery';

  elsif n ~* 'droge worst|beef jerky|cabanossi|snackworst|biltong' then
    return 'meat_snacks';
  elsif n ~* '\mham\M|salami|cervelaat|rookvlees|\mpat[ée]\M|leverworst|kipfilet|achterham|vleeswaren|boterhamworst'
        or p2 ~* 'processed meat' then
    return 'cold_cuts';

  elsif n ~* 'popcorn' or c ~* 'popcorn' then
    return 'popcorn';
  elsif n ~* 'chips|crisps' or c ~* 'chips|crisps' then
    return 'crisps_chips';
  elsif n ~* 'olijven|\molive\M|olives' then
    return 'sauces_dips';
  elsif p2 ~* '\mcheese\M' or n ~* '\mkaas\M|\mcheese\M' then
    return 'cheese_snacks';

  elsif (n ~* 'boter\M|\mmargarine\M|\mhalvarine\M') and not (n ~* 'aardappel|frites|friet|krokett|croquett') then
    return 'butter_margarine';

  elsif n ~* 'bier|\mwijn\M|wodka|whisky|whiskey|\mrum\M|\mgin\M|likeur|prosecco|cava\M' or p1 ~* 'alcoholic' then
    return 'alcohol_drinks';

  elsif n ~* 'red bull|monster energy|\maa\M drink|energy ?drink|rockstar' then
    return 'energy_drinks';
  elsif n ~* 'isostar|gatorade|powerade|sportdrank|aquarius' then
    return 'sports_drinks';
  elsif v_is_light_zero and (n ~* '\mcola\M|frisdrank|\msoda\M|limonade|fanta|sprite|\m7up\M|tonic|bitter lemon|ice.?tea|rivella|sisi\M' or p2 ~* 'sweetened beverages') then
    return 'soft_drinks_light_zero';
  elsif n ~* '\mcola\M|frisdrank|\msoda\M|limonade|fanta|sprite|\m7up\M|tonic|bitter lemon|ice.?tea|rivella|sisi\M'
        or p2 ~* 'sweetened beverages' then
    return 'soft_drinks_regular';
  elsif n ~* '\msap\M|juice' or c ~* 'juice' then
    return 'fruit_juices';
  elsif n ~* 'koffie|\mcoffee\M|\mcafe\M|cappuccino|espresso|latte\M|\mthee\M|\mtea\M' or p2 ~* 'coffee and tea' then
    return 'hot_beverages';
  elsif (n ~* '\mwater\M|bronwater|mineraalwater' or p2 ~* 'waters and flavored waters')
        and not v_is_drink_named then
    return 'water';

  elsif (p2 ~* '\mnuts\M' or n ~* 'noten|zaden|amandelen|cashew|walnoot|hazelnoot|pistache') and not (n ~* 'pasta') then
    return 'nuts_seeds';

  elsif n ~* 'soep|\msoup\M' or p2 ~* '\msoup\M' then
    return 'soups';
  elsif (n ~* '\mdip\M|saus|sauce|dressing|streich' or p2 ~* 'sauce|dressing') and not (n ~* 'boter|butter|\molie\M|olive oil') then
    return 'sauces_dips';

  elsif n ~* '\mhoning\M|\mhoney\M|\msiroop\M|\mstroop\M|\msyrup\M|\magave\M|maple syrup|ahornsiroop' then
    return 'honey_syrups';

  elsif p2 ~* '\mfruits\M' and not v_is_drink_named then
    return 'fresh_fruit';
  elsif n ~* 'tomaten?\M|komkommer|worteltjes|wortel\M|\msla\M|paprika|\mui\M|uien\M|broccoli|spinazie|courgette|aubergine|\mprei\M|bloemkool|spruitjes|andijvie|\mboon\M|bonen\M|erwt|betteraves?\M|carottes?\M|oignons?\M' then
    return 'fresh_vegetables';

  elsif n ~* 'kant.?en.?klaar|magnetronmaaltijd|ovenschotel|maaltijdbox'
        -- BATCH1: kant-en-klare/oven/diepvries pizza's positief naar
        -- ready_meals. Sluit ingrediënt-achtige pizza-gerelateerde
        -- producten uit (saus/kruiden/deeg/bodem/meel/farina), en twee
        -- specifiek gecontroleerde randgevallen (Cheez Dippers Pizza is
        -- geen herkenbare kant-en-klare pizza, "Mélange"-producten bleken
        -- kruidenmixen).
        or (n ~* '\mpizza\M'
            and n !~* 'pizzasaus|pizza.?saus|pizzakruiden|pizza.?kruiden|pizzadeeg|pizza.?deeg|pizzabodem|pizza.?bodem|pizzameel|pizza.?meel|\mmeel\M|farina|dippers|m[ée]lange') then
    return 'ready_meals';
  elsif p1 ~* 'composite' or n ~* 'maaltijd|salade|\mmeal\M' then
    return 'meal_components';

  elsif n ~* 'eiwitpoeder|proteine ?poeder|\mwhey\M|supplement'
        -- BATCH1: Engelstalige sportvoeding-vocabulaire (protein powder/
        -- shake/creatine) was niet gedekt. Milkshake expliciet uitgesloten
        -- (blijft dairy_drinks, wordt daar al eerder in de keten gevangen,
        -- deze uitsluiting is een extra vangnet).
        or n ~* 'protein.?powder|\mshake\M|creatine' and n !~* '\mmilkshake\M' then
    return 'supplements_powders';

  -- Merk-vangnet: alleen als NIETS specifiekers hierboven al matchte (dus
  -- ook niet als bv. de naam toevallig "koffie" bevat -- die check komt al
  -- eerder aan bod). Alleen merken waarbij elke variant (ook suikervrij)
  -- gegarandeerd dezelfde swap_family heeft.
  elsif b ~* '\mred ?bull\M|\mmonster\M|\mrockstar\M|\mburn\M' then
    return 'energy_drinks';
  -- BATCH1: chocoladereep-merken. Puur additief op merknaam (products.brand,
  -- niet products.name), dus raakt UITSLUITEND producten die tot nu toe
  -- NIETS specifiekers matchten. Overschrijft dus nooit een bestaande
  -- classificatie (ook niet de inconsistente cookies_biscuits/
  -- chocolate_confectionery-varianten die al bestaan voor dezelfde merken --
  -- die blijven zoals ze zijn, deze regel corrigeert ze bewust niet).
  elsif b ~* '\mbueno\M|kit ?kat|\mtwix\M|\mlion\M|\mmars\M|snickers|bounty|knoppers|milky ?way|kinder country|kinder maxi' then
    return 'chocolate_bars';

  else
    return null;
  end if;
end $function$;

-- Stap 4: swap_family_rules-tabel bijwerken voor documentatie/audit-trail
-- (zelfde patroon als eerdere migraties -- deze tabel wordt niet dynamisch
-- uitgevoerd, is puur menselijk-leesbare documentatie van de huidige regels).
insert into public.swap_family_rules
  (priority, classification_status, swap_family, name_pattern, exclude_patterns, confidence, rationale)
values
  (45, 'classified', 'fried_snacks',
   'kroket|frikandel|bitterbal|kaassouffl[ée]|bamischijf|nasischijf|loempia|\mnugget\M',
   array['broodje','\mwrap\M','sandwich','maaltijd','kant.?en.?klaar','\msalade\M','\msaus\M'],
   0.70, 'Batch 1: nieuwe familie voor gefrituurde/oven-snacks, vóór dit ontbrak elke mapping hiervoor')
on conflict do nothing;

-- Stap 5: retroactieve toepassing op BESTAANDE producten. Alleen op rijen
-- waar swap_family nu null is (additief), BEHALVE de expliciete correctie
-- hieronder (bewust, want aantoonbaar fout).

-- 5a. Correctie: expliciete barcodelijst (niet een open patroonmatch tegen
-- de live data -- de fried_snacks-pattern hierboven diende alleen om deze
-- 6 te VINDEN tijdens de dry-run; de daadwerkelijke UPDATE is bewust op
-- exacte barcodes geankerd, zodat geen enkele andere, niet-vooraf-beoordeelde
-- rij per ongeluk meegecorrigeerd kan worden). Onderbouwing per rij: alle 6
-- stonden op product_form 'cheese_block' (kaaskroket/kaasbitterbal/
-- kaassoufflé) of 'cookie' (Ovenkroket) -- geen van beide een plausibele
-- vorm voor een gefrituurd/oven-snackproduct, en zonder correctie zouden ze
-- kaasplakjes/koekjes als SnackSwap-kandidaat krijgen i.p.v. andere
-- frituursnacks.
update public.product_features pf set
  swap_family = 'fried_snacks',
  classification_reason = 'batch1_fried_snacks_correction',
  classified_at = now()
where pf.barcode in (
  '8718452908783', -- Jumbo Kaas Bitterballen Airfryer & Oven Wapenaer 10 Stuks (was cheese_snacks/cheese_block)
  '8718452908790', -- Jumbo Kaas Kroketten Airfryer & Oven Wapenaer 4 Stuks (was cheese_snacks/cheese_block)
  '8710400391555', -- Kaassouffle (was cheese_snacks/cheese_block)
  '8719009382018', -- Mini Goudse Kaas Bitterballen (was cheese_snacks/cheese_block)
  '20087012',       -- Oven bitterballen met oude kaas en bier (was cheese_snacks/cheese_block)
  '8718906703322'   -- Ovenkroket (was crackers_rice_cakes/cookie)
);

-- 5b. Additief: alle huidige nul-rijen die nu matchen op de nieuwe/verbrede
-- patronen. Zet alleen swap_family + audit-reden; classification_status
-- wordt in stap 6 apart, expliciet gezet (deze UPDATE triggert niet de
-- live-trigger uit 0050, want die vuurt alleen op INSERT/UPDATE van
-- `products` zelf, niet op een directe UPDATE van `product_features`).
with newly_classified as (
  select p.barcode,
    case
      when p.name ~* 'kroket|frikandel|bitterbal|kaassouffl[ée]|bamischijf|nasischijf|loempia|\mnugget\M'
           and p.name !~* 'broodje|\mwrap\M|sandwich|maaltijd|kant.?en.?klaar|\msalade\M|\msaus\M'
        then 'fried_snacks'
      when p.name ~* 'olie'
           and p.name !~* 'in\s*\d*%?\s*(olie|oil)|artisjok|gedroogde tomaten|tonijn in|tuna.{0,3}in|ansjovis|sardientjes|vis in|groente(n)? in|pesto|marinade|maaltijd.*olie|zonnebloemolie in|packed in oil|grissini|cracker|beschuit|chips|crisps'
        then 'cooking_oils_fats'
      when p.name ~* 'ijs'
           and p.name !~* 'ijsbergsla|amandelspijs|spijskoek|radijs|saucijs|parijs|anijs|ijsthee|rijst|prijs|wijze|vrijst'
        then 'ice_cream_desserts'
      when p.name ~* 'rijstwafel|rijswafel|maiswafel' then 'crackers_rice_cakes'
      when p.name ~* 'protein.?powder|\mshake\M|creatine' and p.name !~* '\mmilkshake\M' then 'supplements_powders'
      when p.name ~* '\mpizza\M'
           and p.name !~* 'pizzasaus|pizza.?saus|pizzakruiden|pizza.?kruiden|pizzadeeg|pizza.?deeg|pizzabodem|pizza.?bodem|pizzameel|pizza.?meel|\mmeel\M|farina|dippers|m[ée]lange'
        then 'ready_meals'
      -- BATCH1: merkvangnet, laagste prioriteit (alleen als niets
      -- specifiekers matchte) -- op products.brand, niet products.name.
      -- Dry-run bevestigd: raakt exact 1 bestaand product (barcode
      -- 8000500448052, brand "Kinder Bueno", ondanks de typo "buno" in de
      -- naam zelf) en géén enkel ander product.
      when p.brand ~* '\mbueno\M|kit ?kat|\mtwix\M|\mlion\M|\mmars\M|snickers|bounty|knoppers|milky ?way|kinder country|kinder maxi'
        then 'chocolate_bars'
      else null
    end as new_family
  from public.products p
  join public.product_features pf on pf.barcode = p.barcode
  where pf.swap_family is null
)
update public.product_features pf set
  swap_family = nc.new_family,
  classification_reason = 'batch1_additive_mapping'
from newly_classified nc
where pf.barcode = nc.barcode and nc.new_family is not null;

-- Stap 6: status-backfill, uitsluitend voor de rijen die deze migratie
-- zelf zojuist heeft aangeraakt (herkenbaar aan classification_reason).
-- Zelfde velden/waarden-stijl als de live-trigger uit 0050, zodat Batch 1
-- ook zonder een nieuwe scan direct werkende swap-kandidaten oplevert.
-- Raakt GEEN andere rijen -- classification_status was voor deze exacte
-- rijen al bevestigd null (stap 5a corrigeerde alleen swap_family van
-- al-classified rijen, stap 5b raakte alleen swap_family-is-null rijen).
update public.product_features pf set
  classification_status = 'classified',
  classified_at = now(),
  classification_confidence = 0.70,
  mapping_version = 1
where pf.classification_reason in ('batch1_fried_snacks_correction', 'batch1_additive_mapping')
  and pf.classification_status is null;

-- POSTFLIGHT (read-only, uit te voeren na deze migratie):
-- select swap_family, count(*) from product_features where classification_reason in ('batch1_fried_snacks_correction','batch1_additive_mapping') group by 1;
--   -- verwacht: fried_snacks ~61 (55 nieuw + 6 correctie), cooking_oils_fats ~48, ice_cream_desserts ~22,
--   -- crackers_rice_cakes ~27, supplements_powders ~24, ready_meals ~28-31
-- select count(*) from product_features_resolved; -- moet exact gelijk blijven aan aantal products
-- select count(*) from product_features where swap_family is not null and classification_status is null;
--   -- moet 0 blijven: stap 6 hierboven zet classification_status al direct voor alle door deze
--   -- migratie geraakte rijen, dus Batch 1 werkt zelfstandig, ook zonder dat 0050 al live is
-- select count(*) from product_features_resolved where is_swap_relevant=true and swap_family='fried_snacks';
--   -- moet gelijk zijn aan de fried_snacks-telling hierboven (bevestigt dat is_swap_relevant_default=true
--   -- op de nieuwe mapping-rij correct doorwerkt via de resolved view)
-- select count(*) from swap_family_mapping where swap_family='fried_snacks'; -- moet 1 zijn

-- ROLLBACK (exact, via de snapshot-tabel):
-- update public.product_features pf set
--   swap_family = s.swap_family, is_swap_relevant = s.is_swap_relevant,
--   classification_status = s.classification_status, classification_confidence = s.classification_confidence,
--   classification_reason = s.classification_reason, matched_rule_id = s.matched_rule_id,
--   rule_version = s.rule_version, mapping_version = s.mapping_version,
--   source_fingerprint = s.source_fingerprint, classified_at = s.classified_at
-- from public._snapshot_0051_before s
-- where pf.barcode = s.barcode;
-- delete from public.swap_family_mapping where swap_family = 'fried_snacks';
-- delete from public.swap_family_rules where rationale like 'Batch 1:%';
-- create or replace function public.compute_swap_family(...) <exacte vorige definitie>;
-- drop table public._snapshot_0051_before; -- pas na bevestigde, succesvolle rollback
