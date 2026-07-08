-- ---------------------------------------------------------------------------
-- Taxonomy v2: swap_family wordt de ENIGE classificatiebeslissing. De 4
-- andere velden (category_cluster, snack_type, product_form, consumption_mode
-- + nieuw: secondary_consumption_modes) worden voortaan DETERMINISTISCH
-- afgeleid uit een mapping-tabel, i.p.v. onafhankelijk gegokt per veld.
-- Dat sluit de hele klasse bugs uit die deze sessie steeds opdook (cola-in-
-- chocolade, kaas-in-cheesecake, hazelnootpasta-in-nuts_seeds): die ontstonden
-- allemaal omdat losse velden uit de pas konden lopen.
--
-- We hergebruiken bewust onze bestaande, al-geteste Nederlandse woordenlijst
-- voor category_cluster/snack_type/product_form/consumption_mode (in plaats
-- van de Engelse taxonomie 1-op-1 over te nemen) -- dat scheelt een volledige
-- her-vertaling van alle UI-labels en al-geverifieerde regels, zonder de
-- kernverbetering (1 beslissing, deterministisch afgeleid, related_families)
-- te verliezen. swap_family zelf IS wel de volledige, uitgebreidere lijst.
-- ---------------------------------------------------------------------------

-- 1. Nieuwe swap_family-waarden (splitsingen/toevoegingen t.o.v. wat we hadden).
insert into public.feature_vocabulary (field, value) values
  ('swap_family','soft_drinks_regular'), ('swap_family','soft_drinks_light_zero'),
  ('swap_family','energy_drinks'), ('swap_family','sports_drinks'), ('swap_family','smoothies'),
  ('swap_family','granola_muesli'), ('swap_family','cakes_pastries'), ('swap_family','meat_snacks'),
  ('swap_family','plant_based_dairy'), ('swap_family','jams_fruit_spreads'), ('swap_family','honey_syrups'),
  ('swap_family','sweet_spreads_other'), ('swap_family','hummus_legume_spreads'),
  ('swap_family','ready_meals'), ('swap_family','sandwiches_wraps'), ('swap_family','supplements_powders')
on conflict (field, value) do nothing;
-- Oude 'soft_drinks' en 'sweet_spreads' zijn vervangen door de fijnere
-- splitsingen hierboven; niet meer als geldige waarde gebruikt, maar we
-- laten de vocab-rij staan (geen destructieve delete op een enum-tabel).

-- Enkele nieuwe waarden op de bestaande velden (minimaal, alleen waar echt nodig).
insert into public.feature_vocabulary (field, value) values
  ('snack_type','smoothie'),
  ('product_form','cake_piece'), ('product_form','meal_tray'), ('product_form','bun_wrap'),
  ('consumption_mode','heat_and_eat')
on conflict (field, value) do nothing;

-- 2. Mapping-tabel: DE bron van waarheid. swap_family -> alle andere velden.
create table if not exists public.swap_family_mapping (
  swap_family                 text primary key,
  category_cluster            text,
  snack_type                  text,
  product_form                text,
  consumption_mode             text,
  secondary_consumption_modes text[] not null default '{}',
  usage_context                text[] not null default '{}',
  related_families             text[] not null default '{}'
);
alter table public.swap_family_mapping enable row level security;
drop policy if exists "mapping readable" on public.swap_family_mapping;
create policy "mapping readable" on public.swap_family_mapping for select using (true);

insert into public.swap_family_mapping
  (swap_family, category_cluster, snack_type, product_form, consumption_mode, secondary_consumption_modes, usage_context, related_families)
