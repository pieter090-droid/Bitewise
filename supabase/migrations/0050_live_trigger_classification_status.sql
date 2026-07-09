-- VOORSTEL — NOG NIET UITGEVOERD. Wacht op expliciet akkoord vóór
-- `supabase db push`. Dit bestand staat lokaal klaar zodat het voorstel
-- controleerbaar is, maar is niet tegen de live database gedraaid.
--
-- B1: lost het architectuurgat op waarbij nieuwe, live gescande producten
-- nooit `classification_status` krijgen, ook niet als `compute_swap_family()`
-- een geldige `swap_family` vindt. Bevestigd met barcode 8000500448052
-- ("kinder buno white", gescand 2026-07-09): swap_family=null,
-- classification_status=null, classified_at=null.
--
-- Belangrijk: schrijft classificatievelden UITSLUITEND wanneer
-- product_features.classification_status nog null is (dus nooit een
-- bestaande batch-/AI-classificatie overschrijven), en uitsluitend wanneer
-- v_family niet null is. Verandert niets aan `products`, niets aan
-- `compute_swap_family()` zelf, niets aan bestaande classificatievelden.

create or replace function public.compute_product_features()
returns trigger
language plpgsql
as $function$
declare
  v_is_drink boolean;
  v_reason   text;
  v_cluster  text;
  v_family   text;
  v_map      record;
  v_relevant boolean;
  v_existing_status text;
  v_status   text;
  v_classified_at timestamptz;
  v_confidence numeric;
  v_reason_text text;
  v_mapping_version int;
  v_fingerprint text;
