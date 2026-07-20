-- 0112 — fase 7C: conservatieve sluiting van duidelijke overige
-- supermarktclusters. Products blijft raw; alleen afgeleide features wijzigen.

begin;
set local statement_timeout = '10min';

create temporary table audit7_0112_decisions (
  barcode text primary key,
  target_family text not null,
  decision_reason text not null
) on commit drop;

with candidates as (
  select
    p.barcode,
    lower(' ' || coalesce(p.name, '') || ' ' || coalesce(p.brand, '') || ' ') as n
  from public.products p
  join public.product_features pf using (barcode)
  where pf.classification_status = 'review_required'
    and pf.classification_reason like 'audit7_0110_pending%'
), decisions as (
  select
    barcode,
    case
      when n ~* '\m(vitamine|multivit|magnesium|collageen|creatine|whey|prote[iï]nepoeder|protein powder|supplement)'
       and n !~* '(drink|shot|gumm)'
        then 'supplements_powders'
      when n ~* '\m(kristalsuiker|rietsuiker|poedersuiker|puderzucker|maizena|ma[ïi]smeel|amandelmeel|tarwebloem|bloem|bakpoeder|cocoa powder|cacaopoeder|bakmix|sprinkles)\M'
        then 'baking_ingredients_non_swap'
      when n ~* '\m(olijfolie|zonnebloemolie|kokosolie|frituurolie|bak.?en.?braad|sesamolie)\M'
        then 'fats_oils_non_swap'
      when n ~* '\m(yoghurt|yogurt|kwark|skyr)\M'
        then 'yoghurt_skyr_quark'
      when n ~* '\m(vla|pudding|mousse)\M'
       and n !~* '(kloppudding|poeder|mix|cakeblokjes)'
        then 'dairy_desserts'
      when n ~* '\m(gouda|kaas|cheese|mozzarella|brie|camembert|feta|halloumi)\M'
       and n !~* '(kaasstengel|kaasburger|cheesecake|plantaardig|vegan|saus|bread|sticks|cr[eè]me|orzo)'
        then 'cheese_snacks'
      when n ~* '\m(melk|milk|karnemelk|chocomel|yoghurtdrink)\M'
       and n !~* '(chocolade|vlokken|koek|cake|poeder|condens|filling)'
        then 'dairy_drinks'
      when n ~* '\m(pistolet|bagel|stokbrood|ciabatta|krentenbol|rozijnenbol|brood)\M'
       and n !~* '(beleg|vlokken|pasta|burger|sandwich)'
        then 'bread_bakery'
      when n ~* '\m(cracker|kn[aä]ckebr[oö]d|rijstwafel|ma[iï]swafel|tarwewafel)'
        then 'crackers_rice_cakes'
      when n ~* '\mpopcorn\M'
        then 'popcorn'
      when n ~* '\m(chips|crisps|nacho chips|tortilla chips)\M'
        then 'crisps_chips'
      when n ~* '\m(havermout|porridge|cornflakes)\M'
        then 'breakfast_cereals'
      when n ~* '\m(muesli|granola)\M'
        then 'granola_muesli'
      when n ~* '\m(pindakaas|peanut butter)\M'
        then 'nut_butters'
      when n ~* '\m(jam|marmelade|fruitspread)\M'
        then 'jams_fruit_spreads'
      when n ~* '\m(honing|honey|agavesiroop|maple syrup)\M'
        then 'honey_syrups'
      when n ~* '\m(hagelslag|vruchtenhagel)\M'
        or (n ~* '\mvlokken\M' and n !~* '\mchili\M')
        then 'sweet_spreads_other'
      when n ~* '\m(vlaai|muffin|brownie|cupcake|donut|doughnut|cake)\M'
       and n !~* '(mix|pudding cakeblokjes|m[üu]llermilk)'
        then 'cakes_pastries'
      when n ~* '\msnoep mix\M'
        then 'candy_sweets'
      when n ~* '\m(ijs|ice cream|gelato|sorbet)\M'
        then 'ice_cream_desserts'
      when n ~* '\m(sap|juice)\M'
       and n !~* '(citroensap|limoensap)'
        then 'fruit_juices'
      when n ~* '\m(kombucha|ginger beer|frisdrank|lemonade|limonade)\M'
        then 'soft_drinks_regular'
      when n ~* '\m(skuumkoppe|0\.0 beer)\M'
        then 'alcohol_drinks'
      else null
    end as target_family
  from candidates
)
insert into audit7_0112_decisions (barcode, target_family, decision_reason)
select barcode, target_family, 'naam/merk bewijst productvorm: ' || target_family
from decisions
where target_family is not null;

