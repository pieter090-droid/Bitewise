-- VOORSTEL — NOG NIET UITGEVOERD. Wacht op expliciet akkoord vóór
-- `supabase db push`. Dit bestand staat lokaal klaar zodat het voorstel
-- controleerbaar is, maar is niet tegen de live database gedraaid.
--
-- Batch 2: snoep/gummies-dekking. NIET meegenomen (expliciet uitgesloten):
-- brede mint/pepermunt-regel, suikervrij-snoep als aparte regel,
-- chocolade/Bueno (al gedaan in Batch 1), curry/sauzen,
-- maaltijd/pasta/rijst/aardappel, rauw vlees/kip/vis, oranje cleanup.
--
-- Alles is additief (raakt alleen rijen waar swap_family nu null is)
-- BEHALVE de ene expliciete, barcode-geankerde correctie van "Haribo happy
-- cola" (zie stap 5) — die is bewust en apart onderbouwd.
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

-- Stap 1: snapshot van alle rijen die deze migratie mogelijk raakt, vóór
-- enige wijziging (permanente audit-snapshot, zelfde patroon als 0040/0051).
create table if not exists public._snapshot_0052_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  select barcode from public.products
  where name ~* 'gummy|gummies|wine ?gums?|fruit ?gums?|liquorice|licorice'
     or brand ~* '\mharibo\M'
     or barcode = '4001686315613' -- Haribo happy cola, expliciete correctie
);

-- Stap 2 + 3: compute_swap_family() additief uitbreiden. De bestaande
-- candy_sweets-tak krijgt gummy/wine gum/fruit gum/liquorice/licorice
-- toegevoegd (met uitsluiting voor vitamine/cbd/hemp/supplement-producten,
-- zodat bv. "Vitamines gummies" en "Premium Hemp Cbd Gummies" hier NIET
-- als snoep terechtkomen). Daarnaast een apart Haribo-merkvangnet, zelfde
-- tier/mechaniek als het Bueno-vangnet uit migratie 0051 (alleen als niets
-- specifiekers al matchte). Geen nieuwe family: candy_sweets is qua
-- smaak/textuur/gebruik al de juiste, bestaande familie voor gummies
-- (bevat al drop/winegum/toffee/marshmallow/zuurtjes).
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
  elsif (n ~* 'drop\M|winegum|toffee|marshmallow|spekjes|schuimpjes|zuurtjes|\mlolly|fruittella|napoleon|venco|fruit roll'
         -- BATCH2: gummies/wine gum/fruit gum/liquorice/licorice als naam,
         -- additief aan de bestaande candy_sweets-tak.
         or n ~* 'gummy|gummies|wine ?gums?|fruit ?gums?|liquorice|licorice')
        and n !~* 'vitamine|\mcbd\M|\mhemp\M|supplement' then
    return 'candy_sweets';

  elsif n ~* '\mijs\M|ice cream|sorbet|gelato' or p2 ~* 'ice cream'
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

  elsif n ~* 'kroket|frikandel|bitterbal|kaassouffl[ée]|bamischijf|nasischijf|loempia|\mnugget\M'
        and n !~* 'broodje|\mwrap\M|sandwich|maaltijd|kant.?en.?klaar|\msalade\M|\msaus\M' then
    return 'fried_snacks';

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
        or (n ~* '\mpizza\M'
            and n !~* 'pizzasaus|pizza.?saus|pizzakruiden|pizza.?kruiden|pizzadeeg|pizza.?deeg|pizzabodem|pizza.?bodem|pizzameel|pizza.?meel|\mmeel\M|farina|dippers|m[ée]lange') then
    return 'ready_meals';
  elsif p1 ~* 'composite' or n ~* 'maaltijd|salade|\mmeal\M' then
    return 'meal_components';

  elsif n ~* 'eiwitpoeder|proteine ?poeder|\mwhey\M|supplement'
        or n ~* 'protein.?powder|\mshake\M|creatine' and n !~* '\mmilkshake\M' then
    return 'supplements_powders';

  -- Merk-vangnet: alleen als NIETS specifiekers hierboven al matchte (dus
  -- ook niet als bv. de naam toevallig "koffie" bevat -- die check komt al
  -- eerder aan bod). Alleen merken waarbij elke variant (ook suikervrij)
  -- gegarandeerd dezelfde swap_family heeft.
  elsif b ~* '\mred ?bull\M|\mmonster\M|\mrockstar\M|\mburn\M' then
    return 'energy_drinks';
  elsif b ~* '\mbueno\M|kit ?kat|\mtwix\M|\mlion\M|\mmars\M|snickers|bounty|knoppers|milky ?way|kinder country|kinder maxi' then
    return 'chocolate_bars';
  -- BATCH2: Haribo-merkvangnet, zelfde tier/mechaniek. Haribo is uitsluitend
  -- een snoepmerk, dus dit is veilig zonder verder onderscheid.
  elsif b ~* '\mharibo\M' then
    return 'candy_sweets';

  else
    return null;
  end if;
end $function$;

