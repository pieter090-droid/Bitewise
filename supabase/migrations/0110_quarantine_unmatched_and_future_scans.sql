-- 0110 — sluit het stille NULL-gat voor huidige én toekomstige producten.
--
-- De 2.344 resterende producten hebben na de actuele 77 classifierbranches
-- geen veilige familie. Zij worden niet gegokt: eerst expliciet in review,
-- daarna per inhoudelijk cluster beoordeeld. De producttrigger krijgt dezelfde
-- fail-closed-uitkomst voor toekomstige scans zonder regelmatch.

begin;
set local statement_timeout = '10min';

create table if not exists public._snapshot_0110_unmatched_before as
select pf.*, p.name, p.brand, p.category, p.categories_tags,
       p.pnns_groups_1, p.pnns_groups_2,
       p.kcal_100g, p.sugar_100g, p.protein_100g
from public.product_features pf
join public.products p using (barcode)
join public.catalog_classification_audit a using (barcode)
where a.audit_bucket = 'unreviewed_no_rule_match';

create table if not exists public._snapshot_0110_trigger_before as
select pg_get_functiondef(
  'public.compute_product_features()'::regprocedure
) as function_definition;

do $preflight$
declare
  v_targets integer;
  v_features integer;
begin
  select count(*) into v_targets
  from public.catalog_classification_audit
  where audit_bucket = 'unreviewed_no_rule_match';
  if v_targets <> 2344 then
    raise exception '0110 verwacht 2.344 unmatched targets, gevonden %', v_targets;
  end if;

  select count(*) into v_features
  from public._snapshot_0110_unmatched_before;
  if v_features <> v_targets then
    raise exception '0110 snapshot/features niet 1-op-1: % versus %', v_features, v_targets;
  end if;
end
$preflight$;

update public.product_features pf
set classification_status = 'review_required',
    classification_confidence = 0.0,
    classification_reason =
      'audit7_0110_pending: geen veilige match in actuele classifier',
    classified_at = now(),
    swap_family = null,
    category_cluster = null,
    snack_type = null,
    product_form = null,
    consumption_mode = null,
    secondary_consumption_modes = '{}'::text[],
    usage_context = '{}'::text[],
    is_swap_relevant = false,
    swap_relevance_reason =
      'audit7_0110: fail-closed tot inhoudelijke clusterreview',
    updated_at = now()
from public._snapshot_0110_unmatched_before s
where s.barcode = pf.barcode;

do $patch_trigger$
declare
  v_definition text;
  v_old text := $old$v_status := v_existing_status;
    v_classified_at := null;
    v_confidence := null;
    v_reason_text := null;
    v_mapping_version := null;
    v_fingerprint := null;
  end if;$old$;
  v_new text := $new$if v_existing_status is null and v_family is null then
      v_status := 'review_required';
      v_classified_at := now();
      v_confidence := 0.0;
      v_reason_text := 'live_trigger_no_safe_family_review';
      v_mapping_version := 1;
      v_fingerprint := md5(
        coalesce(NEW.name,'') || '|' || coalesce(NEW.category,'') || '|' ||
        coalesce(NEW.categories_tags,'') || '|' || coalesce(NEW.pnns_groups_1,'') || '|' ||
        coalesce(NEW.pnns_groups_2,'') || '|' || coalesce(NEW.ingredients_text,'') || '|' ||
        coalesce(NEW.ingredients_tags,'')
      );
    else
      v_status := v_existing_status;
      v_classified_at := null;
      v_confidence := null;
      v_reason_text := null;
      v_mapping_version := null;
      v_fingerprint := null;
    end if;
  end if;$new$;
begin
  v_definition := pg_get_functiondef(
    'public.compute_product_features()'::regprocedure
  );
  if length(v_definition) - length(replace(v_definition, v_old, ''))
       <> length(v_old) then
    raise exception '0110 herkent het bestaande NULL-statuspad niet exact';
  end if;
  execute replace(v_definition, v_old, v_new);
end
$patch_trigger$;

refresh materialized view public.catalog_classification_audit;

do $postflight$
declare
  v_bad integer;
begin
  select count(*) into v_bad
  from public.product_features_resolved
  where classification_status is null;
  if v_bad <> 0 then
    raise exception '0110 postflight: nog % producten zonder status', v_bad;
  end if;

  select count(*) into v_bad
  from public.catalog_classification_audit
  where audit_bucket in ('unreviewed_rule_match', 'unreviewed_no_rule_match')
     or audit_bucket like 'invalid_%';
  if v_bad <> 0 then
    raise exception '0110 postflight: nog % unreviewed/invalid auditrijen', v_bad;
  end if;

  if position(
       'live_trigger_no_safe_family_review' in
       pg_get_functiondef('public.compute_product_features()'::regprocedure)
     ) = 0 then
    raise exception '0110 trigger bevat fail-closed reviewpad niet';
  end if;
end
$postflight$;

commit;
