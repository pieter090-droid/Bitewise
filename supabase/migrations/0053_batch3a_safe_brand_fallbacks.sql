-- VOORSTEL — NOG NIET UITGEVOERD. Wacht op expliciet akkoord vóór
-- `supabase db push`. Dit bestand staat lokaal klaar zodat het voorstel
-- controleerbaar is, maar is niet tegen de live database gedraaid.
--
-- Batch 3a: veilige merk-vangnetten, databasebreed onderzocht.
--
-- BELANGRIJK -- twee merken uit de oorspronkelijke scope zijn tijdens de
-- dry-run BEWUST UITGESLOTEN, met bewijs:
--
-- 1. Verstegen: ALLE ongeclassificeerde Verstegen-producten (20 stuks)
--    bleken bij inspectie kruiden/specerijen (basilicum, kruidnagel, gemalen
--    peper, "mix voor gehakt/kip/aardappel") -- GEEN ENKELE was een losse
--    saus/dip/dressing. Geen veilige subset over om mee te nemen.
--    Volledig buiten deze migratie gehouden, zoals gevraagd.
--
-- 2. Bio+: bleek bij inspectie een breed biologisch HUISMERK te zijn
--    (rijst, tofu, macaroni, honing, eieren, fruitspread, gerookte zalm,
--    kwark, mais wafels, pindakaas, volle melk -- minstens 8 verschillende
--    productcategorieën in een steekproef van 20). Dit is hetzelfde
--    risicoprofiel als AH/Jumbo/Plus (private-label, geen dominante
--    productlijn) -- "brand + producttype" bleek bij nader inzien niet
--    isoleerbaar tot een schone yoghurtlijn. Volledig buiten deze migratie
--    gehouden.
--
-- Bonduelle: WEL meegenomen, maar aantoonbaar verbreed portfolio
-- (maaltijdbowls/pasta/quinoa/bulgur/gerst/cuisinée-gerechten/wok/crème-
-- gerechten) -- daarom met expliciete exclusielijst teruggebracht van
-- ~120 naar 76 schone groente/peulvrucht-producten.
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

-- Stap 1: snapshot van alle rijen die deze migratie mogelijk raakt.
create table if not exists public._snapshot_0053_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where barcode in (
  select barcode from public.products
  where brand ~* '\mbonduelle\M'
     or brand ~* '\mmaoam\M|\mkatja\M|look.?o.?look|\mvenco\M|chupa.?chups'
);

-- Stap 2: compute_swap_family() additief uitbreiden met de merk-vangnetten,
-- op dezelfde plek/tier als de bestaande merk-vangnetten (energy drinks,
-- Bueno/chocolate_bars, Haribo/candy_sweets) -- alleen als niets
-- specifiekers al matchte, dus nooit een bestaande classificatie overschrijft.
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

  -- Merk-vangnet: alleen als NIETS specifiekers hierboven al matchte.
  elsif b ~* '\mred ?bull\M|\mmonster\M|\mrockstar\M|\mburn\M' then
    return 'energy_drinks';
  elsif b ~* '\mbueno\M|kit ?kat|\mtwix\M|\mlion\M|\mmars\M|snickers|bounty|knoppers|milky ?way|kinder country|kinder maxi' then
    return 'chocolate_bars';
  elsif b ~* '\mharibo\M' then
    return 'candy_sweets';
  -- BATCH3A: nieuwe merk-vangnetten. Candy-merken puur op brand (net als
  -- Haribo/Bueno) -- laag risico, uitsluitend zoetwarenfabrikanten.
  elsif b ~* '\mmaoam\M|\mkatja\M|look.?o.?look|\mvenco\M|chupa.?chups' then
    return 'candy_sweets';
  -- BATCH3A: Bonduelle -- brand + exclusielijst, NIET kaal op brand alleen
  -- (portfolio bevat ook maaltijdbowls/pasta/quinoa/bulgur/cuisinée-
  -- gerechten die geen "fresh_vegetables" zijn). Uitsluiting is bewust
  -- breed getest tijdens dry-run (zie migratiekop).
  elsif b ~* '\mbonduelle\M'
        and n !~* 'lunch bowl|\mpasta\M|quinoa|boulgour|\morge\M|\mriz\M|cuisin|\mwok\M|salteado|\mcurry\M|pur[ée]e|\mservice\M|minute|ligne|composée|composee|cr[eè]me|epeautre|épeautre' then
    return 'fresh_vegetables';

  else
    return null;
  end if;
end $function$;

-- Stap 3: retroactieve toepassing, alleen op rijen waar swap_family nu
-- null is (additief). Geen enkele bestaande classificatie wordt overschreven.
with newly_classified as (
  select p.barcode,
    case
      when p.brand ~* '\mmaoam\M|\mkatja\M|look.?o.?look|\mvenco\M|chupa.?chups' then 'candy_sweets'
      when p.brand ~* '\mbonduelle\M'
           and p.name !~* 'lunch bowl|\mpasta\M|quinoa|boulgour|\morge\M|\mriz\M|cuisin|\mwok\M|salteado|\mcurry\M|pur[ée]e|\mservice\M|minute|ligne|composée|composee|cr[eè]me|epeautre|épeautre'
        then 'fresh_vegetables'
      else null
    end as new_family
  from public.products p
  join public.product_features pf on pf.barcode = p.barcode
  where pf.swap_family is null
)
update public.product_features pf set
  swap_family = nc.new_family,
  classification_reason = 'batch3a_brand_fallback'
from newly_classified nc
where pf.barcode = nc.barcode and nc.new_family is not null;

-- Stap 4: status-backfill, uitsluitend voor de rijen die deze migratie
-- zelf zojuist heeft aangeraakt.
update public.product_features pf set
  classification_status = 'classified',
  classified_at = now(),
  classification_confidence = 0.70,
  mapping_version = 1
where pf.classification_reason = 'batch3a_brand_fallback'
  and pf.classification_status is null;

-- POSTFLIGHT (read-only, uit te voeren na deze migratie):
-- select swap_family, count(*) from product_features where classification_reason='batch3a_brand_fallback' group by 1;
--   -- verwacht: candy_sweets ~16, fresh_vegetables ~76 (totaal ~92)
-- select count(*) from product_features_resolved; -- moet exact gelijk blijven aan aantal products
-- select count(*) from product_features where swap_family is not null and classification_status is null; -- moet 0 blijven
-- select count(*) from product_features_resolved where brand ~* '\mverstegen\M' and swap_family is not null; -- moet 0 zijn (bewust buiten scope)
-- select count(*) from product_features_resolved where brand ~* '\mbio\+' and classification_reason='batch3a_brand_fallback'; -- moet 0 zijn (bewust buiten scope)

-- ROLLBACK (exact, via de snapshot-tabel):
-- update public.product_features pf set
--   swap_family = s.swap_family, is_swap_relevant = s.is_swap_relevant,
--   classification_status = s.classification_status, classification_confidence = s.classification_confidence,
--   classification_reason = s.classification_reason, matched_rule_id = s.matched_rule_id,
--   rule_version = s.rule_version, mapping_version = s.mapping_version,
--   source_fingerprint = s.source_fingerprint, classified_at = s.classified_at
-- from public._snapshot_0053_before s
-- where pf.barcode = s.barcode;
-- create or replace function public.compute_swap_family(...) <exacte vorige definitie uit 0052>;
-- drop table public._snapshot_0053_before; -- pas na bevestigde, succesvolle rollback
