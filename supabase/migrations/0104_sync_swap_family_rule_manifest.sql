-- 0104 — Fase 6: swap_family_rules synchroniseren met de uitvoerbare
-- first-match-wins-keten in compute_swap_family().
--
-- Historisch bevatte swap_family_rules slechts een kleine, handmatig
-- bijgehouden subset. De functie is de runtime-bron van waarheid. Deze
-- migratie maakt de tabel daarom tot een reproduceerbaar manifest van alle
-- actuele branches en bewaart de exacte PL/pgSQL-conditie per branch.

alter table public.swap_family_rules
  add column if not exists rule_key text,
  add column if not exists branch_order integer,
  add column if not exists condition_sql text,
  add column if not exists source_function text,
  add column if not exists source_function_hash text,
  add column if not exists source_migration text;

create unique index if not exists swap_family_rules_rule_key_uq
  on public.swap_family_rules(rule_key)
  where rule_key is not null;

create or replace function public.refresh_swap_family_rule_manifest()
returns integer
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_definition text;
  v_hash text;
  v_match text[];
  v_order integer := 0;
  v_family text;
  v_relevant boolean;
begin
  v_definition := pg_get_functiondef('public.compute_swap_family(text,text,text,text,text,text)'::regprocedure);
  v_hash := md5(v_definition);

  -- Oude handmatige subsets blijven voor historische FK-verwijzingen bestaan,
  -- maar zijn niet langer actief als beschrijving van de runtime-keten.
  update public.swap_family_rules
  set is_active = false, updated_at = now()
  where is_active is true;

  for v_match in
    select regexp_matches(
      v_definition,
      E'(?ns)\\m(?:if|elsif)\\M\\s+(.*?)\\s+then\\s+return\\s+''([^'']+)''\\s*;',
      'g'
    )
  loop
    v_order := v_order + 1;
    v_family := v_match[2];

    select is_swap_relevant_default into v_relevant
    from public.swap_family_mapping
    where swap_family = v_family;

    insert into public.swap_family_rules (
      priority, classification_status, swap_family, confidence,
      rule_version, is_active, rationale, rule_key, branch_order,
      condition_sql, source_function, source_function_hash, source_migration,
      updated_at
    ) values (
      v_order * 10,
      case when coalesce(v_relevant, false) then 'classified'
           else 'not_swap_relevant' end,
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

  if v_order = 0 then
    raise exception 'compute_swap_family-manifest bevat 0 branches; parser of functieformaat gewijzigd';
  end if;

  return v_order;
end
$function$;

select public.refresh_swap_family_rule_manifest();

comment on table public.swap_family_rules is
  'Geordend auditmanifest van compute_swap_family(). Actieve regels worden reproduceerbaar opgebouwd door refresh_swap_family_rule_manifest(); condition_sql en source_function_hash koppelen iedere rij aan de runtimefunctie.';

comment on column public.swap_family_rules.condition_sql is
  'Exacte PL/pgSQL-conditie van deze first-match-branch. Variabelen: n=naam, c=categorie/tags, p1/p2=PNNS, b=merk.';

-- POSTFLIGHT:
-- actieve regels = resultaat refresh-functie (verwacht 76 voor 0098);
-- branch_order aaneengesloten; één hash; geen onbekende families.
