-- 0102 — Handmatige classificaties overleven een aanraking van products.
--
-- GEVONDEN BIJ DE CONTROLE VAN FASE 5. Eén `update products set updated_at`
-- op een AI-verrijkt product, verder niets gewijzigd:
--
--   Melkchocolade (B'tween)
--   herkomst: correction_0073: melkchocolade is een chocoladereep, geen graanreep
--   chocolate_bars  ->  cereal_bars
--
-- OORZAAK: in compute_product_features() stond in de ON CONFLICT-tak
--
--   swap_family = excluded.swap_family,        -- onvoorwaardelijk
--   category_cluster = excluded.category_cluster,
--   ...
--   classification_reason = case when pf.classification_status is null ... end
--
-- De B1-bescherming dekte alleen de classification_*-metadata. De familie
-- zelf werd bij élke insert of update op products herberekend en
-- overschreven. De herkomst bleef daarbij staan, dus een rij kon
-- `audit1_0098: ...` als reden tonen terwijl hij ergens anders in zat.
-- De provenance loog dan over de werkelijke familie -- precies het spoor
-- waarop de hele audit is gecontroleerd.
--
-- OMVANG (gemeten voor deze migratie, over de volledige tabel):
--   1369 producten zouden van familie wisselen bij een aanraking,
--   waarvan  859 uit fase 1-auditmigraties en 145 uit correction_/batch-werk;
--   1783 producten zouden op NULL komen omdat de regel ze niet kent.
--   Samen ruim 3100 rijen, meer dan 20% van de database.
--
-- KEUZE: de audit wint. Die correcties zijn stuk voor stuk met de hand
-- beoordeeld; de regel is een generalisatie. swap_family en de daarvan
-- afgeleide kolommen komen daarom onder dezelfde voorwaarde als
-- classification_status: alleen invullen bij een écht nieuw product.
--
-- Nieuwe scans veranderen niet: die hebben classification_status null en
-- lopen dus onverkort door de regel plus de fase 5a-vangrails uit 0101.
--
-- ROLLBACK: functiedefinitie staat in _snapshot_0102_before.

create table if not exists public._snapshot_0102_before (
  snapshot_key text primary key,
  definition text not null,
  captured_at timestamptz not null default now()
);

insert into public._snapshot_0102_before (snapshot_key, definition)
select 'compute_product_features_before_0102',
       pg_get_functiondef('public.compute_product_features()'::regprocedure)
on conflict (snapshot_key) do nothing;

-- Snapshot van de familietoewijzing zelf, zodat een eventuele terugdraai
-- ook de data kan herstellen.
create table if not exists public._snapshot_0102_families as
select barcode, swap_family, category_cluster, snack_type, product_form,
       consumption_mode, classification_status, classification_reason
from public.product_features;

-- ---------------------------------------------------------------------
-- Tegenstrijdige eigen beslissing: B'tween Melkchocolade.
-- 0073 zei chocoladereep op de productnaam, 0095 (R47) zei granenreep op
-- het merk. Twee handmatige oordelen die elkaar tegenspreken; dat is geen
-- keuze om hier stilzwijgend te beslechten.
-- ---------------------------------------------------------------------
update public.product_features pf
set classification_status = 'review_required',
    classification_reason = 'audit1_0102: 0073 (naam=chocolade) vs 0095/R47 (merk=granenreep) — conflict, review'
from public.products p
where p.barcode = pf.barcode
  and p.brand ~* 'b.?tween'
  and p.name ~* '^melkchocolade$';

-- ---------------------------------------------------------------------
-- Handmatige beslissingen zonder classification_status.
--
-- De B2-bescherming hierboven hangt aan classification_status. Vier rijen
-- dragen een audit-/correctieherkomst maar hebben nooit een status
-- gekregen, waardoor ze door het "nieuw product"-gat blijven vallen en bij
-- een aanraking alsnog herberekend worden. Ze zijn met de hand beoordeeld,
-- dus ze horen de status te hebben die daarbij past.
-- ---------------------------------------------------------------------
update public.product_features
set classification_status = 'classified',
    classified_at = coalesce(classified_at, now())
where classification_status is null
  and swap_family is not null
  and (classification_reason like 'audit1_%' or classification_reason like 'correction_%');

-- ---------------------------------------------------------------------
-- Gepatchte compute_product_features(): B2-bescherming op swap_family.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.compute_product_features()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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

  -- B3 (0102): een *_non_swap familie is per definitie geen swapkandidaat.
  -- Zonder deze uitzondering maakte elke aanraking van products ze weer
  -- relevant, omdat 'heeft een familie' als relevant gold. Dat draaide de
  -- fix uit migratie 0080 terug (539 rijen).
  v_relevant := case
    when v_family like '%\_non\_swap' escape '\' then false
    else (v_reason is not null) or (v_family is not null and v_family <> 'unknown') end;
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
    -- B4 (0102): is_swap_relevant volgde uit de HERBEREKENDE familie, terwijl
    -- swap_family hieronder de bewaarde waarde houdt. Die twee liepen dan uit
    -- elkaar: een rij bleef *_non_swap maar werd wel weer swap-relevant
    -- (108 rijen). Relevantie hoort bij de familie die er werkelijk staat.
    is_swap_relevant      = case when pf.classification_status is null
                                 then excluded.is_swap_relevant else pf.is_swap_relevant end,
    swap_relevance_reason = case when pf.classification_status is null
                                 then excluded.swap_relevance_reason else pf.swap_relevance_reason end,
    cluster_key           = excluded.cluster_key,
    swap_family            = case when pf.classification_status is null then excluded.swap_family else pf.swap_family end,
    category_cluster      = case when pf.classification_status is null then excluded.category_cluster else pf.category_cluster end,
    snack_type             = case when pf.classification_status is null then excluded.snack_type else pf.snack_type end,
    product_form           = case when pf.classification_status is null then excluded.product_form else pf.product_form end,
    consumption_mode       = case when pf.classification_status is null then excluded.consumption_mode else pf.consumption_mode end,
    secondary_consumption_modes = case when pf.classification_status is null then excluded.secondary_consumption_modes else pf.secondary_consumption_modes end,
    usage_context           = case when pf.classification_status is null then excluded.usage_context else pf.usage_context end,
    -- B2 (0102): swap_family en de daarvan afgeleide kolommen staan
    -- hierboven onder dezelfde voorwaarde. Ze werden onvoorwaardelijk
    -- herberekend, waardoor elke aanraking van een products-rij een
    -- handmatige auditcorrectie terugdraaide terwijl classification_reason
    -- bleef staan -- de herkomst loog dan over de werkelijke familie.
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
end $function$
;
