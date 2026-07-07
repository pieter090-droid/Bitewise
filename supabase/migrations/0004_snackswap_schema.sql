-- 0004_snackswap_schema.sql
-- SnackSwap-model: schemavoorbereiding. Volledig additief & idempotent.
-- Geen drops, geen kolomverwijderingen, geen dataverlies.
-- Grondslagen (vastgelegd):
--   * afgeleide waarden per 100 g;
--   * ontbrekende brondata => boolean NULL/ongezet, NOOIT false;
--   * data_quality meet of de swap-engine genoeg heeft, niet OFF-volledigheid.

create extension if not exists "pgcrypto";

-- updated_at helper (veilig opnieuw aanmaken; kan al bestaan).
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

-- ---------------------------------------------------------------------------
-- 1. Fundament: uniciteit op barcode (data is geverifieerd duplicaatvrij:
--    15.128 rijen, 0 duplicaten, 0 NULL). Vereist voor de FK's hieronder en
--    maakt de bestaande lookup_product-upsert (onConflict: barcode) robuust.
-- ---------------------------------------------------------------------------
create unique index if not exists products_barcode_key
  on public.products (barcode);

-- ---------------------------------------------------------------------------
-- 2. product_features (Layer 2) -- 1:1 met products via barcode.
--    Booleans zijn NULLABLE: NULL = onbekend, true/false = bekend.
--    Array-kolommen zijn Bitewise-eigen (niet uit OFF) => text[] + GIN.
-- ---------------------------------------------------------------------------
create table if not exists public.product_features (
  barcode text primary key
    references public.products(barcode) on delete cascade,

  data_quality_score numeric,   -- 0..100, completeness voor de swap-engine
  ai_confidence      numeric,

  snack_type       text,        -- AI-fase
  category_cluster text,        -- AI-fase

  taste_profile               text[] not null default '{}',
  texture_profile             text[] not null default '{}',
  use_moment                  text[] not null default '{}',
  swap_tags                   text[] not null default '{}',
  recommended_swap_directions text[] not null default '{}',

  is_sweet     boolean,   -- perceptie => AI-fase
  is_salty     boolean,   -- perceptie => AI-fase
  is_drink     boolean,
  is_dairy     boolean,
  is_chocolate boolean,
  is_crunchy   boolean,   -- textuur => AI-fase

  is_high_protein   boolean,
  is_low_sugar      boolean,
  is_low_kcal       boolean,
  is_high_fiber     boolean,
  is_less_processed boolean,

  has_sweeteners boolean,
  has_palm_oil   boolean,
  ingredient_count integer,

  ai_model       text,
  ai_enriched_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists product_features_touch on public.product_features;
create trigger product_features_touch
  before update on public.product_features
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 3. product_features_staging (Layer 3) -- AI-output voor goedkeuring.
-- ---------------------------------------------------------------------------
create table if not exists public.product_features_staging (
  id uuid primary key default gen_random_uuid(),
  barcode text not null
    references public.products(barcode) on delete cascade,

  snack_type       text,
  category_cluster text,
  taste_profile               text[] not null default '{}',
  texture_profile             text[] not null default '{}',
  use_moment                  text[] not null default '{}',
  swap_tags                   text[] not null default '{}',
  recommended_swap_directions text[] not null default '{}',

  is_sweet boolean, is_salty boolean, is_drink boolean, is_dairy boolean,
  is_chocolate boolean, is_crunchy boolean,
  is_high_protein boolean, is_low_sugar boolean, is_low_kcal boolean,
  is_high_fiber boolean, is_less_processed boolean,
  has_sweeteners boolean, has_palm_oil boolean,
  ingredient_count integer,

  ai_confidence   numeric,
  ai_model        text,
  raw_ai_response jsonb,

  validation_status text not null default 'pending'
    check (validation_status in ('pending','approved','rejected','needs_review')),
  validation_errors text[] not null default '{}',

  created_at timestamptz not null default now()
);
create index if not exists pfs_barcode_idx on public.product_features_staging (barcode);
create index if not exists pfs_status_idx  on public.product_features_staging (validation_status);

-- ---------------------------------------------------------------------------
-- 4. swap_recommendation_cache (Layer 4).
-- ---------------------------------------------------------------------------
create table if not exists public.swap_recommendation_cache (
  id uuid primary key default gen_random_uuid(),
  from_barcode text not null
    references public.products(barcode) on delete cascade,
  to_barcode text
    references public.products(barcode) on delete cascade,

  user_goal    text,
  context_hash text,
  swap_type    text,
  score        numeric,
  score_breakdown jsonb,
  reasons  text[] not null default '{}',
  warnings text[] not null default '{}',

  created_at timestamptz not null default now(),
  expires_at timestamptz
);
create index if not exists src_from_idx    on public.swap_recommendation_cache (from_barcode);
create index if not exists src_context_idx on public.swap_recommendation_cache (context_hash);

-- ---------------------------------------------------------------------------
-- 5. swap_feedback (Layer 5).
-- ---------------------------------------------------------------------------
create table if not exists public.swap_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  from_barcode text references public.products(barcode) on delete cascade,
  to_barcode   text references public.products(barcode) on delete cascade,

  feedback_type text not null
    check (feedback_type in ('useful','not_useful','saved','disliked',
      'too_expensive','not_available','not_similar_enough',
      'does_not_fit_goal','allergy_concern')),
  feedback_reason text,
  user_goal       text,

  created_at timestamptz not null default now()
);
create index if not exists sf_from_idx on public.swap_feedback (from_barcode);

