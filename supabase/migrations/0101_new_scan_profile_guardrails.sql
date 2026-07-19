-- 0101 — Fase 5a: borg nieuwe scans na de bestaande classificatietrigger.
--
-- 1. Vul uitsluitend lege smaak-/textuur-/momentvelden vanuit de persistente
--    tabel swap_family_profile_defaults (0099); kopieer geen defaults.
-- 2. Gebruik voedingswaarden die op products beschikbaar zijn om 0-kcal,
--    vrijwel suikervrije soft_drinks_regular direct af te vangen.
-- 3. Naam/voeding-conflict of onvoldoende bewijs => review_required.
--
-- products blijft raw. Bestaande AI-/handmatige profielwaarden worden nooit
-- overschreven. De triggernaam sorteert bewust na products_compute_features.

create table if not exists public._snapshot_0101_trigger_before (
  snapshot_key text primary key,
  definition text not null,
  captured_at timestamptz not null default now()
);

insert into public._snapshot_0101_trigger_before (snapshot_key, definition)
select 'products_compute_features_function',
       pg_get_functiondef('public.compute_product_features()'::regprocedure)
on conflict (snapshot_key) do nothing;

insert into public._snapshot_0101_trigger_before (snapshot_key, definition)
select 'products_compute_features_trigger', pg_get_triggerdef(oid, true)
from pg_trigger
where tgrelid = 'public.products'::regclass
  and tgname = 'products_compute_features'
on conflict (snapshot_key) do nothing;

create or replace function public.apply_new_scan_profile_guardrails()
returns trigger
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_pf public.product_features%rowtype;
  v_default public.swap_family_profile_defaults%rowtype;
  v_map public.swap_family_mapping%rowtype;
  v_family text;
  v_status text;
  v_reason text;
  v_has_sweeteners boolean;
begin
  select * into v_pf
  from public.product_features
  where barcode = NEW.barcode;

  if not found then
    return NEW;
  end if;

  v_family := v_pf.swap_family;
  v_status := v_pf.classification_status;
  v_reason := v_pf.classification_reason;
  v_has_sweeteners := v_pf.has_sweeteners;

  -- Alleen automatisch door de live trigger geclassificeerde rijen mogen
  -- nutritioneel worden herzien. Batches, AI en handmatige reviews blijven
  -- onaangeraakt. De 0100-backlog is al afzonderlijk gecorrigeerd.
  if v_pf.classification_reason = 'live_trigger_compute_swap_family'
     and v_pf.swap_family = 'soft_drinks_regular'
     and NEW.kcal_100g = 0
     and coalesce(NEW.sugar_100g, 0) <= 0.5 then
    if NEW.name ~* '\mregular\M' then
      v_status := 'review_required';
      v_reason := 'live_trigger_nutrition_conflict: naam zegt regular, voeding zegt zero';
    elsif v_has_sweeteners is not true
          and (NEW.brand ~* '\mspa\M|\mchaudfontaine\M|\mbar le duc\M'
               or NEW.name ~* '\mbronwater\M') then
      v_family := 'water';
      v_reason := 'live_trigger_nutrition_guardrail: 0 kcal ongezoet bronwater';
    elsif v_has_sweeteners is true then
      v_family := 'soft_drinks_light_zero';
      v_reason := 'live_trigger_nutrition_guardrail: 0 kcal + zoetstoffen';
    else
      v_status := 'review_required';
      v_reason := 'live_trigger_nutrition_conflict: regular familie met zero-profiel';
    end if;
  end if;

  if v_family is distinct from v_pf.swap_family then
    select * into v_map
    from public.swap_family_mapping
    where swap_family = v_family;
  end if;

  update public.product_features
  set swap_family = v_family,
      classification_status = v_status,
      classification_reason = v_reason,
      category_cluster = case when v_family is distinct from v_pf.swap_family
                              then v_map.category_cluster else category_cluster end,
      snack_type = case when v_family is distinct from v_pf.swap_family
                        then v_map.snack_type else snack_type end,
      product_form = case when v_family is distinct from v_pf.swap_family
                          then v_map.product_form else product_form end,
      consumption_mode = case when v_family is distinct from v_pf.swap_family
                              then v_map.consumption_mode else consumption_mode end,
      secondary_consumption_modes = case when v_family is distinct from v_pf.swap_family
        then coalesce(v_map.secondary_consumption_modes, '{}')
        else secondary_consumption_modes end,
      usage_context = case when v_family is distinct from v_pf.swap_family
                           then coalesce(v_map.usage_context, '{}') else usage_context end,
      updated_at = now()
  where barcode = NEW.barcode;

  select * into v_default
  from public.swap_family_profile_defaults
  where swap_family = v_family;

  if found then
    update public.product_features
    set is_sweet = coalesce(is_sweet, v_default.d_is_sweet),
        is_salty = coalesce(is_salty, v_default.d_is_salty),
        is_crunchy = coalesce(is_crunchy, v_default.d_is_crunchy),
        taste_profile = case when taste_profile is null or cardinality(taste_profile) = 0
                             then coalesce(v_default.d_taste, taste_profile)
                             else taste_profile end,
        texture_profile = case when texture_profile is null or cardinality(texture_profile) = 0
                               then coalesce(v_default.d_texture, texture_profile)
                               else texture_profile end,
        use_moment = case when use_moment is null or cardinality(use_moment) = 0
                          then coalesce(v_default.d_moment, use_moment)
                          else use_moment end,
        updated_at = now()
    where barcode = NEW.barcode;
  end if;

  return NEW;
end
$function$;

drop trigger if exists products_z_apply_new_scan_guardrails on public.products;
create trigger products_z_apply_new_scan_guardrails
  after insert or update on public.products
  for each row execute function public.apply_new_scan_profile_guardrails();

comment on function public.apply_new_scan_profile_guardrails() is
  'Fase 5a (0101): vult profieldefaults uit 0099 voor nieuwe scans en zet nutritionele familieconflicten op een veilige familie of review_required.';

-- POSTFLIGHT:
-- 1) Geen automatisch geclassificeerde zero-drank blijft regular.
-- 2) Geen gat waar een ondubbelzinnige default beschikbaar is.
-- Zie supabase/phase5_intake_check.sql.