-- Stap 4: swap_family_rules-tabel bijwerken voor documentatie/audit-trail.
insert into public.swap_family_rules
  (priority, classification_status, swap_family, name_pattern, exclude_patterns, confidence, rationale)
values
  (46, 'classified', 'candy_sweets',
   'gummy|gummies|wine ?gums?|fruit ?gums?|liquorice|licorice',
   array['vitamine','\mcbd\M','\mhemp\M','supplement'],
   0.70, 'Batch 2: gummies/wine gum/fruit gum/liquorice als Engelstalig/vocab-gat additief aan bestaande candy_sweets-tak toegevoegd')
on conflict do nothing;

-- Stap 5: expliciete, barcode-geankerde correctie -- "Haribo happy cola",
-- barcode 4001686315613. Vóór correctie: swap_family='soft_drinks_regular',
-- kcal_100g=343.00, sugar_100g=46.00. Onderbouwing: (1) Haribo-product,
-- brand bevestigt snoepfabrikant; (2) voedingsprofiel (343 kcal/100g,
-- 46g suiker/100g) is volstrekt niet consistent met een frisdrank
-- (frisdrank ligt typisch rond 40 kcal/100ml, 10g suiker/100ml) maar wel
-- met snoep; (3) de fout is aantoonbaar veroorzaakt doordat de productnaam
-- het woord "cola" bevat en dat eerder in de keten (soft_drinks_regular)
-- werd gevangen vóórdat een specifiekere candy-regel dit kon voorkomen.
-- Dit is een expliciete, op exacte barcode geankerde correctie -- GEEN
-- brede cola-uitsluiting of -herclassificatie, en raakt geen enkel ander
-- cola-product.
update public.product_features pf set
  swap_family = 'candy_sweets',
  classification_reason = 'batch2_haribo_happy_cola_correction',
  classified_at = now()
where pf.barcode = '4001686315613';

-- Stap 6: retroactieve toepassing op bestaande producten. Alleen op rijen
-- waar swap_family nu null is (additief) -- de Haribo Happy Cola-correctie
-- in stap 5 is al apart gebeurd en wordt hier niet nogmaals geraakt.
with newly_classified as (
  select p.barcode,
    case
      when (p.name ~* 'drop\M|winegum|toffee|marshmallow|spekjes|schuimpjes|zuurtjes|\mlolly|fruittella|napoleon|venco|fruit roll|gummy|gummies|wine ?gums?|fruit ?gums?|liquorice|licorice')
           and p.name !~* 'vitamine|\mcbd\M|\mhemp\M|supplement'
        then 'candy_sweets'
      when p.brand ~* '\mharibo\M' then 'candy_sweets'
      else null
    end as new_family
  from public.products p
  join public.product_features pf on pf.barcode = p.barcode
  where pf.swap_family is null
)
update public.product_features pf set
  swap_family = nc.new_family,
  classification_reason = 'batch2_candy_gummies_additive'
from newly_classified nc
where pf.barcode = nc.barcode and nc.new_family is not null;

-- Stap 7: status-backfill, uitsluitend voor de rijen die deze migratie
-- zelf zojuist heeft aangeraakt (herkenbaar aan classification_reason).
-- Zelfde stijl als 0051. Raakt geen andere rijen.
update public.product_features pf set
  classification_status = 'classified',
  classified_at = now(),
  classification_confidence = 0.70,
  mapping_version = 1
where pf.classification_reason in ('batch2_candy_gummies_additive', 'batch2_haribo_happy_cola_correction')
  and pf.classification_status is null;

-- POSTFLIGHT (read-only, uit te voeren na deze migratie):
-- select swap_family, classification_reason, count(*) from product_features
--   where classification_reason in ('batch2_candy_gummies_additive','batch2_haribo_happy_cola_correction')
--   group by 1,2;
--   -- verwacht: candy_sweets/batch2_candy_gummies_additive ~16, candy_sweets/batch2_haribo_happy_cola_correction 1
-- select count(*) from product_features_resolved; -- moet exact gelijk blijven aan aantal products
-- select swap_family from product_features where barcode='4001686315613'; -- moet 'candy_sweets' zijn
-- select count(*) from product_features where swap_family is not null and classification_status is null; -- moet 0 blijven

-- ROLLBACK (exact, via de snapshot-tabel):
-- update public.product_features pf set
--   swap_family = s.swap_family, is_swap_relevant = s.is_swap_relevant,
--   classification_status = s.classification_status, classification_confidence = s.classification_confidence,
--   classification_reason = s.classification_reason, matched_rule_id = s.matched_rule_id,
--   rule_version = s.rule_version, mapping_version = s.mapping_version,
--   source_fingerprint = s.source_fingerprint, classified_at = s.classified_at
-- from public._snapshot_0052_before s
-- where pf.barcode = s.barcode;
-- delete from public.swap_family_rules where rationale like 'Batch 2:%';
-- create or replace function public.compute_swap_family(...) <exacte vorige definitie uit 0051>;
-- drop table public._snapshot_0052_before; -- pas na bevestigde, succesvolle rollback
