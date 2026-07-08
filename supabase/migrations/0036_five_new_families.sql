-- Fase 1A (expliciet goedgekeurd). De 5 goedgekeurde nieuwe families.
-- Gewichten/vormen gebaseerd op de
-- steekproeven uit de dry-run rondes (raw meat/poultry/fish: category_cluster
-- hartig, product_form raw_*, consumption_mode cook_or_prepare, expliciet
-- is_swap_relevant_default = false zoals afgesproken -- rauw vlees/vis is
-- geen "snack om te swappen" maar moet wel traceerbaar geclassificeerd zijn).

insert into public.swap_family_mapping
  (swap_family, category_cluster, snack_type, product_form, consumption_mode,
   secondary_consumption_modes, usage_context, related_families, is_swap_relevant_default)
values
  ('raw_poultry', 'hartig', 'vleeswaren_beleg', 'raw_poultry', 'cook_or_prepare',
   '{}', array['cooking'], array['raw_meat','cold_cuts'], false),
  ('raw_meat', 'hartig', 'vleeswaren_beleg', 'raw_meat', 'cook_or_prepare',
   '{}', array['cooking'], array['raw_poultry','fish_seafood'], false),
  ('fish_seafood', 'hartig', 'vleeswaren_beleg', 'fish_piece', 'cook_or_prepare',
   '{}', array['cooking'], array['raw_poultry','raw_meat'], false),
  ('mayonnaise_sauces', 'hartig', 'hartige_snack', 'sauce', 'dip',
   array['spread_on_bread'], array['snack','lunch','cooking'], array['sauces_dips','savory_spreads'], true),
  ('cooking_oils_fats', 'overig', 'overig', 'liquid_fat', 'cook_or_prepare',
   '{}', array['cooking','baking'], array['butter_margarine'], true)
on conflict (swap_family) do update set
  category_cluster = excluded.category_cluster,
  snack_type = excluded.snack_type,
  product_form = excluded.product_form,
  consumption_mode = excluded.consumption_mode,
  secondary_consumption_modes = excluded.secondary_consumption_modes,
  usage_context = excluded.usage_context,
  related_families = excluded.related_families,
  is_swap_relevant_default = excluded.is_swap_relevant_default;

-- Reverse-relaties toevoegen zodat cross-verwijzing symmetrisch is (per de
-- relatie-audit uit de vorige ronde: same_form/same_usage-achtige relaties
-- horen bewust wederzijds te zijn, tenzij er een reden is voor eenrichting).
update public.swap_family_mapping set related_families = array_append(related_families, 'raw_poultry')
  where swap_family in ('raw_meat','cold_cuts') and not ('raw_poultry' = any(related_families));
update public.swap_family_mapping set related_families = array_append(related_families, 'raw_meat')
  where swap_family in ('raw_poultry','fish_seafood') and not ('raw_meat' = any(related_families));
update public.swap_family_mapping set related_families = array_append(related_families, 'fish_seafood')
  where swap_family in ('raw_meat') and not ('fish_seafood' = any(related_families));
update public.swap_family_mapping set related_families = array_append(related_families, 'mayonnaise_sauces')
  where swap_family in ('sauces_dips','savory_spreads') and not ('mayonnaise_sauces' = any(related_families));
update public.swap_family_mapping set related_families = array_append(related_families, 'cooking_oils_fats')
  where swap_family in ('butter_margarine') and not ('cooking_oils_fats' = any(related_families));

-- POSTFLIGHT: select count(*) from swap_family_mapping; -- moet 53 zijn (48+5)
-- select swap_family from swap_family_mapping where swap_family in
--   ('raw_poultry','raw_meat','fish_seafood','mayonnaise_sauces','cooking_oils_fats'); -- moet 5 rijen zijn

-- ROLLBACK: delete from public.swap_family_mapping where swap_family in
--   ('raw_poultry','raw_meat','fish_seafood','mayonnaise_sauces','cooking_oils_fats');
--   (de reverse-relatie-updates hierboven zijn additief op related_families van
--   BESTAANDE rijen -- rollback daarvan vereist een losse array_remove-stap,
--   hieronder als losse, optionele rollback-substap:)
-- update swap_family_mapping set related_families = array_remove(related_families, 'raw_poultry')
--   where swap_family in ('raw_meat','cold_cuts');
-- (herhaal voor de overige 4 toegevoegde reverse-relaties)
