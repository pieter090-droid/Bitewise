-- 0113 — fase 7C: gecontroleerde graan-, pluimvee- en proteïneclusters.
-- Samengestelde gerechten winnen altijd van losse ingrediëntwoorden.

begin;
set local statement_timeout = '10min';

create temporary table audit7_0113_decisions (
  barcode text primary key,
  target_family text not null
) on commit drop;

with candidates as (
  select p.barcode,
    lower(' ' || coalesce(p.name, '') || ' ' || coalesce(p.brand, '') || ' ') as n
  from public.products p
  join public.product_features pf using (barcode)
  where pf.classification_status = 'review_required'
    and pf.classification_reason like 'audit7_0110_pending%'
), decisions as (
  select barcode,
    case
      when n ~* '(protein|prote[iï]ne|eiwit).*(bar|reep)|\m(protein nut bar|protein cheat bar)\M'
        then 'protein_bars'
      when n ~* '(protein|prote[iï]ne).*(drink|iced coffee)|m[üu]llermilk protein'
        then 'dairy_drinks'
      when n ~* '(protein poeder|prote[iï]nepoeder|protein powder|pea protein|mass gainer|micellar casein|protein pulver|vegan eiwit|eiwit vegan|when protein|protein mango|vanille eiwit)'
        then 'supplements_powders'
      when n ~* '(protein pancakes|prote[iï]ne pannenkoeken|protein waffle)'
        then 'cakes_pastries'
      when n ~* 'protein bowl'
        then 'ready_meals'
      when n ~* 'eiwit rijstpudding'
        then 'dairy_desserts'
      when n ~* '(spaghetti bolognese|pasta bolognese|pasta beef|pasta paddenstoel|penne alla norma|rigatoni carbonara|penne arabiata|penne arrabbiata|pasta kip|pasta chicken|pasta tonijn|orzo feta|comfort bowl.*orzo|tomaat orzo|gehaktbal pasta|macaroni teriyaki|spaghetti alla carbonara|goelash met rijst|rijst met kipshoarma)'
        then 'ready_meals'
      when n ~* '\mbapoa\M'
        then 'sandwiches_wraps'
      when n ~* '(gyoza|cordon bleu|crispy chicken|chicken tender|kip krokant|kip borrelhap|gepaneerde kip ballet|chicken spring roll|karaage|kara age)'
        then 'fried_snacks'
      when n ~* '(kip.kerrie|zoete kip sesam)' and n !~* 'verspakket'
        then 'savory_spreads'
      when n ~* '(kalkoen filet beleg|gerookte kalkoen|gerookte kip)'
        then 'cold_cuts'
      when n ~* '(roast chicken|gegrilde kip|gegaarde.*kip|kip.*gegaard|chicken teriyaki|kip sate|kip koreaanse stijl|bbq chicken|sticky chicken)'
        then 'meal_components'
      when n ~* '\m(kip|chicken|kalkoen|turkey)\M'
       and n ~* '(gekruid|kebab|brochette|reepjes|wings?|wing|boomstam|chipolata|gourmet lapjes|piri piri|shoarma|filet|dij|bout)'
       and n !~* '(roast|gerookt|gegrild|gegaard|krokant|crispy|tender|sate|teriyaki|salad|bowl|pasta|wrap|wereldgerecht|verspakket|portugese|xxl nutrition|tam doyum|worst)'
        then 'raw_poultry'
      when n ~* '\m(basmati|zilvervlies rijst|long rice|pandan rijst|witte rijst|brown rice|sushi rice|macaroni|spaghetti|penne|orzo|couscous|pasta tricolore|glutenvrije pasta|fijne noedels|gnocci)\M'
       and n !~* '(bolognese|carbonara|arrabi|arrabbi|alla norma|paddenstoel|kip|chicken|beef|tonijn|zalm|gehakt|groente|waff|wafel|powder|poeder|bowl|verspakket|tomaat|speculoos|amandel|cashew|pinda|feta|teriyaki)'
        then 'grain_starch_ingredients'
      else null
    end as target_family
  from candidates
)
insert into audit7_0113_decisions (barcode, target_family)
select barcode, target_family from decisions where target_family is not null;

create table if not exists public._snapshot_0113_clusters_before as
select pf.*, p.name, p.brand, d.target_family
from audit7_0113_decisions d
join public.product_features pf using (barcode)
join public.products p using (barcode);

do $preflight$
declare v_targets integer; v_unknown integer;
begin
  select count(*) into v_targets from audit7_0113_decisions;
  if v_targets < 120 then
    raise exception '0113 verwacht minimaal 120 veilige targets, gevonden %', v_targets;
  end if;
  select count(*) into v_unknown
  from audit7_0113_decisions d left join public.swap_family_mapping m
    on m.swap_family = d.target_family
  where m.swap_family is null;
  if v_unknown <> 0 then raise exception '0113: % onbekende families', v_unknown; end if;
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
    swap_relevance_reason = 'audit7_0113: naam/merk bewijst ' || d.target_family,
    classification_status = 'classified',
    classification_confidence = 0.92,
    classification_reason = 'audit7_0113_classified: ' || d.target_family,
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
from audit7_0113_decisions d
join public.swap_family_mapping m on m.swap_family = d.target_family
left join public.swap_family_profile_defaults defs on defs.swap_family = d.target_family
where pf.barcode = d.barcode;

refresh materialized view public.catalog_classification_audit;

do $postflight$
declare v_bad integer;
begin
  select count(*) into v_bad
  from public.product_features pf
  join public._snapshot_0113_clusters_before s using (barcode)
  where pf.classification_status is distinct from 'classified'
     or pf.swap_family is distinct from s.target_family;
  if v_bad <> 0 then raise exception '0113: % targets ongeldig', v_bad; end if;
  select count(*) into v_bad from public.catalog_classification_audit
  where audit_bucket like 'invalid_%';
  if v_bad <> 0 then raise exception '0113: % harde auditinvarianten', v_bad; end if;
end
$postflight$;

commit;
