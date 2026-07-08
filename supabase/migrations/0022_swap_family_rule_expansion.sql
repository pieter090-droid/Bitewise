-- ---------------------------------------------------------------------------
-- Gratis regelronde 2: dekking uitbreiden voor de categorieën die nog het
-- vaakst NULL waren onder is_swap_relevant-producten (gemeten na 0013-0020):
-- zuiveldrank, generieke snoep/frisdrank, warme drank, vers fruit/groente,
-- water, brood, vleeswaren. Geen AI, geen kosten -- puur meer trefwoorden en
-- nieuwe (kleine) families voor categorieën die nog geen enkele hadden.
-- ---------------------------------------------------------------------------
insert into public.feature_vocabulary (field, value) values
  ('swap_family','dairy_drinks'), ('swap_family','candy_sweets'), ('swap_family','hot_beverages'),
  ('swap_family','fresh_fruit'), ('swap_family','fresh_vegetables'), ('swap_family','water'),
  ('swap_family','bread_bakery'), ('swap_family','cold_cuts'), ('swap_family','alcohol_drinks'),
  ('product_form','vegetable_piece'), ('product_form','bread'), ('product_form','meat_slice')
on conflict (field, value) do nothing;

create or replace function public.compute_swap_family_fields(
  p_name text, p_category text, p_categories_tags text, p_pnns1 text, p_pnns2 text
) returns table(swap_family text, product_form text, consumption_mode text, usage_context text[])
language plpgsql immutable as $$
declare
  n  text := coalesce(p_name, '');
  c  text := coalesce(p_category, '') || ' ' || coalesce(p_categories_tags, '');
  p1 text := coalesce(p_pnns1, '');
  p2 text := coalesce(p_pnns2, '');
  v_is_drink_named boolean;
