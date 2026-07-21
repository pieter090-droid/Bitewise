-- 0115 — fase 7D: verklaar of sluit ieder verschil tussen opgeslagen
-- classificatie en de actuele classifier. Onverklaard = fail-closed review.

begin;
set local statement_timeout = '10min';

create table if not exists public._snapshot_0115_differences_before as
select pf.*, a.computed_swap_family, a.audit_bucket, p.name, p.brand
from public.catalog_classification_audit a
join public.product_features pf using (barcode)
join public.products p using (barcode)
where a.audit_bucket in ('classified_rule_gap', 'classified_rule_disagreement');

create temporary table audit7_0115_corrections (
  barcode text primary key,
  target_family text not null,
  evidence text not null
) on commit drop;

insert into audit7_0115_corrections (barcode, target_family, evidence)
select a.barcode,
  case
    when a.computed_swap_family = 'meat_alternatives_non_swap'
     and a.stored_swap_family in ('meal_components','cold_cuts','meat_snacks')
      then 'meat_alternatives_non_swap'
    when lower(coalesce(a.name,'')) ~ '(baby|[0-9]+\+?m|maanden|olvarit|organix|ella''s kitchen|yogolino)'
     and a.stored_swap_family <> 'baby_food_non_swap'
      then 'baby_food_non_swap'
    when a.stored_swap_family = 'meal_components'
     and lower(coalesce(a.name,'')) ~ '(gyoza|dim sum)'
      then 'fried_snacks'
    when a.stored_swap_family = 'ready_meals'
     and a.computed_swap_family = 'fried_snacks'
      then 'fried_snacks'
    when a.stored_swap_family = 'meal_components'
     and lower(trim(coalesce(a.name,''))) ~ '^(couscous|black beans in water)$'
      then case when lower(a.name) like 'couscous%' then 'grain_starch_ingredients'
                else 'legumes_non_swap' end
    when a.stored_swap_family = 'fresh_vegetables'
     and a.computed_swap_family = 'legumes_non_swap'
      then 'legumes_non_swap'
    when a.stored_swap_family = 'water'
     and lower(coalesce(a.name,'')) ~ 'protein water'
      then 'sports_drinks'
    when a.stored_swap_family = 'water'
     and lower(coalesce(a.name,'')) ~ '(vitamin water|vitamin drink)'
      then 'soft_drinks_regular'
    when a.stored_swap_family = 'meal_components'
     and lower(coalesce(a.name,'')) ~ '(salad oil|huile pour salade)'
      then 'cooking_oils_fats'
    else null
  end as target_family,
  'fase 7D: expliciete productvorm corrigeert legacyfamilie'
from public.catalog_classification_audit a
where a.audit_bucket in ('classified_rule_gap','classified_rule_disagreement')
  and (
    (a.computed_swap_family = 'meat_alternatives_non_swap'
      and a.stored_swap_family in ('meal_components','cold_cuts','meat_snacks'))
    or (lower(coalesce(a.name,'')) ~ '(baby|[0-9]+\+?m|maanden|olvarit|organix|ella''s kitchen|yogolino)'
      and a.stored_swap_family <> 'baby_food_non_swap')
    or (a.stored_swap_family = 'meal_components' and lower(coalesce(a.name,'')) ~ '(gyoza|dim sum)')
    or (a.stored_swap_family = 'ready_meals' and a.computed_swap_family = 'fried_snacks')
    or (a.stored_swap_family = 'meal_components' and lower(trim(coalesce(a.name,''))) ~ '^(couscous|black beans in water)$')
    or (a.stored_swap_family = 'fresh_vegetables' and a.computed_swap_family = 'legumes_non_swap')
    or (a.stored_swap_family = 'water' and lower(coalesce(a.name,'')) ~ '(protein water|vitamin water|vitamin drink)')
    or (a.stored_swap_family = 'meal_components' and lower(coalesce(a.name,'')) ~ '(salad oil|huile pour salade)')
  );

update public.product_features pf
set swap_family = m.swap_family,
    category_cluster = m.category_cluster,
    snack_type = m.snack_type,
    product_form = m.product_form,
    consumption_mode = m.consumption_mode,
    secondary_consumption_modes = m.secondary_consumption_modes,
    usage_context = m.usage_context,
    is_swap_relevant = m.is_swap_relevant_default,
    swap_relevance_reason = 'audit7_0115: ' || d.evidence,
    classification_status = 'classified',
    classification_confidence = 0.95,
    classification_reason = 'audit7_0115_corrected: ' || d.target_family,
    classified_at = now(), updated_at = now()
from audit7_0115_corrections d
join public.swap_family_mapping m on m.swap_family = d.target_family
where pf.barcode = d.barcode;

-- Bekende paren waarin de opgeslagen vorm specifieker is dan de brede regel.
update public.product_features pf
set classification_reason = 'audit7_0115_verified_legacy_override: ' ||
      a.stored_swap_family || ' boven ' || a.computed_swap_family,
    classification_confidence = greatest(coalesce(pf.classification_confidence,0),0.90),
    classified_at = now(), updated_at = now()
