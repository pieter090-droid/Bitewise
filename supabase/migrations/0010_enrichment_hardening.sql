-- 0010_enrichment_hardening.sql
-- Robuustheid + eenmalige-loop-schakelaar + AI-kwaliteitscheck-trigger.
-- Idempotent & additief.

-- ---------------------------------------------------------------------------
-- 1. Eenmalige-loop-schakelaar. Standaard AAN voor de eerste volledige run;
--    schakelt zichzelf UIT zodra die run + kwaliteitscheck succesvol klaar
--    zijn. Nieuwe verrijking pas weer na expliciete herstart door de gebruiker.
-- ---------------------------------------------------------------------------
create table if not exists public.ai_enrichment_control (
  id                    smallint primary key default 1,
  auto_enrich_enabled   boolean not null default true,
  last_submit_error_at  timestamptz,
  last_submit_error     text,
  submit_attempts       integer not null default 0,
  updated_at            timestamptz not null default now(),
  constraint singleton check (id = 1)
);
insert into public.ai_enrichment_control (id) values (1) on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 2. Foutafhandeling-kolommen op ai_enrichment_batches (3-uur-afkoeling,
--    max-pogingen, kwaliteitscheck-status).
-- ---------------------------------------------------------------------------
alter table public.ai_enrichment_batches
  add column if not exists last_error_at timestamptz,
  add column if not exists last_error   text,
  add column if not exists attempts     integer not null default 0,
  add column if not exists quality_checked_at         timestamptz,
  add column if not exists quality_check_last_error_at timestamptz,
  add column if not exists quality_check_last_error    text,
  add column if not exists quality_check_attempts      integer not null default 0;

alter table public.ai_enrichment_batches drop constraint if exists ai_enrichment_batches_status_check;
alter table public.ai_enrichment_batches add constraint ai_enrichment_batches_status_check
  check (status in ('submitted','completed','failed'));

-- ---------------------------------------------------------------------------
-- 3. batch_id op staging -- maakt collect echt incrementeel hervatbaar
--    (bij een crash halverwege wordt alleen het ontbrekende deel opnieuw
--    ingevoegd, niets dubbel, geen tokens verspild).
-- ---------------------------------------------------------------------------
alter table public.product_features_staging
  add column if not exists batch_id text;
create index if not exists pfs_batch_idx on public.product_features_staging (batch_id);

-- ---------------------------------------------------------------------------
-- 4. swap_score_eval_results -- AI-rechter-uitkomsten van de kwaliteitscheck.
--    unique(batch_id, from, to) maakt de check zelf ook incrementeel
--    hervatbaar: al-beoordeelde paren worden nooit dubbel aan Sonnet 5
--    voorgelegd (geen tokenverspilling bij een retry).
-- ---------------------------------------------------------------------------
create table if not exists public.swap_score_eval_results (
  id                uuid primary key default gen_random_uuid(),
  batch_id          text not null,
  from_barcode      text not null references public.products(barcode) on delete cascade,
  to_barcode        text not null references public.products(barcode) on delete cascade,
  our_score         numeric,
  our_breakdown     jsonb,
  ai_judgment_score numeric,
  ai_judgment_reason text,
  is_discrepancy    boolean not null default false,
  created_at        timestamptz not null default now(),
  unique (batch_id, from_barcode, to_barcode)
);
alter table public.swap_score_eval_results enable row level security;
-- Geen anon-policy: alleen service_role (edge function) leest/schrijft.

-- ---------------------------------------------------------------------------
-- 5. Trigger: zodra een batch 'completed' wordt (en nog niet gecontroleerd
--    is), roep automatisch evaluate_swap_quality aan. Vuurt maar 1x per
--    batch (quality_checked_at-guard voorkomt herhaling).
-- ---------------------------------------------------------------------------
create or replace function public.trigger_evaluate_swap_quality()
returns trigger language plpgsql as $$
begin
  if NEW.status = 'completed' and OLD.status is distinct from 'completed'
     and NEW.quality_checked_at is null then
    perform net.http_post(
      url := 'https://ulgfgawoulkyumfzqgrc.supabase.co/functions/v1/evaluate_swap_quality',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', 'sb_publishable_SUIlYw03NLjU-tRlCn752w_ssZfGEFe'
      ),
      body := jsonb_build_object('batch_id', NEW.batch_id)
    );
  end if;
  return NEW;
end $$;

drop trigger if exists ai_enrichment_batches_quality_check on public.ai_enrichment_batches;
create trigger ai_enrichment_batches_quality_check
  after update on public.ai_enrichment_batches
  for each row execute function public.trigger_evaluate_swap_quality();
