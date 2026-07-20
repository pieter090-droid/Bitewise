-- Fase 6 — read-only consistentiecheck voor runtimefunctie en regelmanifest.
-- Iedere query hoort nul rijen terug te geven.

-- A. Exact 77 actieve, aaneengesloten branches (na bouillonsplitsing 0109).
select 'manifest_shape' as issue,
       count(*) as active_count,
       min(branch_order) as min_order,
       max(branch_order) as max_order,
       count(distinct branch_order) as distinct_orders
from public.swap_family_rules
where is_active
having count(*) <> 77
    or min(branch_order) <> 1
    or max(branch_order) <> 77
    or count(distinct branch_order) <> 77;

-- B. Iedere actieve rij hoort bij de huidige functiedefinitie.
select 'stale_function_hash' as issue, rule_key, branch_order, swap_family
from public.swap_family_rules
where is_active
  and source_function_hash is distinct from md5(
    pg_get_functiondef(
      'public.compute_swap_family(text,text,text,text,text,text)'::regprocedure
    )
  );

-- C. Geen lege conditie, sleutel of onbekende familie.
select 'incomplete_manifest_row' as issue, r.rule_key, r.branch_order,
       r.swap_family
from public.swap_family_rules r
left join public.swap_family_mapping m using (swap_family)
where r.is_active
  and (r.rule_key is null or r.condition_sql is null
    or btrim(r.condition_sql) = '' or m.swap_family is null);

-- D. Relevantiestatus van het manifest volgt het familiemodel.
select 'manifest_relevance_mismatch' as issue, r.rule_key, r.swap_family,
       r.classification_status, m.is_swap_relevant_default
from public.swap_family_rules r
join public.swap_family_mapping m using (swap_family)
where r.is_active
  and ((m.is_swap_relevant_default and r.classification_status <> 'classified')
    or (not m.is_swap_relevant_default
      and r.classification_status <> 'not_swap_relevant'));

-- E. Defaults verwijzen uitsluitend naar bestaande families.
select 'orphan_profile_default' as issue, d.swap_family
from public.swap_family_profile_defaults d
left join public.swap_family_mapping m using (swap_family)
where m.swap_family is null;