-- ---------------------------------------------------------------------------
-- 6. Indexen op products voor kandidaatzoeken/filteren.
--    (GEEN GIN op categories_tags/labels_tags: die zijn text, geen text[].)
-- ---------------------------------------------------------------------------
create index if not exists products_nutriscore_idx  on public.products (nutriscore_grade);
create index if not exists products_nova_idx         on public.products (nova_group);
create index if not exists products_kcal_idx         on public.products (kcal_100g);
create index if not exists products_sugar_idx        on public.products (sugar_100g);
create index if not exists products_protein_idx      on public.products (protein_100g);
create index if not exists products_fiber_idx        on public.products (fiber_100g);
create index if not exists products_completeness_idx on public.products (completeness);

create index if not exists pf_snack_type_idx       on public.product_features (snack_type);
create index if not exists pf_category_cluster_idx on public.product_features (category_cluster);
create index if not exists pf_dq_idx               on public.product_features (data_quality_score);
create index if not exists pf_ai_conf_idx          on public.product_features (ai_confidence);
create index if not exists pf_taste_gin    on public.product_features using gin (taste_profile);
create index if not exists pf_swaptags_gin on public.product_features using gin (swap_tags);
create index if not exists pf_moment_gin   on public.product_features using gin (use_moment);

-- ---------------------------------------------------------------------------
-- 7. Data-quality-functie: meet of de swap-engine dit product kan scoren.
--    Aangepast aan echte kolomnamen (name, sugar_100g, protein_100g, ...).
--    Metadata (last_modified_t, off_url, stores, foto's, serving) telt NIET.
-- ---------------------------------------------------------------------------
create or replace function public.calculate_product_data_quality(p_barcode text)
returns numeric language sql stable as $$
  select least(100,
      case when nullif(trim(name), '') is not null then 15 else 0 end
    + case when kcal_100g is not null then 20 else 0 end
    + case when categories_tags is not null
             or pnns_groups_1 is not null
             or category is not null then 15 else 0 end
    + case when sugar_100g is not null then 10 else 0 end
    + case when protein_100g is not null then 10 else 0 end
    + case when fat_100g is not null then 5 else 0 end
    + case when saturated_fat_100g is not null then 3 else 0 end
    + case when fiber_100g is not null then 5 else 0 end
    + case when salt_100g is not null then 3 else 0 end
    + case when nutriscore_grade is not null
             and nutriscore_grade not in ('unknown','not-applicable') then 6 else 0 end
    + case when nova_group is not null then 4 else 0 end
    + case when ingredients_text is not null then 4 else 0 end
  )
  from public.products where barcode = p_barcode;
$$;

-- ---------------------------------------------------------------------------
-- 8. RLS: zelfde patroon als products (anon leest de gedeelde afgeleide data;
--    schrijven gebeurt uitsluitend via service_role/Edge Functions).
--    staging + feedback krijgen GEEN anon-policy (service_role only).
-- ---------------------------------------------------------------------------
alter table public.product_features          enable row level security;
alter table public.product_features_staging  enable row level security;
alter table public.swap_recommendation_cache enable row level security;
alter table public.swap_feedback             enable row level security;

drop policy if exists "features readable" on public.product_features;
create policy "features readable" on public.product_features for select using (true);

drop policy if exists "cache readable" on public.swap_recommendation_cache;
create policy "cache readable" on public.swap_recommendation_cache for select using (true);
