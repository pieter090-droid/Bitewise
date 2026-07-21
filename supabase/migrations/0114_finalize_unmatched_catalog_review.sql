-- 0114 — fase 7C afsluiting.
-- Benut de laatste betrouwbare broncategorieën en vervang daarna iedere
-- generieke 0110-pendingreden door een expliciete, reproduceerbare reviewreden.
-- Geen twijfelgeval wordt swapbaar gemaakt; products blijft raw.

begin;
set local statement_timeout = '10min';

create table if not exists public._snapshot_0114_pending_before as
select pf.*, p.name, p.brand, p.category, p.categories_tags,
       p.pnns_groups_1, p.pnns_groups_2
from public.product_features pf
join public.products p using (barcode)
where pf.classification_status = 'review_required'
  and pf.classification_reason like 'audit7_0110_pending%';

create temporary table audit7_0114_safe_decisions (
  barcode text primary key,
  target_family text not null,
  evidence text not null
) on commit drop;

with candidates as (
  select p.barcode,
    lower(coalesce(p.name, '')) as n,
    lower(coalesce(p.category, '')) as c
  from public.products p
  join public.product_features pf using (barcode)
  where pf.classification_status = 'review_required'
    and pf.classification_reason like 'audit7_0110_pending%'
), decisions as (
  select barcode,
    case
      when c ~ '(zoetstoffen|sweeteners|édulcorants)'
        then 'baking_ingredients_non_swap'
      when c ~ '(cocoa and its products|cacao en afgeleide producten)'
       and n ~ '(cacao|cocoa)'
        then 'baking_ingredients_non_swap'
      when c ~ '(bakmixes)'
        then 'baking_ingredients_non_swap'
      when c ~ '(crêpes and galettes|en:pancakes)'
       and n ~ '(pannenkoek|pancake)'
        then 'cakes_pastries'
      when c ~ 'maaltijdpakketten'
        then 'meal_components'
      when c ~ '(voedingssupplementen|dietary supplements|sport|gezondheid)'
       and n ~ '(vitamin|magnesium|calcium|collageen|electroly|protein|prote[iï]ne|eiwit|poeder|supplement)'
       and n !~ '(bar|cookie|koek|gel|gumm|drink|shot|chia)'
        then 'supplements_powders'
      when c ~ 'syrups' and n ~ '(stroop|siroop|syrup)'
        then 'honey_syrups'
      else null
    end as target_family
  from candidates
)
insert into audit7_0114_safe_decisions (barcode, target_family, evidence)
select barcode, target_family, 'betrouwbare broncategorie + passende productnaam'
from decisions where target_family is not null;

do $preflight$
declare v_pending integer; v_safe integer; v_unknown integer;
begin
  select count(*) into v_pending from public._snapshot_0114_pending_before;
  if v_pending <> 1931 then
    raise exception '0114 verwacht 1931 pending rijen, gevonden %', v_pending;
  end if;
  select count(*) into v_safe from audit7_0114_safe_decisions;
  if v_safe < 20 then
    raise exception '0114 verwacht minimaal 20 categorie-bewezen rijen, gevonden %', v_safe;
  end if;
  select count(*) into v_unknown
  from audit7_0114_safe_decisions d left join public.swap_family_mapping m
    on m.swap_family = d.target_family
  where m.swap_family is null;
  if v_unknown <> 0 then raise exception '0114: % onbekende families', v_unknown; end if;
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
    swap_relevance_reason = 'audit7_0114: ' || d.evidence,
    classification_status = 'classified',
    classification_confidence = 0.90,
    classification_reason = 'audit7_0114_category_confirmed: ' || d.target_family,
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
from audit7_0114_safe_decisions d
join public.swap_family_mapping m on m.swap_family = d.target_family
left join public.swap_family_profile_defaults defs on defs.swap_family = d.target_family
where pf.barcode = d.barcode;

-- De rest is inhoudelijk beoordeeld maar niet veilig in één van de huidige
-- families te plaatsen. De reden is expliciet en bepaalt welk vervolg nodig is.
update public.product_features pf
set swap_family = null,
    category_cluster = null,
    snack_type = null,
    product_form = null,
    consumption_mode = null,
    secondary_consumption_modes = '{}'::text[],
    usage_context = '{}'::text[],
    is_swap_relevant = false,
    swap_relevance_reason = 'audit7_0114: fail-closed na volledige catalogusgroepering',
    classification_status = 'review_required',
    classification_confidence = 0.50,
    classification_reason = case
      when coalesce(p.name, '') ~ '[ÃÐð]'
        then 'audit7_final_source_text_corrupt: naam/encoding verhindert betrouwbare classificatie'
      when coalesce(p.category, '') = ''
       and coalesce(p.categories_tags, '') = ''
       and coalesce(p.pnns_groups_1, 'unknown') in ('', 'unknown')
       and coalesce(p.pnns_groups_2, 'unknown') in ('', 'unknown')
        then 'audit7_final_insufficient_taxonomy: naam en voeding bewijzen geen veilige productvorm'
      when lower(coalesce(p.name, '') || ' ' || coalesce(p.category, '')) ~
        '(kruid|spice|peper|zout|salt|augurk|pickle|kapper|gember|ginger|azijn|vinegar|groentemix|verspakket|kookpakket)'
        then 'audit7_final_unsupported_product_form: herkenbaar product zonder passende swapfamilie'
      when coalesce(p.category, '') <> ''
        then 'audit7_final_broad_or_conflicting_taxonomy: categorie is te breed of strijdig met de naam'
      else 'audit7_final_ambiguous_composite: meerdere interpretaties, geen veilige familiekeuze'
    end,
    classified_at = now(),
    updated_at = now()
from public.products p
where p.barcode = pf.barcode
  and pf.classification_status = 'review_required'
  and pf.classification_reason like 'audit7_0110_pending%';

refresh materialized view public.catalog_classification_audit;

do $postflight$
declare v_pending integer; v_accounted integer; v_bad integer;
begin
  select count(*) into v_pending from public.product_features
  where classification_reason like 'audit7_0110_pending%';
  if v_pending <> 0 then raise exception '0114: nog % generieke pending rijen', v_pending; end if;

  select count(*) into v_accounted from public.product_features pf
  join public._snapshot_0114_pending_before s using (barcode)
  where pf.classification_reason like 'audit7_0114_category_confirmed:%'
     or pf.classification_reason like 'audit7_final_%';
  if v_accounted <> 1931 then
    raise exception '0114: eindverantwoording % i.p.v. 1931', v_accounted;
  end if;

  select count(*) into v_bad from public.catalog_classification_audit
  where audit_bucket like 'invalid_%';
  if v_bad <> 0 then raise exception '0114: % harde auditinvarianten', v_bad; end if;
end
$postflight$;

commit;
