-- 0006_snackswap_selection.sql
-- Selectie + clustering + AI-enrichment-pijplijn (schema only, GEEN AI-run).
-- Idempotent & additief. Bouwt voort op 0004/0005.
--
-- Kernideeen:
--  * Alleen snack/drank-producten (is_swap_relevant) worden ooit AI-verrijkt.
--  * Binnen een cluster (zelfde categorie-leaf + macro-bucket) wordt maar 1
--    representant door de AI gehaald; labels stromen naar de clustergenoten.
--  * Nieuwe producten (via lookup_product) krijgen automatisch objectieve
--    features + selectie + cluster via een trigger -- NOOIT automatisch AI.
--  * validate_staged_features() is de extra kwaliteitspoort voor AI-output.

-- ---------------------------------------------------------------------------
-- 1. feature_vocabulary: toegestane waarden per AI-veld (data-gedreven validatie)
-- ---------------------------------------------------------------------------
create table if not exists public.feature_vocabulary (
  field text not null,
  value text not null,
  primary key (field, value)
);

insert into public.feature_vocabulary (field, value) values
  ('snack_type','hartige_snack'),('snack_type','noten_zaden'),('snack_type','zoete_snack'),
  ('snack_type','chocolade'),('snack_type','snoep'),('snack_type','ijs'),
  ('snack_type','zuivel_toetje'),('snack_type','reep'),('snack_type','fruit'),
  ('snack_type','groente'),('snack_type','brood_bakkerij'),('snack_type','ontbijtgranen'),
  ('snack_type','kaas'),('snack_type','vleeswaren_beleg'),('snack_type','frisdrank'),
  ('snack_type','sap'),('snack_type','water'),('snack_type','warme_drank'),
  ('snack_type','zuiveldrank'),('snack_type','alcohol'),('snack_type','maaltijd_component'),
  ('snack_type','supplement'),('snack_type','overig'),
  ('category_cluster','zoet'),('category_cluster','hartig'),('category_cluster','drank'),
  ('category_cluster','zuivel'),('category_cluster','fruit_groente'),('category_cluster','maaltijd'),
  ('category_cluster','overig'),
  ('taste_profile','zoet'),('taste_profile','zout'),('taste_profile','zuur'),
  ('taste_profile','bitter'),('taste_profile','umami'),('taste_profile','fruitig'),
  ('taste_profile','kruidig'),
  ('texture_profile','knapperig'),('texture_profile','krokant'),('texture_profile','zacht'),
  ('texture_profile','romig'),('texture_profile','taai'),('texture_profile','vloeibaar'),
  ('texture_profile','bruisend'),('texture_profile','luchtig'),('texture_profile','plakkerig'),
  ('use_moment','ontbijt'),('use_moment','lunch'),('use_moment','diner'),
  ('use_moment','snack'),('use_moment','drinken'),
  ('swap_tags','volume_snack'),('swap_tags','plantaardig'),('swap_tags','volkoren'),
  ('swap_tags','ongezoet'),('swap_tags','volwaardig'),
  ('recommended_swap_directions','naar_minder_suiker'),('recommended_swap_directions','naar_meer_eiwit'),
  ('recommended_swap_directions','naar_minder_kcal'),('recommended_swap_directions','naar_meer_vezels'),
  ('recommended_swap_directions','naar_minder_bewerkt'),('recommended_swap_directions','naar_kleinere_portie')
on conflict (field, value) do nothing;

alter table public.feature_vocabulary enable row level security;
drop policy if exists "vocab readable" on public.feature_vocabulary;
create policy "vocab readable" on public.feature_vocabulary for select using (true);

-- ---------------------------------------------------------------------------
-- 2. Nieuwe kolommen op product_features (selectie + clustering)
-- ---------------------------------------------------------------------------
alter table public.product_features
  add column if not exists is_swap_relevant      boolean,
  add column if not exists swap_relevance_reason text,   -- pnns_snack | category_rescue | cereal_fruit
  add column if not exists cluster_key           text,
  add column if not exists is_representative      boolean;

alter table public.product_features_staging
  add column if not exists applied_at timestamptz;

create index if not exists pf_swap_relevant_idx on public.product_features (is_swap_relevant);
create index if not exists pf_cluster_idx        on public.product_features (cluster_key);
create index if not exists pf_representative_idx  on public.product_features (is_representative);

-- ---------------------------------------------------------------------------
-- 3. Regel-functies (rule-based, geen AI): selectie + clustersleutel
-- ---------------------------------------------------------------------------
create or replace function public.compute_swap_relevance(
  p_pnns1 text, p_pnns2 text, p_categories_tags text
) returns text language sql immutable as $$
  select case
    when p_pnns1 in ('Sugary snacks','Salty snacks','Beverages','Milk and dairy products')
      then 'pnns_snack'
    when p_pnns2 in ('Breakfast cereals','Fruits','Dried fruits')
      then 'cereal_fruit'
    when coalesce(p_pnns1,'unknown') = 'unknown'
      and p_categories_tags is not null
      and p_categories_tags ~* '(snack|chocolate|candie|confectioner|biscuit|cookie|cake|beverage|juice|soda|drink|ice-cream|crisp|chips|nuts|yogurt|dessert)'
      then 'category_rescue'
    else null
  end;
