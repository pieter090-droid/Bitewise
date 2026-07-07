-- 0009_swapscore_model.sql
-- SwapScore-model: gewichten, groepen, bewerkingskwaliteit + de reken-
-- functies (spec + testoracle -- de app rekent straks zelf in Dart,
-- deze functies zijn de referentie-implementatie + testbasis voor de
-- AI-kwaliteitscheck uit migratie 0010).

-- ---------------------------------------------------------------------------
-- 1. Kleine helper: overlap-ratio tussen twee tag-arrays (Jaccard-achtig).
-- ---------------------------------------------------------------------------
create or replace function public.array_overlap_ratio(a text[], b text[])
returns numeric language sql immutable as $$
  select case
    when a is null or b is null
      or coalesce(array_length(a,1),0) = 0 or coalesce(array_length(b,1),0) = 0
    then null
    else (select count(*)::numeric from unnest(a) x where x = any(b))
         / greatest(array_length(a,1), array_length(b,1))
  end;
$$;

-- ---------------------------------------------------------------------------
-- 2. product_features.processing_quality_score (vult automatisch, zie stap 4)
-- ---------------------------------------------------------------------------
alter table public.product_features
  add column if not exists processing_quality_score numeric;

-- ---------------------------------------------------------------------------
-- 3. swap_score_weights -- de 6 gewichten als data, niet hardcoded.
-- ---------------------------------------------------------------------------
create table if not exists public.swap_score_weights (
  id                          uuid primary key default gen_random_uuid(),
  name                        text not null unique,
  weight_goal_match           numeric not null,
  weight_nutrition_improvement numeric not null,
  weight_day_context          numeric not null,
  weight_similarity           numeric not null,
  weight_processing_quality   numeric not null,
  weight_data_quality         numeric not null,
  is_active                   boolean not null default true,
  created_at                  timestamptz not null default now()
);

insert into public.swap_score_weights
  (name, weight_goal_match, weight_nutrition_improvement, weight_day_context,
   weight_similarity, weight_processing_quality, weight_data_quality)
values ('default', 30, 25, 15, 15, 10, 5)
on conflict (name) do nothing;

alter table public.swap_score_weights enable row level security;
drop policy if exists "weights readable" on public.swap_score_weights;
create policy "weights readable" on public.swap_score_weights for select using (true);

-- ---------------------------------------------------------------------------
-- 4. swap_recommendation_groups -- UX-groepen als config (geen hardcoded lijst).
--    rule_column/rule_direction = null betekent "gebruik de algehele ranking"
--    (zoals bij 'Beste keuze voor vandaag').
-- ---------------------------------------------------------------------------
create table if not exists public.swap_recommendation_groups (
  id             uuid primary key default gen_random_uuid(),
  slug           text not null unique,
  label          text not null,
  rule_column    text,
  rule_swap_tag  text,
  rule_direction text,
  sort_order     integer not null default 0,
  is_active      boolean not null default true
);

insert into public.swap_recommendation_groups
  (slug, label, rule_column, rule_direction, sort_order) values
  ('beste_keuze_vandaag',           'Beste keuze voor vandaag', null,               null,                     10),
  ('minder_suiker',                 'Minder suiker',            'is_low_sugar',     'naar_minder_suiker',     20),
  ('meer_eiwit',                    'Meer eiwit',               'is_high_protein',  'naar_meer_eiwit',        30),
  ('minder_kcal',                   'Minder kcal',              'is_low_kcal',      'naar_minder_kcal',       40),
  ('minder_bewerkt',                'Minder bewerkt',           'is_less_processed','naar_minder_bewerkt',    50),
  ('zelfde_smaak_kleinere_portie',  'Zelfde smaak, kleinere portie', null,          'naar_kleinere_portie',   60)
on conflict (slug) do nothing;

alter table public.swap_recommendation_groups enable row level security;
drop policy if exists "groups readable" on public.swap_recommendation_groups;
create policy "groups readable" on public.swap_recommendation_groups for select using (true);