begin
  v_is_drink := case
    when NEW.categories_tags is null and NEW.pnns_groups_1 is null then null
    when NEW.pnns_groups_1 ilike '%beverage%'
      or NEW.categories_tags ilike '%en:beverages%'
      or NEW.categories_tags ilike '%drinks%' then true
    else false end;

  v_reason := public.compute_swap_relevance(NEW.pnns_groups_1, NEW.pnns_groups_2, NEW.categories_tags);
  v_family := public.compute_swap_family(NEW.name, NEW.category, NEW.categories_tags, NEW.pnns_groups_1, NEW.pnns_groups_2, NEW.brand);
  select * into v_map from public.swap_family_mapping where swap_family = v_family;

  v_relevant := (v_reason is not null) or (v_family is not null and v_family <> 'unknown');
  v_cluster := case when v_relevant
    then public.compute_cluster_key(NEW.categories_tags, NEW.main_category,
                                    NEW.kcal_100g, NEW.sugar_100g, NEW.protein_100g)
    else null end;

  -- B1: bepaal of dit een NIEUW product is (nog geen classification_status)
  -- of een bestaand, al-geclassificeerd product (batch/AI/handmatig).
  select classification_status into v_existing_status
  from public.product_features where barcode = NEW.barcode;

  if v_existing_status is null and v_family is not null then
    v_status         := 'classified';
    v_classified_at  := now();
    v_confidence     := 0.70;
    v_reason_text    := 'live_trigger_compute_swap_family';
    v_mapping_version:= 1;
    v_fingerprint    := md5(
      coalesce(NEW.name,'') || '|' || coalesce(NEW.category,'') || '|' ||
      coalesce(NEW.categories_tags,'') || '|' || coalesce(NEW.pnns_groups_1,'') || '|' ||
      coalesce(NEW.pnns_groups_2,'') || '|' || coalesce(NEW.ingredients_text,'') || '|' ||
      coalesce(NEW.ingredients_tags,'')
    );
    -- matched_rule_id blijft NULL: compute_swap_family() is een functie,
    -- geen regel-tabel-lookup, en geeft dus geen betrouwbare rule_id terug.
  else
    -- bestaande status (classified/review_required/null via eerdere batch)
    -- blijft ONGEWIJZIGD; bij v_existing_status is null en v_family is null
    -- blijft status ook gewoon null (geen family gevonden = terecht onbeoordeeld).
    v_status := v_existing_status;
    v_classified_at := null;
    v_confidence := null;
    v_reason_text := null;
    v_mapping_version := null;
    v_fingerprint := null;
  end if;

  insert into public.product_features as pf (
    barcode, data_quality_score, ingredient_count,
    is_drink, is_dairy, is_chocolate, has_palm_oil, has_sweeteners,
    is_low_sugar, is_high_fiber, is_high_protein, is_low_kcal, is_less_processed,
    is_swap_relevant, swap_relevance_reason, cluster_key,
    swap_family, category_cluster, snack_type, product_form, consumption_mode,
    secondary_consumption_modes, usage_context,
    classification_status, classified_at, classification_confidence,
    classification_reason, mapping_version, source_fingerprint
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
    v_relevant,
    coalesce(v_reason, case when v_relevant then 'swap_family_v2' else null end),
    v_cluster,
    v_family,
    coalesce(v_map.category_cluster, null), coalesce(v_map.snack_type, null),
    coalesce(v_map.product_form, null), coalesce(v_map.consumption_mode, null),
    coalesce(v_map.secondary_consumption_modes, '{}'), coalesce(v_map.usage_context, '{}'),
    v_status, v_classified_at, v_confidence, v_reason_text, v_mapping_version, v_fingerprint
  )
  on conflict (barcode) do update set
    data_quality_score    = excluded.data_quality_score,
    ingredient_count      = excluded.ingredient_count,
    is_drink              = excluded.is_drink,
    is_dairy              = excluded.is_dairy,
    is_chocolate           = excluded.is_chocolate,
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
    swap_family            = excluded.swap_family,
    category_cluster      = excluded.category_cluster,
    snack_type             = excluded.snack_type,
    product_form           = excluded.product_form,
    consumption_mode       = excluded.consumption_mode,
    secondary_consumption_modes = excluded.secondary_consumption_modes,
    usage_context           = excluded.usage_context,
    -- B1: alleen classificatievelden overschrijven als ze nu nog null zijn
    -- (dus alleen bij een écht nieuw product) — bestaande batch/AI-waarden
    -- blijven altijd staan, want pf.classification_status is dan al gevuld.
    classification_status      = case when pf.classification_status is null then excluded.classification_status else pf.classification_status end,
    classified_at               = case when pf.classification_status is null then excluded.classified_at else pf.classified_at end,
    classification_confidence   = case when pf.classification_status is null then excluded.classification_confidence else pf.classification_confidence end,
    classification_reason       = case when pf.classification_status is null then excluded.classification_reason else pf.classification_reason end,
    mapping_version              = case when pf.classification_status is null then excluded.mapping_version else pf.mapping_version end,
    source_fingerprint           = case when pf.classification_status is null then excluded.source_fingerprint else pf.source_fingerprint end,
    updated_at            = now();
  return NEW;
end $function$;

-- POSTFLIGHT (read-only, uit te voeren na deze migratie):
-- select count(*) from product_features where swap_family is not null and classification_status is null; -- moet 0 blijven
-- update products set updated_at = now() where barcode = '8000500448052'; -- forceert de trigger opnieuw, dry-run-test
-- select classification_status, classified_at, classification_reason from product_features where barcode='8000500448052'; -- moet nu 'classified'/now()/'live_trigger_compute_swap_family' zijn ALS swap_family gevonden wordt (nu nog null, want geen regel dekt "kinder buno white" totdat 0051 het merkvangnet toevoegt)
-- select count(*) from product_features_resolved; -- moet exact gelijk blijven aan aantal products (geen rijen verloren/verdubbeld)

-- ROLLBACK: create or replace function public.compute_product_features() <exacte vorige definitie, vóór deze migratie>;
-- (de vorige definitie staat in migratiehistorie; geen data-rollback nodig, want dit wijzigt alleen functiegedrag,
--  geen bestaande rijen worden aangeraakt door deze migratie zelf)