$$;

create or replace function public.compute_cluster_key(
  p_categories_tags text, p_main_category text,
  p_kcal numeric, p_sugar numeric, p_protein numeric
) returns text language sql immutable as $$
  select
    coalesce(
      nullif(trim(split_part(p_categories_tags, ',',
        greatest(array_length(string_to_array(p_categories_tags, ','), 1), 1))), ''),
      p_main_category, 'unknown')
    || '|' || coalesce((round(p_kcal   / 10.0) * 10)::text, 'x')
    || '|' || coalesce((round(p_sugar  / 10.0) * 10)::text, 'x')
    || '|' || coalesce((round(p_protein/ 10.0) * 10)::text, 'x');
$$;

-- ---------------------------------------------------------------------------
-- 4. Trigger: nieuwe/bijgewerkte producten -> objectieve features + selectie.
--    Raakt NOOIT de AI-kolommen aan (idempotent op re-run).
-- ---------------------------------------------------------------------------
create or replace function public.compute_product_features()
returns trigger language plpgsql as $$
declare
  v_is_drink boolean;
  v_reason   text;
  v_cluster  text;
begin
  v_is_drink := case
    when NEW.categories_tags is null and NEW.pnns_groups_1 is null then null
    when NEW.pnns_groups_1 ilike '%beverage%'
      or NEW.categories_tags ilike '%en:beverages%'
      or NEW.categories_tags ilike '%drinks%' then true
    else false end;

  v_reason := public.compute_swap_relevance(NEW.pnns_groups_1, NEW.pnns_groups_2, NEW.categories_tags);
  v_cluster := case when v_reason is not null
    then public.compute_cluster_key(NEW.categories_tags, NEW.main_category,
                                    NEW.kcal_100g, NEW.sugar_100g, NEW.protein_100g)
    else null end;

  insert into public.product_features as pf (
    barcode, data_quality_score, ingredient_count,
    is_drink, is_dairy, is_chocolate, has_palm_oil, has_sweeteners,
    is_low_sugar, is_high_fiber, is_high_protein, is_low_kcal, is_less_processed,
    is_swap_relevant, swap_relevance_reason, cluster_key
  ) values (
    NEW.barcode,
    public.calculate_product_data_quality(NEW.barcode),
    case when nullif(trim(NEW.ingredients_tags), '') is null then null
         else array_length(string_to_array(NEW.ingredients_tags, ','), 1) end,
    v_is_drink,
    case when NEW.allergens is null and NEW.categories_tags is null then null
         when NEW.allergens ilike '%milk%' or NEW.categories_tags ilike '%dairy%' then true else false end,
    case when NEW.categories_tags is null and NEW.category is null then null
         when NEW.categories_tags ilike '%chocolate%' or NEW.category ilike '%chocolate%' then true else false end,
    case when NEW.ingredients_analysis_tags is null then null
         when NEW.ingredients_analysis_tags ilike '%en:palm-oil-free%' then false
         when NEW.ingredients_analysis_tags ilike '%en:palm-oil%' then true else null end,
    case when NEW.additives_tags is null then null
         when NEW.additives_tags ~* 'e(420|421|95[0-9]|96[0-9])(\D|$)' then true else false end,
    case when NEW.sugar_100g is null then null
         when v_is_drink is true then NEW.sugar_100g <= 2.5 else NEW.sugar_100g <= 5 end,
    case when NEW.fiber_100g is null then null else NEW.fiber_100g >= 6 end,
    case when NEW.protein_100g is null or NEW.kcal_100g is null or NEW.kcal_100g = 0 then null
         else (NEW.protein_100g * 4) >= (0.20 * NEW.kcal_100g) end,
    case when NEW.kcal_100g is null then null
         when v_is_drink is true then NEW.kcal_100g <= 20 else NEW.kcal_100g <= 150 end,
    case when NEW.nova_group is null then null else NEW.nova_group <= 2 end,
    (v_reason is not null), v_reason, v_cluster
  )
  on conflict (barcode) do update set
    data_quality_score    = excluded.data_quality_score,
    ingredient_count      = excluded.ingredient_count,
    is_drink              = excluded.is_drink,
    is_dairy              = excluded.is_dairy,
    is_chocolate          = excluded.is_chocolate,
    has_palm_oil          = excluded.has_palm_oil,
    has_sweeteners        = excluded.has_sweeteners,
    is_low_sugar          = excluded.is_low_sugar,
    is_high_fiber         = excluded.is_high_fiber,
    is_high_protein       = excluded.is_high_protein,
    is_low_kcal           = excluded.is_low_kcal,
    is_less_processed     = excluded.is_less_processed,
    is_swap_relevant      = excluded.is_swap_relevant,
    swap_relevance_reason = excluded.swap_relevance_reason,
    cluster_key           = excluded.cluster_key,
    updated_at            = now();
  return NEW;
