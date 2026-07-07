-- ---------------------------------------------------------------------------
-- SwapScore-model v2: swap_family / product_form / consumption_mode /
-- usage_context. Lost het "Nutella -> Merci"-probleem op: snack_type/
-- category_cluster/taste_profile/texture_profile/use_moment leggen geen
-- productVORM of gebruikswijze vast, waardoor een smeersel en een los
-- bonbonstuk als gelijkwaardige swap konden overkomen.
--
-- Alles hieronder is puur regelgebaseerd (geen AI, geen kosten) en additief:
-- geen bestaande kolom, tabel of rij wordt aangepast/verwijderd. De live
-- poort/score (calculate_swap_score/calculate_similarity_score/
-- SwapScoreCalculator) gebruikt deze velden nog NIET -- dat is een aparte,
-- nog goed te keuren vervolgstap.
-- ---------------------------------------------------------------------------

-- 1. Nieuwe kolommen (product_features + staging-spiegel).
alter table public.product_features
  add column if not exists swap_family text,
  add column if not exists product_form text,
  add column if not exists consumption_mode text,
  add column if not exists usage_context text[] not null default '{}';

alter table public.product_features_staging
  add column if not exists swap_family text,
  add column if not exists product_form text,
  add column if not exists consumption_mode text,
  add column if not exists usage_context text[] not null default '{}';

create index if not exists idx_product_features_swap_family
  on public.product_features(swap_family);
create index if not exists idx_product_features_product_form
  on public.product_features(product_form);
create index if not exists idx_product_features_consumption_mode
  on public.product_features(consumption_mode);
create index if not exists idx_product_features_usage_context_gin
  on public.product_features using gin(usage_context);

-- 2. Vocabulaire (voor toekomstige AI-validatie EN voor de regelgebaseerde
--    functie hieronder -- dezelfde toegestane waarden voor beide paden).
insert into public.feature_vocabulary (field, value) values
  ('swap_family','chocolate_spreads'), ('swap_family','sweet_spreads'), ('swap_family','nut_butters'),
  ('swap_family','chocolate_confectionery'), ('swap_family','chocolate_bars'), ('swap_family','protein_bars'),
  ('swap_family','cereal_bars'), ('swap_family','cookies_biscuits'), ('swap_family','crisps_chips'),
  ('swap_family','popcorn'), ('swap_family','yoghurt_skyr_quark'), ('swap_family','dairy_desserts'),
  ('swap_family','soft_drinks'), ('swap_family','fruit_juices'), ('swap_family','breakfast_cereals'),
  ('swap_family','crackers_rice_cakes'), ('swap_family','nuts_seeds'), ('swap_family','ice_cream_desserts'),
  ('swap_family','cheese_snacks'), ('swap_family','sauces_dips'), ('swap_family','meal_components'),
  ('swap_family','unknown'),
  ('product_form','spread'), ('product_form','bar'), ('product_form','piece'), ('product_form','praline'),
  ('product_form','cookie'), ('product_form','chips'), ('product_form','crisps'), ('product_form','popcorn'),
  ('product_form','drink'), ('product_form','yoghurt_cup'), ('product_form','dessert_cup'), ('product_form','cereal'),
  ('product_form','granola'), ('product_form','powder'), ('product_form','sauce'), ('product_form','dip'),
  ('product_form','cheese_block'), ('product_form','cheese_slice'), ('product_form','nuts_mix'),
  ('product_form','fruit_piece'), ('product_form','unknown'),
  ('consumption_mode','spread_on_bread'), ('consumption_mode','eat_as_piece'), ('consumption_mode','drink'),
  ('consumption_mode','spoonable'), ('consumption_mode','dip'), ('consumption_mode','pour_over'),
  ('consumption_mode','mix_with_yoghurt'), ('consumption_mode','cook_or_prepare'), ('consumption_mode','topping'),
  ('consumption_mode','on_the_go_bar'), ('consumption_mode','unknown'),
  ('usage_context','breakfast'), ('usage_context','snack'), ('usage_context','dessert'), ('usage_context','lunch'),
  ('usage_context','after_sport'), ('usage_context','on_the_go'), ('usage_context','topping'),
  ('usage_context','treat'), ('usage_context','cooking'), ('usage_context','unknown')
on conflict (field, value) do nothing;

-- 3. Consistentie-mapping: welke product_form hoort normaliter bij welke
--    swap_family. Puur voor latere validatie (needs_review bij afwijking) --
--    voorkomt dat swap_family/product_form uit elkaar kunnen lopen zoals
--    category_cluster/snack_type dat eerder deden.
create table if not exists public.swap_family_expected_form (
  swap_family text primary key,
  expected_product_form text not null
);
insert into public.swap_family_expected_form (swap_family, expected_product_form) values
  ('chocolate_spreads','spread'), ('sweet_spreads','spread'), ('nut_butters','spread'),
  ('chocolate_confectionery','praline'), ('chocolate_bars','bar'), ('protein_bars','bar'),
  ('cereal_bars','bar'), ('cookies_biscuits','cookie'), ('crisps_chips','chips'),
  ('popcorn','popcorn'), ('yoghurt_skyr_quark','yoghurt_cup'), ('dairy_desserts','dessert_cup'),
  ('soft_drinks','drink'), ('fruit_juices','drink'), ('breakfast_cereals','cereal'),
  ('crackers_rice_cakes','cookie'), ('nuts_seeds','nuts_mix'), ('ice_cream_desserts','dessert_cup'),
  ('cheese_snacks','cheese_block'), ('sauces_dips','sauce')
