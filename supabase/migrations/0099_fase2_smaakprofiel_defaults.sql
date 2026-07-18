-- 0099 — Fase 2: smaakprofiel-defaults per ondubbelzinnige swap-familie.
--
-- PROBLEEM: 6.814 van de 15.129 producten hebben geen is_sweet/is_salty/
-- is_crunchy en ~6.9k hebben een lege taste_profile/texture_profile/
-- use_moment. Dat zijn de producten die nooit door AI-verrijking zijn
-- gegaan. Het swapmodel scoort die velden mee (similarity: 15% per-product
-- signalen, plus de hartig-vs-zoet-poort die in fase 3 komt), dus een NULL
-- betekent nu "neutraal 50" en levert willekeurige swaps op.
--
-- AANPAK: per familie een default-profiel, maar UITSLUITEND voor families
-- waar het profiel ondubbelzinnig uit de familie volgt. Gemengde families
-- (sauces_dips, bread_bakery, ready_meals, meal_components, popcorn zoet-
-- vs-zout, supplements_powders, alle *_non_swap) krijgen GEEN default —
-- die blijven NULL en zijn daarmee eerlijk "onbekend" in plaats van fout.
-- Binnen een familie kan een enkel veld ook NULL blijven als juist dat
-- veld ambigu is (bijv. nuts_seeds is_salty: gezouten én ongezouten).
--
-- GARANTIE: elke update vult alleen waar de waarde NULL (of de array leeg)
-- is. Daarmee wordt geen enkele AI-verrijkte waarde overschreven. Wél
-- worden losse NULL-velden van een verder AI-verrijkt product aangevuld;
-- dat is bedoeld — het gaat om gaten, niet om oordelen.
--
-- ROLLBACK: herstel via _snapshot_0099_before.

create table if not exists public._snapshot_0099_before as
select barcode, is_sweet, is_salty, is_crunchy,
       taste_profile, texture_profile, use_moment
from public.product_features;

create temporary table _family_defaults (
  swap_family     text primary key,
  d_is_sweet      boolean,
  d_is_salty      boolean,
  d_is_crunchy    boolean,
  d_taste         text[],
  d_texture       text[],
  d_moment        text[]
) on commit drop;

insert into _family_defaults values
  -- ---- zoet, ondubbelzinnig -------------------------------------------
  ('chocolate_bars',          true,  false, null,  '{zoet}',          '{zacht}',              '{snack}'),
  ('chocolate_confectionery', true,  false, null,  '{zoet}',          '{zacht}',              '{snack}'),
  ('chocolate_spreads',       true,  false, false, '{zoet}',          '{romig}',              '{ontbijt,lunch}'),
  ('candy_sweets',            true,  false, null,  '{zoet}',          '{taai}',               '{snack}'),
  ('cookies_biscuits',        true,  false, true,  '{zoet}',          '{krokant}',            '{snack}'),
  ('cakes_pastries',          true,  false, false, '{zoet}',          '{zacht}',              '{snack}'),
  ('ice_cream_desserts',      true,  false, false, '{zoet}',          '{romig}',              '{snack}'),
  ('dairy_desserts',          true,  false, false, '{zoet}',          '{romig}',              '{snack}'),
  ('sweet_spreads_other',     true,  false, false, '{zoet}',          '{plakkerig}',          '{ontbijt,lunch}'),
  ('honey_syrups',            true,  false, false, '{zoet}',          '{plakkerig}',          '{ontbijt}'),
  ('jams_fruit_spreads',      true,  false, false, '{zoet,fruitig}',  '{plakkerig}',          '{ontbijt,lunch}'),
  ('cereal_bars',             true,  false, null,  '{zoet}',          '{taai}',               '{snack,ontbijt}'),
  ('protein_bars',            true,  false, null,  '{zoet}',          '{taai}',               '{snack}'),
  ('granola_muesli',          true,  false, true,  '{zoet}',          '{krokant}',            '{ontbijt}'),
  ('breakfast_cereals',       true,  false, true,  '{zoet}',          '{krokant}',            '{ontbijt}'),
  ('fresh_fruit',             true,  false, null,  '{zoet,fruitig}',  null,                   '{snack}'),

  -- ---- hartig, ondubbelzinnig ------------------------------------------
  ('crisps_chips',            false, true,  true,  '{zout}',          '{krokant}',            '{snack}'),
  ('crackers_rice_cakes',     false, true,  true,  '{zout}',          '{krokant}',            '{lunch,snack}'),
  ('fried_snacks',            false, true,  true,  '{zout,umami}',    '{krokant}',            '{snack}'),
  ('meat_snacks',             false, true,  null,  '{zout,umami}',    '{taai}',               '{snack}'),
  ('cheese_snacks',           false, true,  false, '{zout,umami}',    '{zacht}',              '{snack,lunch}'),
  ('cold_cuts',               false, true,  false, '{zout,umami}',    '{zacht}',              '{lunch}'),
  ('savory_spreads',          false, true,  false, '{zout,umami}',    '{romig}',              '{lunch}'),
  ('hummus_legume_spreads',   false, true,  false, '{zout,kruidig}',  '{romig}',              '{lunch,snack}'),
  ('mayonnaise_sauces',       false, true,  false, '{zout}',          '{romig}',              '{lunch,diner}'),
  ('soups',                   false, true,  false, '{zout,umami}',    '{vloeibaar}',          '{lunch,diner}'),
  ('fish_seafood',            false, true,  false, '{zout,umami}',    '{zacht}',              '{lunch,diner}'),
  ('sandwiches_wraps',        false, true,  false, '{zout,umami}',    '{zacht}',              '{lunch}'),
  ('raw_meat',                false, null,  false, '{umami}',         '{zacht}',              '{diner}'),
  ('raw_poultry',             false, null,  false, '{umami}',         '{zacht}',              '{diner}'),
  ('fresh_vegetables',        false, false, null,  null,              null,                   '{diner}'),
  ('cooking_oils_fats',       false, false, false, null,              '{vloeibaar}',          '{diner}'),
  -- nuts_seeds: gezouten EN ongezouten, dus geen is_salty/taste-default.
  ('nuts_seeds',              false, null,  true,  null,              '{krokant}',            '{snack}'),
  -- butter_margarine: gezouten EN ongezouten.
  ('butter_margarine',        false, null,  false, null,              '{romig}',              '{ontbijt,lunch}'),
  -- popcorn: zoet EN zout, dus alleen textuur/moment.
  ('popcorn',                 null,  null,  true,  null,              '{luchtig}',            '{snack}'),
  -- nut_butters: gezoet EN ongezoet.
  ('nut_butters',             null,  null,  false, null,              '{romig}',              '{ontbijt,lunch}'),

  -- ---- dranken ----------------------------------------------------------
  ('water',                   false, false, false, null,              '{vloeibaar}',          '{drinken}'),
  ('soft_drinks_regular',     true,  false, false, '{zoet}',          '{bruisend,vloeibaar}', '{drinken}'),
  ('soft_drinks_light_zero',  true,  false, false, '{zoet}',          '{bruisend,vloeibaar}', '{drinken}'),
  ('fruit_juices',            true,  false, false, '{zoet,fruitig}',  '{vloeibaar}',          '{ontbijt,drinken}'),
  ('smoothies',               true,  false, false, '{zoet,fruitig}',  '{vloeibaar}',          '{ontbijt,drinken}'),
  ('energy_drinks',           true,  false, false, '{zoet}',          '{bruisend,vloeibaar}', '{drinken}'),
  ('sports_drinks',           true,  false, false, '{zoet}',          '{vloeibaar}',          '{drinken}'),
  ('alcohol_drinks',          false, false, false, null,              '{vloeibaar}',          '{drinken}'),
  -- koffie/thee/chocolademelk door elkaar: geen smaak-default.
  ('hot_beverages',           null,  null,  false, null,              '{vloeibaar}',          '{drinken}'),
  -- zuiveldranken/plantaardig/yoghurt: gezoet EN ongezoet.
  ('dairy_drinks',            null,  null,  false, null,              '{vloeibaar}',          '{drinken}'),
  ('plant_based_dairy',       null,  null,  false, null,              '{vloeibaar}',          '{ontbijt,drinken}'),
  ('yoghurt_skyr_quark',      null,  null,  false, null,              '{romig}',              '{ontbijt,snack}');

