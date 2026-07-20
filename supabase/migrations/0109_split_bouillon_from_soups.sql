-- 0109 — bouillon/stock is geen directe swap voor kant-en-klare soep.
--
-- De 0108-regressie liet Drink Bouillon Hot Ginger boven tomatencrèmesoep
-- eindigen. De oude R40-keuze plaatste bouillon als dekkingsfix in `soups`,
-- maar blokjes, poeders, fond en drinkbouillon zijn kook-/drinkcomponenten,
-- geen SnackSwap-maaltijd. Zij krijgen een expliciete non-swapfamilie.

begin;
set local statement_timeout = '10min';

create table if not exists public._snapshot_0109_bouillon_before as
select pf.*, p.name, p.brand, p.category
from public.product_features pf
join public.products p using (barcode)
where coalesce(p.name, '') ~*
  'bouillon|\mbrodo\M|\mbroth\M|stock cubes?|\mfond de\M|\mfumet\M|drinkbouillon|opkikker';

create table if not exists public._snapshot_0109_functions_before as
select
  pg_get_functiondef(
    'public.compute_swap_family(text,text,text,text,text,text)'::regprocedure
  ) as classifier_definition,
  pg_get_functiondef(
    'public.refresh_swap_family_rule_manifest()'::regprocedure
  ) as manifest_definition;

insert into public.swap_family_mapping (
  swap_family, category_cluster, snack_type, product_form, consumption_mode,
  secondary_consumption_modes, usage_context, related_families,
  is_swap_relevant_default
) values (
  'broths_bouillon_non_swap', 'overig', 'ingredient', 'stock_broth',
  'cook_or_prepare', array['drink'], array['cooking'], '{}', false
)
on conflict (swap_family) do update set
  category_cluster = excluded.category_cluster,
  snack_type = excluded.snack_type,
  product_form = excluded.product_form,
  consumption_mode = excluded.consumption_mode,
  secondary_consumption_modes = excluded.secondary_consumption_modes,
  usage_context = excluded.usage_context,
  related_families = excluded.related_families,
  is_swap_relevant_default = excluded.is_swap_relevant_default;

do $patch_classifier$
declare
  v_definition text;
  v_old text := $old$elsif (n ~* 'soep|\msoup\M|bouillon|\mbrodo\M' or p2 ~* '\msoup\M')
        and n !~* 'soepgroente|soepgroenten|soepstengel|soep ?stengel|crouton|soepballetjes|soep ?balletjes|verspakket|groentepakket' then
    return 'soups';$old$;
  v_new text := $new$elsif n ~* 'bouillon|\mbrodo\M|\mbroth\M|stock cubes?|\mfond de\M|\mfumet\M|drinkbouillon|opkikker' then
    return 'broths_bouillon_non_swap';
  elsif (n ~* 'soep|\msoup\M' or p2 ~* '\msoup\M')
        and n !~* 'soepgroente|soepgroenten|soepstengel|soep ?stengel|crouton|soepballetjes|soep ?balletjes|verspakket|groentepakket' then
    return 'soups';$new$;
begin
  v_definition := pg_get_functiondef(
    'public.compute_swap_family(text,text,text,text,text,text)'::regprocedure
  );
  if length(v_definition) - length(replace(v_definition, v_old, ''))
       <> length(v_old) then
    raise exception '0109 verwacht exact één herkenbare soup/bouillonbranch';
  end if;
  execute replace(v_definition, v_old, v_new);
end
$patch_classifier$;

do $patch_manifest$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.refresh_swap_family_rule_manifest()'::regprocedure
  );
  if length(v_definition) - length(replace(v_definition, 'v_order <> 76', ''))
       <> length('v_order <> 76')
     or length(v_definition) - length(replace(v_definition, 'verwacht 76 branches', ''))
       <> length('verwacht 76 branches') then
    raise exception '0109 verwacht het 76-branchmanifest uit 0105';
  end if;
  v_definition := replace(v_definition, 'v_order <> 76', 'v_order <> 77');
  v_definition := replace(
    v_definition,
    'verwacht 76 branches',
    'verwacht 77 branches'
  );
  execute v_definition;
end
$patch_manifest$;

update public.product_features pf
set swap_family = m.swap_family,
    category_cluster = m.category_cluster,
    snack_type = m.snack_type,
    product_form = m.product_form,
    consumption_mode = m.consumption_mode,
    secondary_consumption_modes = m.secondary_consumption_modes,
    usage_context = m.usage_context,
    is_swap_relevant = false,
    swap_relevance_reason = 'audit7_0109: bouillon/stock is kookcomponent, geen directe soep-swap',
    classification_status = 'classified',
    classification_confidence = greatest(
      coalesce(pf.classification_confidence, 0), 0.95
    ),
    classification_reason = 'audit7_0109: broths_bouillon_non_swap',
    classified_at = now(),
    mapping_version = coalesce(pf.mapping_version, 1),
    updated_at = now()
from public.products p
join public.swap_family_mapping m
  on m.swap_family = 'broths_bouillon_non_swap'
where p.barcode = pf.barcode
  and coalesce(p.name, '') ~*
    'bouillon|\mbrodo\M|\mbroth\M|stock cubes?|\mfond de\M|\mfumet\M|drinkbouillon|opkikker';

select public.refresh_swap_family_rule_manifest();
refresh materialized view public.catalog_classification_audit;

do $postflight$
declare
  v_bad integer;
begin
  if public.compute_swap_family(
       'Drink Bouillon Hot Ginger', null, null, null, null, 'Natur Compagnie'
     ) <> 'broths_bouillon_non_swap' then
    raise exception '0109 classifier splitst drinkbouillon niet af';
  end if;
  if public.compute_swap_family(
       'Tomaten creme soep', null, null, null, null, 'AH'
     ) <> 'soups' then
    raise exception '0109 classifier behoudt echte soep niet';
  end if;

  select count(*) into v_bad
  from public.product_features pf
  join public.products p using (barcode)
  where coalesce(p.name, '') ~*
      'bouillon|\mbrodo\M|\mbroth\M|stock cubes?|\mfond de\M|\mfumet\M|drinkbouillon|opkikker'
    and (
      pf.swap_family is distinct from 'broths_bouillon_non_swap'
      or pf.classification_status is distinct from 'classified'
      or pf.is_swap_relevant is not false
    );
  if v_bad <> 0 then
    raise exception '0109 postflight: % bouillon/stock-rijen inconsistent', v_bad;
  end if;

  select count(*) into v_bad
  from public.swap_family_rules
  where is_active is true;
  if v_bad <> 77 then
    raise exception '0109 postflight: verwacht 77 actieve regels, gevonden %', v_bad;
  end if;
end
$postflight$;

commit;