on conflict (swap_family) do nothing;
alter table public.swap_family_expected_form enable row level security;
drop policy if exists "expected form readable" on public.swap_family_expected_form;
create policy "expected form readable" on public.swap_family_expected_form for select using (true);

-- 4. Regelgebaseerde afleiding (gratis, geen AI). Meest-specifieke patronen
--    eerst; geen match -> NULL (nooit gokken, zelfde principe als overal
--    elders in dit model). 'unknown' als letterlijke waarde is gereserveerd
--    voor een AI die expliciet "weet ik niet" concludeert, niet voor hier.
create or replace function public.compute_swap_family_fields(
  p_name text, p_category text, p_categories_tags text, p_pnns1 text, p_pnns2 text
) returns table(swap_family text, product_form text, consumption_mode text, usage_context text[])
language plpgsql immutable as $$
declare
  n text := coalesce(p_name, '');
  c text := coalesce(p_category, '') || ' ' || coalesce(p_categories_tags, '');
  p text := coalesce(p_pnns1, '') || ' ' || coalesce(p_pnns2, '');
begin
  if n ~* 'pindakaas|peanut butter|amandelpasta|notenpasta|cashewpasta' then
    return query select 'nut_butters', 'spread', 'spread_on_bread', array['breakfast','topping'];
  elsif n ~* 'nutella|chocopasta|choco.?pasta' or c ~* 'chocolate.?spread|cocoa.and.hazelnut' then
    return query select 'chocolate_spreads', 'spread', 'spread_on_bread', array['breakfast','topping'];
  elsif n ~* 'jam|confiture|marmelade|hagelslag' or c ~* 'jam|confiture' then
    return query select 'sweet_spreads', 'spread', 'spread_on_bread', array['breakfast','topping'];
  elsif c ~* 'pralines|bonbons' or n ~* 'bonbon|praline|\mmerci\M' then
    return query select 'chocolate_confectionery', 'praline', 'eat_as_piece', array['snack','treat'];
  elsif n ~* 'eiwitreep|protein bar' or c ~* 'protein.?bar' then
    return query select 'protein_bars', 'bar', 'on_the_go_bar', array['after_sport','on_the_go'];
  elsif n ~* 'mueslireep|cerealreep|granolareep' or c ~* 'cereal.?bar' then
    return query select 'cereal_bars', 'bar', 'on_the_go_bar', array['snack','on_the_go'];
  elsif n ~* 'chocoladereep|candy bar' or c ~* 'chocolate.?bar' then
    return query select 'chocolate_bars', 'bar', 'on_the_go_bar', array['snack','treat'];
  elsif p ~* 'biscuits|cookies' or n ~* '\mkoek|cookie' then
    return query select 'cookies_biscuits', 'cookie', 'eat_as_piece', array['snack','treat'];
  elsif n ~* 'cracker|beschuit|rice cake|knackebrod' or c ~* 'cracker' then
    return query select 'crackers_rice_cakes', 'cookie', 'eat_as_piece', array['snack'];
  elsif n ~* 'popcorn' or c ~* 'popcorn' then
    return query select 'popcorn', 'popcorn', 'eat_as_piece', array['snack'];
  elsif n ~* 'chips|crisps' or c ~* 'chips|crisps' then
    return query select 'crisps_chips', 'chips', 'eat_as_piece', array['snack'];
  elsif (p ~* 'yogurt' or n ~* 'yoghurt|skyr|kwark|quark')
        and not (n ~* 'drink|drinkyoghurt' or c ~* 'drinkable') then
    return query select 'yoghurt_skyr_quark', 'yoghurt_cup', 'spoonable', array['breakfast','snack'];
  elsif n ~* 'pudding|mousse|\mvla\M|dessert' and p ~* 'dairy|milk' then
    return query select 'dairy_desserts', 'dessert_cup', 'spoonable', array['dessert','snack'];
  elsif n ~* '\mijs\M|ice cream|sorbet|gelato' then
    return query select 'ice_cream_desserts', 'dessert_cup', 'spoonable', array['dessert','treat'];
  elsif p ~* 'cheese' or n ~* '\mkaas\M|cheese' then
    if n ~* 'plak|slice' then
      return query select 'cheese_snacks', 'cheese_slice', 'eat_as_piece', array['snack','lunch'];
    else
      return query select 'cheese_snacks', 'cheese_block', 'eat_as_piece', array['snack','lunch'];
    end if;
  elsif n ~* 'cola|frisdrank|\msoda\M|limonade|energy ?drink' then
    return query select 'soft_drinks', 'drink', 'drink', array['on_the_go']::text[];
  elsif n ~* '\msap\M|juice' or c ~* 'juice' then
    return query select 'fruit_juices', 'drink', 'drink', array['breakfast','on_the_go'];
  elsif p ~* 'breakfast cereal' or n ~* 'muesli|cornflakes|granola|ontbijtgranen' then
    return query select 'breakfast_cereals', 'cereal', 'pour_over', array['breakfast'];
  elsif p ~* 'nuts' or n ~* 'noten|zaden|amandelen|cashew|walnoot|hazelnoot' then
    return query select 'nuts_seeds', 'nuts_mix', 'eat_as_piece', array['snack'];
  elsif n ~* 'hummus|\mdip\M|saus|sauce|dressing' or p ~* 'sauce|dressing' then
    return query select 'sauces_dips', 'dip', 'dip', array['snack','cooking'];
  elsif p ~* 'composite' or n ~* 'maaltijd|salade|\mmeal\M' then
    return query select 'meal_components', 'unknown', 'cook_or_prepare', array['lunch','cooking'];
  else
    return query select null::text, null::text, null::text, '{}'::text[];
  end if;