-- ---------------------------------------------------------------------------
-- 5. compute_product_features (0006) uitgebreid met processing_quality_score.
--    Volledig rule-based: NOVA is BONUS (nooit eis, punt 6 uit de dubbelcheck-
--    lijst), ontbrekende signalen blijven neutraal i.p.v. het product te
--    benadelen.
-- ---------------------------------------------------------------------------
create or replace function public.compute_product_features()
returns trigger language plpgsql as $$
declare
  v_is_drink   boolean;
  v_reason     text;
  v_cluster    text;
  v_is_less_processed boolean;
  v_ingredient_count integer;
  v_processing numeric;
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

  v_ingredient_count := case when nullif(trim(NEW.ingredients_tags), '') is null then null
    else array_length(string_to_array(NEW.ingredients_tags, ','), 1) end;

  v_is_less_processed := case when NEW.nova_group is null then null else NEW.nova_group <= 2 end;

  -- Bewerkingskwaliteit: start neutraal (50), NOVA is bonus/malus, nooit eis.
  v_processing := 50
    + case NEW.nova_group when 1 then 30 when 2 then 15 when 3 then -15 when 4 then -30 else 0 end
    + case v_is_less_processed when true then 10 when false then -10 else 0 end
    + case
        when NEW.additives_n is null then 0
        when NEW.additives_n = 0 then 10
        when NEW.additives_n <= 2 then 0
        when NEW.additives_n <= 5 then -10
        else -20 end
    + case
        when v_ingredient_count is null then 0
        when v_ingredient_count <= 5 then 5
        when v_ingredient_count > 15 then -5
        else 0 end;
  v_processing := greatest(0, least(100, v_processing));

  insert into public.product_features as pf (
    barcode, data_quality_score, ingredient_count,
    is_drink, is_dairy, is_chocolate, has_palm_oil, has_sweeteners,
    is_low_sugar, is_high_fiber, is_high_protein, is_low_kcal, is_less_processed,
    is_swap_relevant, swap_relevance_reason, cluster_key, processing_quality_score
  ) values (
    NEW.barcode,
    public.calculate_product_data_quality(NEW.barcode),
    v_ingredient_count,
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
    v_is_less_processed,
    (v_reason is not null), v_reason, v_cluster, v_processing
  )
  on conflict (barcode) do update set
    data_quality_score       = excluded.data_quality_score,
    ingredient_count         = excluded.ingredient_count,
    is_drink                 = excluded.is_drink,
    is_dairy                 = excluded.is_dairy,
    is_chocolate             = excluded.is_chocolate,
    has_palm_oil             = excluded.has_palm_oil,
    has_sweeteners           = excluded.has_sweeteners,
    is_low_sugar             = excluded.is_low_sugar,
    is_high_fiber            = excluded.is_high_fiber,
    is_high_protein          = excluded.is_high_protein,
    is_low_kcal              = excluded.is_low_kcal,
    is_less_processed        = excluded.is_less_processed,
    is_swap_relevant         = excluded.is_swap_relevant,
    swap_relevance_reason    = excluded.swap_relevance_reason,
    cluster_key              = excluded.cluster_key,
    processing_quality_score = excluded.processing_quality_score,
    updated_at               = now();
  return NEW;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Backfill: processing_quality_score voor bestaande rijen (eenmalig,
--    idempotent -- herberekent puur uit products, geen AI).
-- ---------------------------------------------------------------------------
update public.product_features pf set
  processing_quality_score = least(100, greatest(0,
      50
    + case p.nova_group when 1 then 30 when 2 then 15 when 3 then -15 when 4 then -30 else 0 end
    + case pf.is_less_processed when true then 10 when false then -10 else 0 end
    + case
        when p.additives_n is null then 0
        when p.additives_n = 0 then 10
        when p.additives_n <= 2 then 0
        when p.additives_n <= 5 then -10
        else -20 end
    + case
        when pf.ingredient_count is null then 0
        when pf.ingredient_count <= 5 then 5
        when pf.ingredient_count > 15 then -5
        else 0 end
  )),
  updated_at = now()
from public.products p
where pf.barcode = p.barcode and pf.processing_quality_score is null;

-- ---------------------------------------------------------------------------
-- 7. calculate_similarity_score -- losse, herbruikbare vergelijkbaarheids-
--    functie (ook nodig voor UX-groep "Zelfde smaak, kleinere portie").
-- ---------------------------------------------------------------------------
create or replace function public.calculate_similarity_score(p_from text, p_to text)
returns table(score numeric, breakdown jsonb) language plpgsql stable as $$
declare
  f record; t record;
  v_cluster_match boolean;
  v_type_match    boolean;
  v_taste   numeric;
  v_texture numeric;
  v_moment  numeric;
  v_score   numeric;