end $$;

drop trigger if exists products_compute_features on public.products;
create trigger products_compute_features
  after insert or update on public.products
  for each row execute function public.compute_product_features();

-- ---------------------------------------------------------------------------
-- 5. Representant-selectie: 1 per cluster (hoogste datakwaliteit). Herhaalbaar;
--    draai dit vlak voor elke AI-batch zodat nieuwe producten meelopen.
-- ---------------------------------------------------------------------------
create or replace function public.refresh_swap_representatives()
returns void language plpgsql as $$
begin
  update public.product_features set is_representative = false
  where coalesce(is_swap_relevant, false) = false
    and coalesce(is_representative, false) = true;

  with ranked as (
    select barcode,
      row_number() over (
        partition by cluster_key
        order by data_quality_score desc nulls last, barcode
      ) as rn
    from public.product_features
    where is_swap_relevant and cluster_key is not null
  )
  update public.product_features pf
  set is_representative = (r.rn = 1)
  from ranked r
  where pf.barcode = r.barcode;
end $$;

-- ---------------------------------------------------------------------------
-- 6. EXTRA CHECK: valideer AI-output voordat het product_features raakt.
--    - onbekende vocab-waarde        -> rejected
--    - confidence < 0.6 of ontbreekt -> needs_review
--    - AI zegt 'drank' maar objectief is_drink=false -> needs_review (mismatch)
--    - anders                        -> approved
-- ---------------------------------------------------------------------------
create or replace function public.invalid_vocab(p_field text, p_values text[])
returns text[] language sql stable as $$
  select coalesce(array_agg(p_field || ':' || v), '{}')
  from unnest(p_values) v
  where v is not null
    and not exists (
      select 1 from public.feature_vocabulary fv
      where fv.field = p_field and fv.value = v);
$$;

create or replace function public.validate_staged_features()
returns integer language plpgsql as $$
declare
  r          record;
  v_errors   text[];
  v_is_drink boolean;
  v_mismatch boolean;
  v_count    int := 0;
begin
  for r in select * from public.product_features_staging where validation_status = 'pending' loop
    v_errors := '{}'::text[];
    v_errors := v_errors
      || public.invalid_vocab('snack_type',                  array[r.snack_type])
      || public.invalid_vocab('category_cluster',            array[r.category_cluster])
      || public.invalid_vocab('taste_profile',               r.taste_profile)
      || public.invalid_vocab('texture_profile',             r.texture_profile)
      || public.invalid_vocab('use_moment',                  r.use_moment)
      || public.invalid_vocab('swap_tags',                   r.swap_tags)
      || public.invalid_vocab('recommended_swap_directions', r.recommended_swap_directions);

    select pf.is_drink into v_is_drink from public.product_features pf where pf.barcode = r.barcode;
    v_mismatch := (r.snack_type in ('frisdrank','sap','water','warme_drank','zuiveldrank','alcohol')
                   and v_is_drink is false);

    update public.product_features_staging s set
      validation_errors = v_errors,
      validation_status = case
        when coalesce(array_length(v_errors, 1), 0) > 0 then 'rejected'
        when r.ai_confidence is null or r.ai_confidence < 0.6 or v_mismatch then 'needs_review'
        else 'approved'
      end
    where s.id = r.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

-- ---------------------------------------------------------------------------
-- 7. Goedkeuring: approved staging -> product_features, met label-propagatie
--    naar alle clustergenoten. Objectieve kolommen blijven ongemoeid.
-- ---------------------------------------------------------------------------
create or replace function public.approve_staged_features()
returns integer language plpgsql as $$
declare
  r         record;
  v_cluster text;
  v_count   int := 0;
begin
  for r in select * from public.product_features_staging
           where validation_status = 'approved' and applied_at is null loop
    select cluster_key into v_cluster from public.product_features where barcode = r.barcode;

    update public.product_features pf set
      snack_type                  = r.snack_type,
      category_cluster            = r.category_cluster,
      taste_profile               = r.taste_profile,
      texture_profile             = r.texture_profile,
      use_moment                  = r.use_moment,
      swap_tags                   = r.swap_tags,
      recommended_swap_directions = r.recommended_swap_directions,
      is_sweet                    = r.is_sweet,
      is_salty                    = r.is_salty,
      is_crunchy                  = r.is_crunchy,
      ai_confidence               = r.ai_confidence,
      ai_model                    = r.ai_model,
      ai_enriched_at              = now(),
      updated_at                  = now()
    where (v_cluster is not null and pf.cluster_key = v_cluster)
       or pf.barcode = r.barcode;

    update public.product_features_staging set applied_at = now() where id = r.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;
