-- ---------------------------------------------------------------------------
-- Bugfix: compute_swap_family_fields() classificeerde Merci "Yoghurt & Fruit"
-- (categories_tags bevat en:chocolates/en:filled-chocolates, pnns_groups_2 =
-- "Chocolate products") als swap_family=yoghurt_skyr_quark, puur omdat de
-- NAAM het woord "yoghurt" bevat (een smaaknaam, geen productcategorie).
-- Oorzaak: chocolate_confectionery checkte alleen praline/bonbon/merci in de
-- naam, niet de veel betrouwbaardere categories_tags/pnns_groups_2-signalen,
-- en de yoghurt-check kwam er sowieso te vroeg voor te staan qua prioriteit.
-- Fix: chocolade-checks (spreads -> bars -> confectionery-catchall) lopen nu
-- allemaal vóór de yoghurt/zuivel-checks, en confectionery kijkt ook naar
-- categories_tags/pnns_groups_2 i.p.v. alleen naam.
-- ---------------------------------------------------------------------------
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
  elsif n ~* 'eiwitreep|protein bar' or c ~* 'protein.?bar' then
    return query select 'protein_bars', 'bar', 'on_the_go_bar', array['after_sport','on_the_go'];
  elsif n ~* 'mueslireep|cerealreep|granolareep' or c ~* 'cereal.?bar' then
    return query select 'cereal_bars', 'bar', 'on_the_go_bar', array['snack','on_the_go'];
  elsif n ~* 'chocoladereep|candy bar' or c ~* 'chocolate.?bar' then
    return query select 'chocolate_bars', 'bar', 'on_the_go_bar', array['snack','treat'];
  elsif c ~* 'pralines|bonbons|chocolates|filled.chocolates' or p ~* 'chocolate'
        or n ~* 'bonbon|praline|\mmerci\M' then
    return query select 'chocolate_confectionery', 'praline', 'eat_as_piece', array['snack','treat'];
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

-- Herbereken de al-bestaande rijen met de gecorrigeerde functie.
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