begin
  select category_cluster, snack_type, taste_profile, texture_profile, use_moment
    into f from public.product_features where barcode = p_from;
  select category_cluster, snack_type, taste_profile, texture_profile, use_moment
    into t from public.product_features where barcode = p_to;

  v_cluster_match := (f.category_cluster is not null and f.category_cluster = t.category_cluster);
  v_type_match    := (f.snack_type is not null and f.snack_type = t.snack_type);
  v_taste   := public.array_overlap_ratio(f.taste_profile, t.taste_profile);
  v_texture := public.array_overlap_ratio(f.texture_profile, t.texture_profile);
  v_moment  := public.array_overlap_ratio(f.use_moment, t.use_moment);

  v_score := (case when v_cluster_match then 40 else 0 end)
           + (case when v_type_match then 20 else 0 end)
           + coalesce(v_taste, 0.5)   * 15
           + coalesce(v_texture, 0.5) * 15
           + coalesce(v_moment, 0.5)  * 10;

  return query select least(100, greatest(0, v_score)), jsonb_build_object(
    'category_cluster_match', v_cluster_match,
    'snack_type_match', v_type_match,
    'taste_overlap', v_taste, 'texture_overlap', v_texture, 'use_moment_overlap', v_moment
  );
end $$;

-- ---------------------------------------------------------------------------
-- 8. calculate_swap_score -- de volledige SwapScore (spec + testoracle).
--    NULL-veilig (ontbrekende macro = deelscore overslaan, nooit als 0),
--    harde category_cluster-poort, allergeen-voorzichtig (nooit "veilig"
--    beloven), 100g-basis (serving-data wordt hier niet gebruikt).
-- ---------------------------------------------------------------------------
create or replace function public.calculate_swap_score(
  p_from text, p_to text, p_goal text default null, p_day_context jsonb default '{}'::jsonb
) returns table(score numeric, breakdown jsonb, reasons text[], warnings text[])
language plpgsql stable as $$
declare
  f record; t record; w record;
  v_goal_match numeric := 0;
  v_nutrition  numeric := 0;
  v_daycontext numeric := 0;
  v_similarity numeric; v_sim_breakdown jsonb;
  v_processing numeric := 0;
  v_dataquality numeric := 0;
  v_total numeric;
  v_reasons text[] := '{}';
  v_warnings text[] := '{}';
  v_kcal_remaining numeric;
  v_sugar_remaining numeric;