-- --------------------------------------------------------------------
-- Booleans: alleen waar NULL.
-- --------------------------------------------------------------------
update public.product_features pf
set is_sweet = fd.d_is_sweet
from _family_defaults fd
where fd.swap_family = pf.swap_family
  and fd.d_is_sweet is not null
  and pf.is_sweet is null;

update public.product_features pf
set is_salty = fd.d_is_salty
from _family_defaults fd
where fd.swap_family = pf.swap_family
  and fd.d_is_salty is not null
  and pf.is_salty is null;

update public.product_features pf
set is_crunchy = fd.d_is_crunchy
from _family_defaults fd
where fd.swap_family = pf.swap_family
  and fd.d_is_crunchy is not null
  and pf.is_crunchy is null;

-- --------------------------------------------------------------------
-- Arrays: alleen waar NULL of leeg.
-- --------------------------------------------------------------------
update public.product_features pf
set taste_profile = fd.d_taste
from _family_defaults fd
where fd.swap_family = pf.swap_family
  and fd.d_taste is not null
  and (pf.taste_profile is null or cardinality(pf.taste_profile) = 0);

update public.product_features pf
set texture_profile = fd.d_texture
from _family_defaults fd
where fd.swap_family = pf.swap_family
  and fd.d_texture is not null
  and (pf.texture_profile is null or cardinality(pf.texture_profile) = 0);

update public.product_features pf
set use_moment = fd.d_moment
from _family_defaults fd
where fd.swap_family = pf.swap_family
  and fd.d_moment is not null
  and (pf.use_moment is null or cardinality(pf.use_moment) = 0);

-- --------------------------------------------------------------------
-- De defaulttabel wordt ook persistent vastgelegd, zodat fase 5a (trigger
-- voor nieuwe scans) en de documentatie dezelfde bron gebruiken.
-- --------------------------------------------------------------------
create table if not exists public.swap_family_profile_defaults (
  swap_family     text primary key,
  d_is_sweet      boolean,
  d_is_salty      boolean,
  d_is_crunchy    boolean,
  d_taste         text[],
  d_texture       text[],
  d_moment        text[],
  updated_at      timestamptz not null default now()
);

insert into public.swap_family_profile_defaults
  (swap_family, d_is_sweet, d_is_salty, d_is_crunchy, d_taste, d_texture, d_moment)
select swap_family, d_is_sweet, d_is_salty, d_is_crunchy, d_taste, d_texture, d_moment
from _family_defaults
on conflict (swap_family) do update set
  d_is_sweet   = excluded.d_is_sweet,
  d_is_salty   = excluded.d_is_salty,
  d_is_crunchy = excluded.d_is_crunchy,
  d_taste      = excluded.d_taste,
  d_texture    = excluded.d_texture,
  d_moment     = excluded.d_moment,
  updated_at   = now();

comment on table public.swap_family_profile_defaults is
  'Fase 2 (migratie 0099): smaakprofiel-defaults per ondubbelzinnige swap-familie. Een NULL-veld betekent bewust "ambigu binnen deze familie, niet invullen". Bron voor de backfill en voor de trigger op nieuwe scans (fase 5a).';