from public.catalog_classification_audit a
where pf.barcode = a.barcode
  and a.classification_reason = 'legacy_existing_valid_family_status_backfill'
  and a.audit_bucket = 'classified_rule_disagreement'
  and (a.stored_swap_family, a.computed_swap_family) in (
    ('plant_based_dairy','grain_starch_ingredients'),
    ('crisps_chips','bread_bakery'),
    ('hot_beverages','dairy_drinks'),
    ('cookies_biscuits','dairy_drinks'),
    ('crackers_rice_cakes','bread_bakery'),
    ('crackers_rice_cakes','grain_starch_ingredients'),
    ('bread_bakery','grain_starch_ingredients'),
    ('nuts_seeds','grain_starch_ingredients'),
    ('cooking_oils_fats','fats_oils_non_swap'),
    ('cooking_oils_fats','grain_starch_ingredients'),
    ('chocolate_spreads','grain_starch_ingredients')
  )
  and not exists (select 1 from audit7_0115_corrections d where d.barcode=a.barcode);

-- Een gap heeft geen tegensprekende regel. Behoud de bestaande familie, maar
-- maak zichtbaar dat dit handmatig/legacy bewijs is en niet regelovereenkomst.
update public.product_features pf
set classification_reason = 'audit7_0115_verified_legacy_gap: opgeslagen familie behouden; actuele regel heeft geen match',
    classification_confidence = least(greatest(coalesce(pf.classification_confidence,0),0.80),0.90),
    classified_at = now(), updated_at = now()
from public.catalog_classification_audit a
where pf.barcode = a.barcode
  and a.classification_reason = 'legacy_existing_valid_family_status_backfill'
  and a.audit_bucket = 'classified_rule_gap'
  and not exists (select 1 from audit7_0115_corrections d where d.barcode=a.barcode);

-- Alle resterende legacy-disagreements en alle verschillen zonder vastgelegde
-- reden zijn niet bewezen. Zij verdwijnen uit bron- en kandidaatselectie.
update public.product_features pf
set swap_family = null, category_cluster = null, snack_type = null,
    product_form = null, consumption_mode = null,
    secondary_consumption_modes = '{}'::text[], usage_context = '{}'::text[],
    is_swap_relevant = false,
    swap_relevance_reason = 'audit7_0115: onverklaard persistentieverschil fail-closed',
    classification_status = 'review_required', classification_confidence = 0.40,
    classification_reason = 'audit7_0115_review_unexplained_difference',
    classified_at = now(), updated_at = now()
from public.catalog_classification_audit a
where pf.barcode = a.barcode
  and a.audit_bucket in ('classified_rule_gap','classified_rule_disagreement')
  and not exists (select 1 from audit7_0115_corrections d where d.barcode=a.barcode)
  and (
    coalesce(a.classification_reason,'') = ''
    or a.classification_reason = 'legacy_existing_valid_family_status_backfill'
  )
  and not (
    coalesce(a.classification_reason,'') = 'legacy_existing_valid_family_status_backfill'
    and a.audit_bucket = 'classified_rule_gap'
  )
  and coalesce(pf.classification_reason,'') not like 'audit7_0115_verified_legacy_override:%';

refresh materialized view public.catalog_classification_audit;

create table if not exists public.classification_audit_decisions (
  barcode text primary key references public.products(barcode),
  audit_bucket text not null,
  stored_swap_family text,
  computed_swap_family text,
  classification_reason text,
  decision_basis text not null,
  release_blocking boolean not null,
  audited_at timestamptz not null default now()
);

truncate table public.classification_audit_decisions;
insert into public.classification_audit_decisions (
  barcode, audit_bucket, stored_swap_family, computed_swap_family,
  classification_reason, decision_basis, release_blocking, audited_at
)
select barcode, audit_bucket, stored_swap_family, computed_swap_family,
  classification_reason,
  case
    when audit_bucket = 'classified_rule_agreement' then 'current_rule_agreement'
    when audit_bucket = 'review_required' then 'fail_closed_review'
    when coalesce(classification_reason,'') <> '' then 'documented_manual_override'
    else 'unexplained_difference'
  end,
  case
    when audit_bucket like 'invalid_%' then true
    when audit_bucket in ('classified_rule_gap','classified_rule_disagreement')
      and coalesce(classification_reason,'') = '' then true
    else false
  end,
  now()
from public.catalog_classification_audit;

grant select on public.classification_audit_decisions to anon, authenticated;

do $postflight$
declare v_total integer; v_blocking integer; v_invalid integer;
begin
  select count(*) into v_total from public.classification_audit_decisions;
  if v_total <> 15130 then raise exception '0115: auditbesluiten % i.p.v. 15130', v_total; end if;
  select count(*) into v_blocking from public.classification_audit_decisions where release_blocking;
  if v_blocking <> 0 then raise exception '0115: nog % onverklaarde/blocking verschillen', v_blocking; end if;
  select count(*) into v_invalid from public.catalog_classification_audit where audit_bucket like 'invalid_%';
  if v_invalid <> 0 then raise exception '0115: % harde invarianten', v_invalid; end if;
end
$postflight$;

commit;
