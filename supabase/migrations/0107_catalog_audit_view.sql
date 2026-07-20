-- 0107 — reproduceerbare, read-only catalogusauditlaag voor fase 7.
--
-- Deze migratie wijzigt geen product- of featuredata. De view maakt voor
-- iedere products-rij zichtbaar: de vastgelegde beslissing, de uitkomst van
-- de actuele runtimeclassifier en de auditgroep waarin het verschil valt.

create table if not exists public._snapshot_0107_catalog_audit_view_before as
select definition as previous_definition
from pg_matviews
where schemaname = 'public'
  and matviewname = 'catalog_classification_audit';

-- De classifier over de hele catalogus is bewust een checkpointberekening.
-- Een gewone view zou compute_swap_family() bij iedere telling opnieuw voor
-- alle rijen uitvoeren en liep in de eerste postflight tegen statement_timeout.
-- Na iedere classificatiemigratie wordt deze materialized view ververst.
set local statement_timeout = '10min';

create materialized view public.catalog_classification_audit as
with evaluated as (
  select
    p.barcode,
    p.name,
    p.brand,
    p.category,
    p.categories_tags,
    p.pnns_groups_1,
    p.pnns_groups_2,
    p.kcal_100g,
    p.sugar_100g,
    p.protein_100g,
    pf.classification_status,
    pf.classification_reason,
    pf.swap_family as stored_swap_family,
    public.compute_swap_family(
      p.name,
      p.category,
      p.categories_tags,
      p.pnns_groups_1,
      p.pnns_groups_2,
      p.brand
    ) as computed_swap_family
  from public.products p
  left join public.product_features pf on pf.barcode = p.barcode
)
select
  e.*,
  m.is_swap_relevant_default as stored_family_relevant,
  cm.is_swap_relevant_default as computed_family_relevant,
  case
    when e.classification_status is null
         and e.computed_swap_family is not null
      then 'unreviewed_rule_match'
    when e.classification_status is null
         and e.computed_swap_family is null
      then 'unreviewed_no_rule_match'
    when e.classification_status = 'review_required'
      then 'review_required'
    when e.classification_status = 'classified'
         and e.stored_swap_family is null
      then 'invalid_classified_without_family'
    when e.classification_status = 'classified'
         and e.computed_swap_family is null
      then 'classified_rule_gap'
    when e.classification_status = 'classified'
         and e.stored_swap_family is distinct from e.computed_swap_family
      then 'classified_rule_disagreement'
    when e.classification_status = 'classified'
         and e.stored_swap_family = e.computed_swap_family
      then 'classified_rule_agreement'
    else 'invalid_unknown_status'
  end as audit_bucket
from evaluated e
left join public.swap_family_mapping m
  on m.swap_family = e.stored_swap_family
left join public.swap_family_mapping cm
  on cm.swap_family = e.computed_swap_family
with data;

create unique index catalog_classification_audit_barcode_idx
  on public.catalog_classification_audit (barcode);

grant select on public.catalog_classification_audit to anon, authenticated;

do $postflight$
declare
  v_products bigint;
  v_audit bigint;
  v_distinct bigint;
  v_bad bigint;
begin
  select count(*) into v_products from public.products;
  select count(*), count(distinct barcode)
    into v_audit, v_distinct
  from public.catalog_classification_audit;

  if v_audit <> v_products or v_distinct <> v_products then
    raise exception
      '0107 auditview is niet 1:1: products %, audit %, uniek %',
      v_products, v_audit, v_distinct;
  end if;

  select count(*) into v_bad
  from public.catalog_classification_audit
  where audit_bucket in (
    'invalid_classified_without_family',
    'invalid_unknown_status'
  );
  if v_bad <> 0 then
    raise exception '0107 bestaande harde statusinvarianten falen: %', v_bad;
  end if;
end
$postflight$;