begin
  select * into w from public.swap_score_weights where is_active = true order by created_at desc limit 1;

  select p.kcal_100g, p.sugar_100g, p.protein_100g, p.fiber_100g, p.salt_100g, p.allergens,
         pf.category_cluster, pf.processing_quality_score, pf.data_quality_score, pf.ai_confidence
    into f
    from public.products p join public.product_features pf on pf.barcode = p.barcode
    where p.barcode = p_from;

  select p.kcal_100g, p.sugar_100g, p.protein_100g, p.fiber_100g, p.salt_100g, p.allergens,
         pf.category_cluster, pf.processing_quality_score, pf.data_quality_score, pf.ai_confidence
    into t
    from public.products p join public.product_features pf on pf.barcode = p.barcode
    where p.barcode = p_to;

  -- Harde poort: nooit chocolade -> komkommer. Buiten hetzelfde cluster
  -- komt een kandidaat niet eens in de ranking terecht.
  if f.category_cluster is null or f.category_cluster is distinct from t.category_cluster then
    return query select 0::numeric,
      jsonb_build_object('excluded_reason', 'category_cluster_mismatch'),
      array[]::text[], array['dit product is niet vergelijkbaar genoeg om als swap te tonen']::text[];
    return;
  end if;

  -- Voedingsverbetering (NULL-veilig: ontbrekend = overslaan, nooit 0).
  if f.sugar_100g is not null and t.sugar_100g is not null and f.sugar_100g > 0 then
    v_nutrition := v_nutrition + greatest(-1, least(1, (f.sugar_100g - t.sugar_100g) / f.sugar_100g)) * 40;
    if t.sugar_100g < f.sugar_100g then
      v_reasons := v_reasons || format('%s%% minder suiker', round((1 - t.sugar_100g/f.sugar_100g)*100));
    end if;
  end if;
  if f.kcal_100g is not null and t.kcal_100g is not null and f.kcal_100g > 0 then
    v_nutrition := v_nutrition + greatest(-1, least(1, (f.kcal_100g - t.kcal_100g) / f.kcal_100g)) * 30;
  end if;
  if f.protein_100g is not null and t.protein_100g is not null then
    v_nutrition := v_nutrition + greatest(-1, least(1, (t.protein_100g - f.protein_100g) / greatest(f.protein_100g,5))) * 20;
    if t.protein_100g > f.protein_100g then
      v_reasons := v_reasons || format('%sg meer eiwit', round(t.protein_100g - f.protein_100g));
    end if;
  end if;
  if f.fiber_100g is not null and t.fiber_100g is not null then
    v_nutrition := v_nutrition + greatest(-1, least(1, (t.fiber_100g - f.fiber_100g) / greatest(f.fiber_100g,3))) * 10;
  end if;
  v_nutrition := greatest(0, least(100, 50 + v_nutrition));

  -- Doel-match (afhankelijk van gekozen gebruikersdoel; NULL-veilig).
  v_goal_match := case p_goal
    when 'minder_suiker'    then (case when t.sugar_100g is null then 50
                                   when f.sugar_100g is null or f.sugar_100g = 0 then 50
                                   else greatest(0, least(100, 50 + (1 - t.sugar_100g/greatest(f.sugar_100g,0.1))*50)) end)
    when 'afvallen'         then (case when t.kcal_100g is null then 50
                                   when f.kcal_100g is null or f.kcal_100g = 0 then 50
                                   else greatest(0, least(100, 50 + (1 - t.kcal_100g/greatest(f.kcal_100g,1))*50)) end)
    when 'spieropbouw'      then (case when t.protein_100g is null then 50
                                   else greatest(0, least(100, 50 + (t.protein_100g - coalesce(f.protein_100g,0))*3)) end)
    when 'gezonder_eten'    then coalesce(t.processing_quality_score, 50)
    when 'gewicht_behouden' then (case when f.kcal_100g is null or t.kcal_100g is null then 50
                                   else 100 - least(100, abs(f.kcal_100g - t.kcal_100g)) end)
    else 50
  end;

  -- Dagcontext: ontbrekend = neutraal (halve bijdrage), nooit hard afstraffen.
  v_kcal_remaining := (p_day_context->>'kcal_remaining')::numeric;
  v_sugar_remaining := (p_day_context->>'sugar_remaining_g')::numeric;
  if v_kcal_remaining is not null and t.kcal_100g is not null then
    v_daycontext := case when v_kcal_remaining < 300 and t.kcal_100g < coalesce(f.kcal_100g, t.kcal_100g+1)
                          then 90 else 50 end;
  else
    v_daycontext := 50;
  end if;
  if v_sugar_remaining is not null and t.sugar_100g is not null and v_sugar_remaining < 10
     and f.sugar_100g is not null and t.sugar_100g < f.sugar_100g then
    v_daycontext := least(100, v_daycontext + 20);
  end if;

  select * into v_similarity, v_sim_breakdown from public.calculate_similarity_score(p_from, p_to);

  v_processing := coalesce(t.processing_quality_score, 50);
  v_dataquality := coalesce(t.data_quality_score, 50) * 0.7 + coalesce(t.ai_confidence, 0.5) * 100 * 0.3;

  v_total :=
      (v_goal_match   * w.weight_goal_match
     + v_nutrition    * w.weight_nutrition_improvement
     + v_daycontext   * w.weight_day_context
     + v_similarity   * w.weight_similarity
     + v_processing   * w.weight_processing_quality
     + v_dataquality  * w.weight_data_quality)
    / (w.weight_goal_match + w.weight_nutrition_improvement + w.weight_day_context
     + w.weight_similarity + w.weight_processing_quality + w.weight_data_quality);

  -- Allergenen: nooit "onbekend = veilig" (punt 7 uit de dubbelcheck-lijst).
  if f.allergens is null or t.allergens is null or trim(coalesce(t.allergens,'')) = '' then
    v_warnings := v_warnings || 'allergeneninformatie is onvolledig -- controleer het etiket';
  elsif t.allergens is not null and f.allergens is not null and t.allergens <> f.allergens then
    v_warnings := v_warnings || 'allergenen kunnen verschillen van het origineel -- controleer het etiket';
  end if;

  return query select round(v_total, 1),
    jsonb_build_object(
      'goal_match', round(v_goal_match,1), 'nutrition_improvement', round(v_nutrition,1),
      'day_context', round(v_daycontext,1), 'similarity', round(v_similarity,1),
      'similarity_breakdown', v_sim_breakdown,
      'processing_quality', round(v_processing,1), 'data_quality', round(v_dataquality,1)
    ),
    v_reasons, v_warnings;
end $$;