end $$;

-- 5. Trigger uitbreiden: bestaande compute_product_features() vult nu ook de
--    4 nieuwe velden mee, zelfde insert/on-conflict-patroon, alle bestaande
--    kolommen exact ongewijzigd.
create or replace function public.compute_product_features()
returns trigger language plpgsql as $$
declare
  v_is_drink boolean;
  v_reason   text;
  v_cluster  text;
  v_family   record;
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

  select * into v_family from public.compute_swap_family_fields(
    NEW.name, NEW.category, NEW.categories_tags, NEW.pnns_groups_1, NEW.pnns_groups_2);

  insert into public.product_features as pf (
    barcode, data_quality_score, ingredient_count,
    is_drink, is_dairy, is_chocolate, has_palm_oil, has_sweeteners,
    is_low_sugar, is_high_fiber, is_high_protein, is_low_kcal, is_less_processed,
    is_swap_relevant, swap_relevance_reason, cluster_key,
    swap_family, product_form, consumption_mode, usage_context
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
    (v_reason is not null), v_reason, v_cluster,
    v_family.swap_family, v_family.product_form, v_family.consumption_mode,
    coalesce(v_family.usage_context, '{}')
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
    swap_family           = excluded.swap_family,
    product_form          = excluded.product_form,
    consumption_mode      = excluded.consumption_mode,
    usage_context         = excluded.usage_context,
    updated_at            = now();
  return NEW;
end $$;

-- 6. Eenmalige backfill: bestaande rijen krijgen de 4 nieuwe velden met
--    terugwerkende kracht, zonder enige andere kolom aan te raken.
update public.product_features pf set
  swap_family      = v.swap_family,
  product_form     = v.product_form,
  consumption_mode = v.consumption_mode,
  usage_context    = coalesce(v.usage_context, '{}'),
  updated_at       = now()
from public.products p,
     lateral public.compute_swap_family_fields(
       p.name, p.category, p.categories_tags, p.pnns_groups_1, p.pnns_groups_2) v
where p.barcode = pf.barcode
  and (pf.swap_family is distinct from v.swap_family
    or pf.product_form is distinct from v.product_form
    or pf.consumption_mode is distinct from v.consumption_mode);

-- 7. Validatie uitbreiden: swap_family/product_form-afwijking van de
--    verwachte combinatie -> needs_review i.p.v. stilzwijgend goedkeuren.
--    Werkt nu al mee in de bestaande AI-validatie, ook al draait er nog geen
--    AI-verrijking voor deze specifieke velden.
create or replace function public.validate_staged_features()
returns integer language plpgsql as $$
declare
  r          record;
  v_errors   text[];
  v_is_drink boolean;
  v_mismatch boolean;
  v_form_mismatch boolean;
  v_expected text;
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
      || public.invalid_vocab('recommended_swap_directions', r.recommended_swap_directions)
      || public.invalid_vocab('swap_family',                 array[r.swap_family])
      || public.invalid_vocab('product_form',                array[r.product_form])
      || public.invalid_vocab('consumption_mode',             array[r.consumption_mode])
      || public.invalid_vocab('usage_context',                r.usage_context);

    select pf.is_drink into v_is_drink from public.product_features pf where pf.barcode = r.barcode;
    v_mismatch := (r.snack_type in ('frisdrank','sap','water','warme_drank','zuiveldrank','alcohol')
                   and v_is_drink is false);

    select expected_product_form into v_expected
      from public.swap_family_expected_form where swap_family = r.swap_family;
    v_form_mismatch := (v_expected is not null and r.product_form is not null and v_expected <> r.product_form);

    update public.product_features_staging s set
      validation_errors = v_errors,
      validation_status = case
        when coalesce(array_length(v_errors, 1), 0) > 0 then 'rejected'
        when r.ai_confidence is null or r.ai_confidence < 0.6 or v_mismatch or v_form_mismatch then 'needs_review'
        else 'approved'
      end
    where s.id = r.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;