create table if not exists public._snapshot_0112_clusters_before as
select pf.*, p.name, p.brand, d.target_family, d.decision_reason
from audit7_0112_decisions d
join public.product_features pf using (barcode)
join public.products p using (barcode);

do $preflight$
declare
  v_targets integer;
  v_unknown integer;
begin
  select count(*) into v_targets from audit7_0112_decisions;
  if v_targets < 50 then
    raise exception '0112 verwacht minimaal 50 veilige targets, gevonden %', v_targets;
  end if;
  select count(*) into v_unknown
  from audit7_0112_decisions d
  left join public.swap_family_mapping m on m.swap_family = d.target_family
  where m.swap_family is null;
  if v_unknown <> 0 then
    raise exception '0112 bevat % onbekende doelfamilies', v_unknown;
  end if;
end
$preflight$;

update public.product_features pf
set swap_family = m.swap_family,
    category_cluster = m.category_cluster,
    snack_type = m.snack_type,
    product_form = m.product_form,
    consumption_mode = m.consumption_mode,
    secondary_consumption_modes = m.secondary_consumption_modes,
    usage_context = m.usage_context,
    is_swap_relevant = m.is_swap_relevant_default,
    swap_relevance_reason = 'audit7_0112: ' || d.decision_reason,
    classification_status = 'classified',
    classification_confidence = 0.92,
    classification_reason = 'audit7_0112_classified: ' || d.target_family,
    classified_at = now(),
    mapping_version = coalesce(pf.mapping_version, 1),
    is_sweet = coalesce(pf.is_sweet, defs.d_is_sweet),
    is_salty = coalesce(pf.is_salty, defs.d_is_salty),
    is_crunchy = coalesce(pf.is_crunchy, defs.d_is_crunchy),
    taste_profile = case when coalesce(cardinality(pf.taste_profile), 0) = 0
      then coalesce(defs.d_taste, pf.taste_profile, '{}'::text[]) else pf.taste_profile end,
    texture_profile = case when coalesce(cardinality(pf.texture_profile), 0) = 0
      then coalesce(defs.d_texture, pf.texture_profile, '{}'::text[]) else pf.texture_profile end,
    use_moment = case when coalesce(cardinality(pf.use_moment), 0) = 0
      then coalesce(defs.d_moment, pf.use_moment, '{}'::text[]) else pf.use_moment end,
    updated_at = now()
from audit7_0112_decisions d
join public.swap_family_mapping m on m.swap_family = d.target_family
left join public.swap_family_profile_defaults defs on defs.swap_family = d.target_family
where pf.barcode = d.barcode;

refresh materialized view public.catalog_classification_audit;

do $postflight$
declare
  v_bad integer;
begin
  select count(*) into v_bad
  from public.product_features pf
  join public._snapshot_0112_clusters_before s using (barcode)
  where pf.classification_status is distinct from 'classified'
     or pf.swap_family is distinct from s.target_family;
  if v_bad <> 0 then
    raise exception '0112 postflight: % targets hebben een ongeldige eindstatus', v_bad;
  end if;
  select count(*) into v_bad
  from public.catalog_classification_audit
  where audit_bucket like 'invalid_%';
  if v_bad <> 0 then
    raise exception '0112 postflight: % harde auditinvarianten falen', v_bad;
  end if;
end
$postflight$;

commit;
