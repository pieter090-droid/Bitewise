-- 0106 — Magnum-producten zonder expliciet ijswoord vielen buiten de regels.
--
-- Aanleiding: EAN 8721274813876 (Magnum Crackables Almond) stond volledig
-- ongeclassificeerd en kreeg daardoor geen swaps. De naam/categorie bevatte
-- geen ijswoord, terwijl merk en officiële productbron ondubbelzinnig ijs
-- aangeven. Dezelfde lekkage trof vier andere Magnum-ijsproducten.
--
-- Vangrails: snapshot, harde functievervangingsassertie, manifestrefresh en
-- postflightasserties. products blijft raw; alleen product_features wijzigt.

create table if not exists public._snapshot_0106_magnum_before as
select pf.*
from public.product_features pf
join public.products p on p.barcode = pf.barcode
where coalesce(p.brand, '') ~* '\mmagnum\M';

create table if not exists public._snapshot_0106_function_before as
select pg_get_functiondef(
  'public.compute_swap_family(text,text,text,text,text,text)'::regprocedure
) as function_definition;

do $migration$
declare
  v_definition text;
  v_old text := $old$elsif (n ~* '\mijs\M|ice cream|sorbet|gelato' or p2 ~* 'ice cream'$old$;
  v_new text := $new$elsif (b ~* '\mmagnum\M' or n ~* '\mijs\M|ice cream|sorbet|gelato' or p2 ~* 'ice cream'$new$;
begin
  v_definition := pg_get_functiondef(
    'public.compute_swap_family(text,text,text,text,text,text)'::regprocedure
  );

  if length(v_definition) - length(replace(v_definition, v_old, ''))
       <> length(v_old) then
    raise exception '0106 verwacht exact één herkenbare ijsbranch';
  end if;

  execute replace(v_definition, v_old, v_new);
end
$migration$;

-- Herstel zowel nooit-geclassificeerde rijen als twee eerdere naamgestuurde
-- misclassificaties (cookie/bonbon): bij merk Magnum gaat het aantoonbaar om
-- ijsproducten. Bestaande specifieke smaakprofielen blijven behouden.
update public.product_features pf
set swap_family = m.swap_family,
    category_cluster = m.category_cluster,
    snack_type = m.snack_type,
    product_form = m.product_form,
    consumption_mode = m.consumption_mode,
    secondary_consumption_modes = m.secondary_consumption_modes,
    usage_context = m.usage_context,
    is_swap_relevant = true,
    swap_relevance_reason = 'audit1_0106: Magnum-merk is ijs; naam zonder ijswoord',
    classification_status = 'classified',
    classification_confidence = greatest(
      coalesce(pf.classification_confidence, 0), 0.95
    ),
    classification_reason = 'audit1_0106: Magnum-merkregel -> ice_cream_desserts',
    classified_at = now(),
    mapping_version = coalesce(pf.mapping_version, 1),
    is_sweet = coalesce(pf.is_sweet, d.d_is_sweet),
    is_salty = coalesce(pf.is_salty, d.d_is_salty),
    is_crunchy = coalesce(pf.is_crunchy, d.d_is_crunchy),
    taste_profile = case
      when coalesce(cardinality(pf.taste_profile), 0) = 0 then d.d_taste
      else pf.taste_profile end,
    texture_profile = case
      when coalesce(cardinality(pf.texture_profile), 0) = 0 then d.d_texture
      else pf.texture_profile end,
    use_moment = case
      when coalesce(cardinality(pf.use_moment), 0) = 0 then d.d_moment
      else pf.use_moment end,
    updated_at = now()
from public.products p
join public.swap_family_mapping m
  on m.swap_family = 'ice_cream_desserts'
left join public.swap_family_profile_defaults d
  on d.swap_family = m.swap_family
where p.barcode = pf.barcode
  and coalesce(p.brand, '') ~* '\mmagnum\M';

select public.refresh_swap_family_rule_manifest();

-- Postflight: de merkregel werkt, alle Magnum-rijen zijn inzetbaar en het
-- runtime-manifest blijft volledig/aaneengesloten.
do $postflight$
declare
  v_bad integer;
begin
  if public.compute_swap_family(
       'Crackables Almond', null, null, null, null, 'Magnum'
     ) <> 'ice_cream_desserts' then
    raise exception '0106 merkregel classificeert Crackables Almond niet als ijs';
  end if;

  select count(*) into v_bad
  from public.product_features pf
  join public.products p on p.barcode = pf.barcode
  where coalesce(p.brand, '') ~* '\mmagnum\M'
    and (
      pf.swap_family is distinct from 'ice_cream_desserts'
      or pf.classification_status is distinct from 'classified'
      or pf.is_swap_relevant is not true
    );
  if v_bad <> 0 then
    raise exception '0106 postflight: % Magnum-rijen nog inconsistent', v_bad;
  end if;

  select count(*) into v_bad
  from public.swap_family_rules
  where is_active is true;
  if v_bad <> 76 then
    raise exception '0106 postflight: verwacht 76 actieve manifestregels, gevonden %', v_bad;
  end if;
end
$postflight$;
