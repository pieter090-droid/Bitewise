-- Database cleanup, groene kandidaten (expliciet goedgekeurd). Verwijdert
-- uitsluitend objecten waarvoor de preflight bevestigde: 0 referenties in
-- app-code (lib/), Edge Functions, DB-functions, triggers en views.
--
-- NIET aangeraakt (bewust buiten scope van deze migratie): `products`,
-- `product_features`, `product_features_resolved`, `swap_family_mapping`,
-- `swap_family_rules`, `lookup_product`, `user_day_logs`, en de oranje
-- objecten `recommend_swaps`/`swaps`/`swap_score_weights`/
-- `swap_score_eval_results`/AI-enrichment-tooling/de twee `_snapshot_*`
-- audit-tabellen.
--
-- Preflight bevestigde per object:
--   compute_swap_family_fields (functie) - 0 rijen n.v.t., 0 referenties
--   swap_candidates            - 0 rijen
--   ai_swap_runs                - 0 rijen
--   favorite_swaps               - 0 rijen
--   swap_recommendation_cache    - 0 rijen
--   swap_recommendation_groups   - 6 rijen -> gearchiveerd hieronder
--   meals                        - 0 rijen
--   meal_plans                   - 0 rijen
--   meal_plan_items               - 0 rijen
--   meal_ingredients              - 0 rijen
--   user_swap_feedback            - 0 rijen
--   synced_day_logs                - 0 rijen
--   user_preferences                - 0 rijen
--   swap_feedback                    - 0 rijen (let op: dit is de Supabase-
--     tabel, niet de gelijknamige lokale Drift-tabel `swap_feedbacks` in de
--     app, die blijft uiteraard ongemoeid)
--
-- Alle FK's die deze tabellen hadden wijzen UIT deze tabellen naar
-- products/swaps/cravings/auth.users (nooit andersom) -- droppen raakt dus
-- nooit products/swaps zelf. Enige onderlinge FK-afhankelijkheid:
-- meal_plan_items -> meal_plans/meals, meal_ingredients -> meals. Drop-
-- volgorde hieronder respecteert dat (kinderen vóór ouders).

-- Stap 1: archiveer de enige tabel met data vóór de drop.
create table if not exists public._archive_swap_recommendation_groups as
select * from public.swap_recommendation_groups;

-- Stap 2: drop in FK-veilige volgorde.
drop table if exists public.meal_plan_items;
drop table if exists public.meal_ingredients;
drop table if exists public.meal_plans;
drop table if exists public.meals;

drop table if exists public.swap_candidates;
drop table if exists public.ai_swap_runs;
drop table if exists public.favorite_swaps;
drop table if exists public.swap_recommendation_cache;
drop table if exists public.swap_recommendation_groups;
drop table if exists public.user_swap_feedback;
drop table if exists public.synced_day_logs;
drop table if exists public.user_preferences;
drop table if exists public.swap_feedback;

drop function if exists public.compute_swap_family_fields(text, text, text, text, text);

-- POSTFLIGHT (read-only, uit te voeren na deze migratie):
-- select count(*) from public._archive_swap_recommendation_groups; -- moet 6 zijn
-- select table_name from information_schema.tables where table_schema='public'
--   and table_name in ('swap_candidates','ai_swap_runs','favorite_swaps',
--   'swap_recommendation_cache','swap_recommendation_groups','meals','meal_plans',
--   'meal_plan_items','meal_ingredients','user_swap_feedback','synced_day_logs',
--   'user_preferences','swap_feedback'); -- moet 0 rijen zijn
-- select proname from pg_proc where proname='compute_swap_family_fields'; -- moet 0 rijen zijn
-- select count(*) from product_features_resolved; -- moet nog exact 15.128 zijn
-- select count(*) from products; -- moet nog exact 15.128 zijn

-- ROLLBACK (exact herstel indien nodig):
-- create table public.swap_recommendation_groups as select * from public._archive_swap_recommendation_groups;
--   (kolomtypes/defaults/constraints -- id uuid default, primary key, etc. -- moeten na een
--    eventuele restore handmatig teruggezet worden; deze archive-tabel bevat alleen de data.)
-- De overige 12 tabellen + de functie hadden 0 rijen; rollback = opnieuw aanmaken via de
-- originele CREATE-migratie(s) indien ooit nodig (schema, geen data-verlies aangezien leeg).
-- drop table public._archive_swap_recommendation_groups; -- pas na bevestigde, definitieve keuze
