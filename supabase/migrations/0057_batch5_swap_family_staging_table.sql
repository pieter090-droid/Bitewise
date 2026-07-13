-- VOORSTEL — NOG NIET UITGEVOERD. Wacht op expliciet akkoord vóór
-- `supabase db push`. Batch 5 (start): lege staging-tabel voor
-- handmatige/AI-ondersteunde beoordeling van de resterende 4429
-- ongeclassificeerde producten (grotendeels pnns_groups_2=unknown,
-- geen regex-signaal meer over).
--
-- Belangrijk: dit is GEEN AI-API-integratie. Er worden geen externe
-- calls gedaan. Classificatie gebeurt handmatig per batch, in de
-- conversatie zelf (zelfde beoordelingsproces als Batch A-D2), met een
-- reden per product. Deze tabel is uitsluitend een staging-laag zodat
-- niets direct in `product_features`/`product_features_resolved`
-- terechtkomt zonder aparte, gereviewde promotie-migratie (zelfde
-- snapshot/dry-run/postflight-rigor als alle voorgaande batches).
--
-- NAAMGEVING: eerste versie van deze migratie gebruikte de naam
-- `product_features_staging`, maar die tabel bleek al te bestaan --
-- 5815 rijen, van een oudere, ongerelateerde AI-verrijkingspijplijn
-- (echte Anthropic Batches-API msgbatch_-ids, juli 2026, vult
-- taste_profile/texture_profile/is_sweet/etc., swap_family altijd null
-- daar). Niet aangeraakt. Deze migratie gebruikt daarom een eigen naam:
-- `swap_family_staging`.
--
-- `products` en `product_features` blijven door DEZE migratie volledig
-- ongewijzigd -- puur een nieuwe, lege tabel.

create table if not exists public.swap_family_staging (
  id bigint generated always as identity primary key,
  barcode text not null references public.products(barcode),
  suggested_swap_family text,              -- moet één van de 60 bestaande swap_family-waarden zijn, of null ("kan niet betrouwbaar classificeren")
  confidence numeric not null check (confidence >= 0 and confidence <= 1),
  reasoning text not null,                 -- verplicht: 1 zin, per-product onderbouwing (zelfde eis als barcode-verankerde correcties)
  batch_label text not null,               -- bv. 'batch5_vegetables_pool'
  reviewed_by text not null default 'claude_manual_review',
  created_at timestamptz not null default now(),
  promoted_at timestamptz,                 -- null = nog niet gepromoveerd naar product_features
  promotion_migration text                 -- bv. '0058_...' -- welke migratie deze rij live heeft gezet
);

create index if not exists idx_swap_family_staging_barcode
  on public.swap_family_staging(barcode);
create index if not exists idx_swap_family_staging_unpromoted
  on public.swap_family_staging(barcode) where promoted_at is null;

-- POSTFLIGHT (read-only):
-- select count(*) from public.swap_family_staging; -- moet 0 zijn direct na deze migratie
-- select count(*) from public.product_features; -- moet ongewijzigd blijven
-- select count(*) from public.products; -- moet ongewijzigd blijven (products blijft raw)

-- ROLLBACK:
-- drop table public.swap_family_staging;
