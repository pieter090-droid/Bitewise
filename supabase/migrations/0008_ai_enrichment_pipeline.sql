-- 0008_ai_enrichment_pipeline.sql
-- Plant de nachtelijke AI-enrichment: 03:00 Europe/Amsterdam (zomertijd = 01:00 UTC)
-- submit-taak, en elke 15 min een collect-taak die pas iets doet zodra de
-- Anthropic Batch klaar is. Beide edge functions worden hieronder aangeroepen
-- via pg_net met de publieke (publishable) key -- zelfde patroon als de app.
--
-- LET OP (vastgelegd): 01:00 UTC komt overeen met 03:00 CEST (zomertijd).
-- In de winter (CET, UTC+1) schuift dit naar 02:00 lokale tijd -- bewust
-- geaccepteerd i.p.v. twee wisselende cron-tijden te onderhouden.

create extension if not exists pg_cron;
create extension if not exists pg_net;

create table if not exists public.ai_enrichment_batches (
  id             uuid primary key default gen_random_uuid(),
  batch_id       text unique,
  status         text not null default 'submitted'
                   check (status in ('submitted','completed','failed')),
  requested_count integer,
  applied_count   integer,
  needs_review_count integer,
  rejected_count  integer,
  submitted_at   timestamptz not null default now(),
  last_checked_at timestamptz,
  completed_at   timestamptz,
  error          text
);

alter table public.ai_enrichment_batches enable row level security;
-- Geen anon-policy: alleen service_role (cron/edge functions) leest/schrijft.

select cron.unschedule('snackswap-enrichment-submit')
  where exists (select 1 from cron.job where jobname = 'snackswap-enrichment-submit');
select cron.unschedule('snackswap-enrichment-collect')
  where exists (select 1 from cron.job where jobname = 'snackswap-enrichment-collect');

select cron.schedule(
  'snackswap-enrichment-submit',
  '0 1 * * *',  -- 03:00 Europe/Amsterdam (CEST)
  $$
  select net.http_post(
    url := 'https://ulgfgawoulkyumfzqgrc.supabase.co/functions/v1/enrich_batch_submit',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', 'sb_publishable_SUIlYw03NLjU-tRlCn752w_ssZfGEFe'
    ),
    body := '{}'::jsonb
  );
  $$
);

select cron.schedule(
  'snackswap-enrichment-collect',
  '*/15 * * * *',  -- elke 15 min; de functie zelf is een goedkope no-op zonder open batch
  $$
  select net.http_post(
    url := 'https://ulgfgawoulkyumfzqgrc.supabase.co/functions/v1/enrich_batch_collect',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', 'sb_publishable_SUIlYw03NLjU-tRlCn752w_ssZfGEFe'
    ),
    body := '{}'::jsonb
  );
  $$
);