begin
  v_is_drink_named := (n ~* '\mdrink\M|drank|drinkyoghurt|drinkyogur' or c ~* 'drinkable');

  if n ~* 'smeerkaas|cream cheese spread|roomkaas smeerbaar' then
    return query select 'savory_spreads', 'spread', 'spread_on_bread', array['breakfast','lunch'];
  elsif n ~* 'pindakaas|peanut butter|amandelpasta|notenpasta|cashewpasta' then
    return query select 'nut_butters', 'spread', 'spread_on_bread', array['breakfast','topping'];
  elsif n ~* 'nutella|chocopasta|choco.?pasta' or c ~* 'chocolate.?spread|cocoa.and.hazelnut' then
    return query select 'chocolate_spreads', 'spread', 'spread_on_bread', array['breakfast','topping'];
  elsif n ~* 'jam|confiture|marmelade|hagelslag' or c ~* 'jam|confiture' then
    return query select 'sweet_spreads', 'spread', 'spread_on_bread', array['breakfast','topping'];
  elsif n ~* 'eiwitreep|protein bar' or c ~* 'protein.?bar' then
    return query select 'protein_bars', 'bar', 'on_the_go_bar', array['after_sport','on_the_go'];
  elsif n ~* 'mueslireep|cerealreep|granolareep' or c ~* 'cereal.?bar' then
    return query select 'cereal_bars', 'bar', 'on_the_go_bar', array['snack','on_the_go'];
  elsif n ~* 'chocoladereep|candy bar' or c ~* 'chocolate.?bar' then
    return query select 'chocolate_bars', 'bar', 'on_the_go_bar', array['snack','treat'];
  elsif c ~* 'pralines|bonbons|chocolates|filled.chocolates' or p2 ~* 'chocolate'
        or n ~* 'bonbon|praline|\mmerci\M' then
    return query select 'chocolate_confectionery', 'praline', 'eat_as_piece', array['snack','treat'];
  elsif n ~* 'drop\M|winegum|toffee|marshmallow|spekjes|schuimpjes|zuurtjes|\mlolly|fruittella|napoleon|venco'
        or c ~* 'candies|sugar.confectionery' then
    return query select 'candy_sweets', 'piece', 'eat_as_piece', array['snack','treat'];
  elsif n ~* '\mijs\M|ice cream|sorbet|gelato' then
    return query select 'ice_cream_desserts', 'dessert_cup', 'spoonable', array['dessert','treat'];
  elsif n ~* 'yoghurt|yaourt|yogur|joghurt|skyr|kwark|quark'
        and not (v_is_drink_named or n ~* 'dressing|saus|sauce|\mdip\M') then
    return query select 'yoghurt_skyr_quark', 'yoghurt_cup', 'spoonable', array['breakfast','snack'];
  elsif n ~* 'chocomel|karnemelk|milkshake|yogidrink' or (v_is_drink_named and (p1 ~* 'dairy|milk' or n ~* 'melk|yoghurt|yogur')) then
    return query select 'dairy_drinks', 'drink', 'drink', array['breakfast','on_the_go'];
  elsif not v_is_drink_named
        and (c ~* 'tiramisu|dairy-desserts'
             or (n ~* 'pudding|mousse|\mvla\M|dessert' and (p1 ~* 'dairy|milk' or p2 ~* 'dairy|milk|dessert'))) then
    return query select 'dairy_desserts', 'dessert_cup', 'spoonable', array['dessert','snack'];
  elsif p2 ~* 'biscuits|cookies' or n ~* '\mkoek|cookie' then
    return query select 'cookies_biscuits', 'cookie', 'eat_as_piece', array['snack','treat'];
  elsif n ~* 'cracker|beschuit|rice cake|knackebrod' or c ~* 'cracker' then
    return query select 'crackers_rice_cakes', 'cookie', 'eat_as_piece', array['snack'];
  elsif n ~* '\mbrood\M|croissant|stokbrood|bolletje|baguette' or p2 ~* '\bbread\b' then
    return query select 'bread_bakery', 'bread', 'eat_as_piece', array['breakfast','lunch'];
  elsif n ~* '\mham\M|salami|cervelaat|rookvlees|\bpat[ée]\b|leverworst|kipfilet|achterham|vleeswaren'
        or p2 ~* 'processed meat' then
    return query select 'cold_cuts', 'meat_slice', 'spread_on_bread', array['lunch'];
  elsif n ~* 'popcorn' or c ~* 'popcorn' then
    return query select 'popcorn', 'popcorn', 'eat_as_piece', array['snack'];
  elsif n ~* 'chips|crisps' or c ~* 'chips|crisps' then
    return query select 'crisps_chips', 'chips', 'eat_as_piece', array['snack'];
  elsif p2 ~* '\mcheese\M' or n ~* '\mkaas\M|\mcheese\M' then
    if n ~* 'plak|slice' then
      return query select 'cheese_snacks', 'cheese_slice', 'eat_as_piece', array['snack','lunch'];
    else
      return query select 'cheese_snacks', 'cheese_block', 'eat_as_piece', array['snack','lunch'];
    end if;
  elsif n ~* 'bier|\mwijn\M|wodka|whisky|whiskey|\brum\b|\bgin\b|likeur|prosecco|cava\M' or p1 ~* 'alcoholic' then
    return query select 'alcohol_drinks', 'drink', 'drink', array['treat']::text[];
  elsif n ~* '\mcola\M|frisdrank|\msoda\M|limonade|energy ?drink|fanta|sprite|\b7up\b|tonic|bitter lemon|ice.?tea|rivella|sisi\M'
        or p2 ~* 'sweetened beverages' then
    return query select 'soft_drinks', 'drink', 'drink', array['on_the_go']::text[];
  elsif n ~* '\msap\M|juice' or c ~* 'juice' then
    return query select 'fruit_juices', 'drink', 'drink', array['breakfast','on_the_go'];
  elsif n ~* 'koffie|\bcoffee\b|cappuccino|espresso|latte\M|\bthee\b|\btea\b' or p2 ~* 'coffee and tea' then
    return query select 'hot_beverages', 'drink', 'drink', array['breakfast','snack'];
  elsif (n ~* '\mwater\M|bronwater|mineraalwater' or p2 ~* 'waters and flavored waters')
        and not v_is_drink_named then
    return query select 'water', 'drink', 'drink', array['on_the_go']::text[];
  elsif p2 ~* 'breakfast cereal' or n ~* 'muesli|cornflakes|granola|ontbijtgranen' then
    return query select 'breakfast_cereals', 'cereal', 'pour_over', array['breakfast'];
  elsif p2 ~* '\mnuts\M' or n ~* 'noten|zaden|amandelen|cashew|walnoot|hazelnoot' then
    return query select 'nuts_seeds', 'nuts_mix', 'eat_as_piece', array['snack'];
  elsif (n ~* 'hummus|\mdip\M|saus|sauce|dressing' or p2 ~* 'sauce|dressing')
        and not (n ~* 'boter|butter|\molie\M|olive oil') then
    return query select 'sauces_dips', 'dip', 'dip', array['snack','cooking'];
  elsif p2 ~* '\bfruits\b' and not v_is_drink_named then
    return query select 'fresh_fruit', 'fruit_piece', 'eat_as_piece', array['snack','breakfast'];
  elsif p2 ~* 'vegetables' then
    return query select 'fresh_vegetables', 'vegetable_piece', 'eat_as_piece', array['snack','lunch'];
  elsif p1 ~* 'composite' or n ~* 'maaltijd|salade|\mmeal\M' then
    return query select 'meal_components', 'unknown', 'cook_or_prepare', array['lunch','cooking'];
  else
    return query select null::text, null::text, null::text, '{}'::text[];
  end if;
end $$;

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
