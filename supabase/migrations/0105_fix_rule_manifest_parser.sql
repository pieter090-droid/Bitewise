-- 0105 — Correctie op 0104: PostgreSQL's regexp_matches vouwde de keten
-- tot één match samen. Splits eerst op een branchbegin aan het begin van
-- een regel, parse daarna condition + return binnen elk segment. Een harde
-- 76-branch-assertie voorkomt dat een gedeeltelijk manifest ooit commit.

create or replace function public.refresh_swap_family_rule_manifest()
returns integer
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_definition text;
  v_hash text;
  v_segment text;
  v_match text[];
  v_order integer := 0;
  v_family text;
  v_relevant boolean;
begin
  v_definition := pg_get_functiondef('public.compute_swap_family(text,text,text,text,text,text)'::regprocedure);
  v_hash := md5(v_definition);

  update public.swap_family_rules
  set is_active = false, updated_at = now()
  where is_active is true;

  for v_segment in
    select regexp_split_to_table(
      v_definition,
      E'\\n[ \\t]*(?:if|elsif)[ \\t]+'
    )
  loop
    v_match := regexp_match(
      v_segment,
      E'(?ns)^(.*)\\s+then\\s+return\\s+''([^'']+)''\\s*;'
    );
    if v_match is null then
      continue;
    end if;

    v_order := v_order + 1;
    v_family := v_match[2];

    select is_swap_relevant_default into v_relevant
    from public.swap_family_mapping
    where swap_family = v_family;

    if not found then
      raise exception 'Manifestbranch % verwijst naar onbekende familie %',
        v_order, v_family;
    end if;

    insert into public.swap_family_rules (
      priority, classification_status, swap_family, confidence,
      rule_version, is_active, rationale, rule_key, branch_order,
      condition_sql, source_function, source_function_hash, source_migration,
      updated_at
    ) values (
      v_order * 10,
      case when v_relevant then 'classified' else 'not_swap_relevant' end,
      v_family,
      0.70,
      6,
      true,
      'Runtime-manifest: branch ' || v_order ||
        ' van de first-match-wins-keten. Exacte conditie staat in condition_sql.',
      'compute_swap_family.branch.' || lpad(v_order::text, 3, '0'),
      v_order,
      regexp_replace(v_match[1], E'\\s+', ' ', 'g'),
      'public.compute_swap_family(text,text,text,text,text,text)',
      v_hash,
      '0098_audit_batch5_meals.sql',
      now()
    )
    on conflict (rule_key) where rule_key is not null do update set
      priority = excluded.priority,
      classification_status = excluded.classification_status,
      swap_family = excluded.swap_family,
      confidence = excluded.confidence,
      rule_version = excluded.rule_version,
      is_active = excluded.is_active,
      rationale = excluded.rationale,
      branch_order = excluded.branch_order,
      condition_sql = excluded.condition_sql,
      source_function = excluded.source_function,
      source_function_hash = excluded.source_function_hash,
      source_migration = excluded.source_migration,
      updated_at = now();
  end loop;

  if v_order <> 76 then
    raise exception 'Onvolledig compute_swap_family-manifest: verwacht 76 branches, gevonden %',
      v_order;
  end if;

  return v_order;
end
$function$;

select public.refresh_swap_family_rule_manifest();