values
  ('water', 'drank', 'water', 'drink', 'drink', '{}', array['on_the_go'], array['soft_drinks_light_zero','sports_drinks']),
  ('soft_drinks_regular', 'drank', 'frisdrank', 'drink', 'drink', '{}', array['on_the_go'], array['soft_drinks_light_zero','energy_drinks','fruit_juices']),
  ('soft_drinks_light_zero', 'drank', 'frisdrank', 'drink', 'drink', '{}', array['on_the_go'], array['soft_drinks_regular','water','energy_drinks']),
  ('energy_drinks', 'drank', 'frisdrank', 'drink', 'drink', '{}', array['on_the_go'], array['soft_drinks_regular','soft_drinks_light_zero','sports_drinks']),
  ('sports_drinks', 'drank', 'frisdrank', 'drink', 'drink', '{}', array['after_sport','on_the_go'], array['water','energy_drinks','soft_drinks_light_zero']),
  ('fruit_juices', 'drank', 'sap', 'drink', 'drink', '{}', array['breakfast','on_the_go'], array['smoothies','soft_drinks_regular','water']),
  ('smoothies', 'drank', 'smoothie', 'drink', 'drink', array['on_the_go_bar'], array['snack','breakfast'], array['fruit_juices','dairy_drinks','fresh_fruit']),
  ('hot_beverages', 'drank', 'warme_drank', 'drink', 'drink', '{}', array['breakfast','snack'], array['water','dairy_drinks']),
  ('alcohol_drinks', 'drank', 'alcohol', 'drink', 'drink', '{}', array['treat'], array['soft_drinks_regular','soft_drinks_light_zero']),
  ('fresh_fruit', 'fruit_groente', 'fruit', 'fruit_piece', 'eat_as_piece', array['topping','mix_with_yoghurt'], array['snack','breakfast'], array['fresh_vegetables','smoothies','jams_fruit_spreads']),
  ('fresh_vegetables', 'fruit_groente', 'groente', 'vegetable_piece', 'eat_as_piece', array['dip','cook_or_prepare'], array['snack','lunch'], array['fresh_fruit','sauces_dips','hummus_legume_spreads']),
  ('bread_bakery', 'maaltijd', 'brood_bakkerij', 'bread', 'eat_as_piece', array['spread_on_bread'], array['breakfast','lunch'], array['crackers_rice_cakes','sandwiches_wraps','cakes_pastries']),
  ('breakfast_cereals', 'zoet', 'ontbijtgranen', 'cereal', 'pour_over', array['mix_with_yoghurt'], array['breakfast'], array['granola_muesli','cereal_bars']),
  ('granola_muesli', 'zoet', 'ontbijtgranen', 'granola', 'mix_with_yoghurt', array['topping'], array['breakfast'], array['breakfast_cereals','nuts_seeds','cereal_bars']),
  ('crackers_rice_cakes', 'hartig', 'hartige_snack', 'cookie', 'eat_as_piece', array['spread_on_bread'], array['snack'], array['bread_bakery','crisps_chips','savory_spreads']),
  ('chocolate_bars', 'zoet', 'reep', 'bar', 'eat_as_piece', array['on_the_go_bar'], array['snack','treat'], array['chocolate_confectionery','candy_sweets','cereal_bars']),
  ('chocolate_confectionery', 'zoet', 'chocolade', 'praline', 'eat_as_piece', '{}', array['snack','treat'], array['chocolate_bars','candy_sweets','cookies_biscuits']),
  ('candy_sweets', 'zoet', 'snoep', 'piece', 'eat_as_piece', '{}', array['snack','treat'], array['chocolate_confectionery','chocolate_bars','cookies_biscuits']),
  ('cookies_biscuits', 'zoet', 'zoete_snack', 'cookie', 'eat_as_piece', '{}', array['snack','treat'], array['cakes_pastries','chocolate_confectionery','cereal_bars']),
  ('cakes_pastries', 'zoet', 'brood_bakkerij', 'cake_piece', 'eat_as_piece', '{}', array['snack','treat'], array['cookies_biscuits','bread_bakery','sweet_spreads_other']),
  ('cereal_bars', 'zoet', 'reep', 'bar', 'on_the_go_bar', array['eat_as_piece'], array['snack','on_the_go'], array['protein_bars','granola_muesli','chocolate_bars']),
  ('protein_bars', 'overig', 'supplement', 'bar', 'on_the_go_bar', array['eat_as_piece'], array['after_sport','on_the_go'], array['cereal_bars','chocolate_bars','supplements_powders']),
  ('ice_cream_desserts', 'zuivel', 'ijs', 'dessert_cup', 'spoonable', array['eat_as_piece'], array['dessert','treat'], array['dairy_desserts','chocolate_confectionery','cakes_pastries']),
  ('crisps_chips', 'hartig', 'hartige_snack', 'chips', 'eat_as_piece', '{}', array['snack'], array['popcorn','nuts_seeds','crackers_rice_cakes']),
  ('popcorn', 'hartig', 'hartige_snack', 'popcorn', 'eat_as_piece', '{}', array['snack'], array['crisps_chips','nuts_seeds']),
  ('nuts_seeds', 'hartig', 'noten_zaden', 'nuts_mix', 'eat_as_piece', array['topping','mix_with_yoghurt'], array['snack'], array['popcorn','crisps_chips','granola_muesli']),
  ('cheese_snacks', 'zuivel', 'kaas', 'cheese_block', 'eat_as_piece', array['topping'], array['snack','lunch'], array['nuts_seeds','cold_cuts','savory_spreads']),
  ('meat_snacks', 'hartig', 'vleeswaren_beleg', 'meat_slice', 'eat_as_piece', '{}', array['snack'], array['cold_cuts','cheese_snacks']),
  ('cold_cuts', 'hartig', 'vleeswaren_beleg', 'meat_slice', 'spread_on_bread', array['eat_as_piece','topping'], array['lunch'], array['cheese_snacks','savory_spreads','sandwiches_wraps']),
  ('yoghurt_skyr_quark', 'zuivel', 'zuivel_toetje', 'yoghurt_cup', 'spoonable', array['mix_with_yoghurt'], array['breakfast','snack'], array['dairy_desserts','dairy_drinks','plant_based_dairy']),
  ('dairy_desserts', 'zuivel', 'zuivel_toetje', 'dessert_cup', 'spoonable', '{}', array['dessert','snack'], array['yoghurt_skyr_quark','ice_cream_desserts','dairy_drinks']),
  ('dairy_drinks', 'zuivel', 'zuiveldrank', 'drink', 'drink', '{}', array['breakfast','on_the_go'], array['yoghurt_skyr_quark','plant_based_dairy','smoothies']),
  ('plant_based_dairy', 'zuivel', 'zuiveldrank', 'drink', 'drink', array['spoonable','mix_with_yoghurt'], array['breakfast','on_the_go'], array['dairy_drinks','yoghurt_skyr_quark']),
  ('chocolate_spreads', 'zoet', 'chocolade', 'spread', 'spread_on_bread', array['topping','spoonable'], array['breakfast','topping'], array['nut_butters','jams_fruit_spreads','sweet_spreads_other']),
  ('nut_butters', 'zoet', 'noten_zaden', 'spread', 'spread_on_bread', array['topping','dip'], array['breakfast','topping'], array['chocolate_spreads','jams_fruit_spreads','nuts_seeds']),
  ('jams_fruit_spreads', 'zoet', 'zoete_snack', 'spread', 'spread_on_bread', array['topping'], array['breakfast','topping'], array['honey_syrups','chocolate_spreads','nut_butters']),
  ('honey_syrups', 'zoet', 'zoete_snack', 'sauce', 'topping', array['spread_on_bread'], array['breakfast','cooking'], array['jams_fruit_spreads','sweet_spreads_other']),
  ('sweet_spreads_other', 'zoet', 'zoete_snack', 'spread', 'spread_on_bread', array['topping'], array['breakfast','topping'], array['chocolate_spreads','jams_fruit_spreads','honey_syrups']),
  ('savory_spreads', 'hartig', 'kaas', 'spread', 'spread_on_bread', array['dip','topping'], array['breakfast','lunch'], array['hummus_legume_spreads','sauces_dips','cold_cuts']),
  ('hummus_legume_spreads', 'hartig', 'hartige_snack', 'dip', 'dip', array['spread_on_bread','topping'], array['snack','lunch'], array['savory_spreads','sauces_dips','fresh_vegetables']),
  ('sauces_dips', 'hartig', 'overig', 'dip', 'dip', array['topping'], array['snack','cooking'], array['hummus_legume_spreads','savory_spreads','fresh_vegetables']),
  ('soups', 'maaltijd', 'maaltijd_component', 'soup', 'spoonable', array['heat_and_eat'], array['lunch','cooking'], array['meal_components','ready_meals']),
  ('meal_components', 'maaltijd', 'maaltijd_component', 'unknown', 'cook_or_prepare', '{}', array['lunch','cooking'], array['soups','ready_meals','sauces_dips']),
  ('ready_meals', 'maaltijd', 'maaltijd_component', 'meal_tray', 'heat_and_eat', '{}', array['lunch','cooking'], array['meal_components','soups','sandwiches_wraps']),
  ('sandwiches_wraps', 'maaltijd', 'maaltijd_component', 'bun_wrap', 'eat_as_piece', array['on_the_go_bar'], array['lunch','on_the_go'], array['bread_bakery','ready_meals','cold_cuts']),
  ('supplements_powders', 'overig', 'supplement', 'powder', 'mix_with_yoghurt', array['drink'], array['after_sport'], array['protein_bars','dairy_drinks','yoghurt_skyr_quark']),
  ('unknown', null, null, null, null, '{}', '{}', '{}')
on conflict (swap_family) do update set
  category_cluster = excluded.category_cluster,
  snack_type = excluded.snack_type,
  product_form = excluded.product_form,
  consumption_mode = excluded.consumption_mode,
  secondary_consumption_modes = excluded.secondary_consumption_modes,
  usage_context = excluded.usage_context,
  related_families = excluded.related_families;

-- 3. product_features/staging: nieuwe kolom voor secundaire consumptiewijzen.
alter table public.product_features
  add column if not exists secondary_consumption_modes text[] not null default '{}';
alter table public.product_features_staging
  add column if not exists secondary_consumption_modes text[] not null default '{}';
create index if not exists idx_product_features_secondary_modes_gin
  on public.product_features using gin(secondary_consumption_modes);
