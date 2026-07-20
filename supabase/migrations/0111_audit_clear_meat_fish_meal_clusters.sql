-- 0111 — fase 7C: conservatieve sluiting van duidelijke vlees-, vis- en
-- maaltijdclusters uit de fail-closed 0110-quarantaine.
--
-- Alleen naam/merkpatronen die zelfstandig een productvorm bewijzen worden
-- gepromoveerd. Categorievelden zijn bewust geen beslisbron: 83% van deze
-- backlog mist categorieën en enkele aanwezige categorieën zijn aantoonbaar
-- fout. De resterende twijfel blijft review_required.

begin;
set local statement_timeout = '10min';

create temporary table audit7_0111_decisions (
  barcode text primary key,
  target_family text not null,
  decision_reason text not null
) on commit drop;

with candidates as (
  select
    p.barcode,
    lower(' ' || coalesce(p.name, '') || ' ' || coalesce(p.brand, '') || ' ') as n
  from public.products p
  join public.product_features pf using (barcode)
  where pf.classification_status = 'review_required'
    and pf.classification_reason like 'audit7_0110_pending%'
), decisions as (
  select
    barcode,
    case
      -- Plantaardige vlees-/visvormen, maar niet ieder product met "vegan".
      when n ~* '(plantaardig|vegetarisch|vegan|meatless|als van kip|no chicken)'
       and n ~* '(kip|chicken|gehakt|d[oö]ner|doner|visburger|burger|worst|schnitzel|vlees|meat|rosbief)'
        then 'meat_alternatives_non_swap'
      -- Kruiden en boemboes zijn smaakmakers, nooit het genoemde gerecht.
      when n ~* '(boemboe|kruidenmix|seasoning|marinade|spice mix|mix voor (kip|vlees|gehakt|shoarma)|hamburger kruiden)'
        then 'sauces_dips'
      -- Gevulde broodvormen.
      when n ~* '\m(bapao|panini|croque)\M'
        then 'sandwiches_wraps'
      -- Houdbare vleessnacks.
      when n ~* '\m(metworst|droge worst|drogeworst|kosterworst|borrelworst|snackworst|fuet)\M'
        then 'meat_snacks'
      -- Expliciet vleesbeleg. Dit staat vóór de bereidingssignalen omdat
      -- bijvoorbeeld gebraden rosbief nog steeds beleg is.
      when n ~* '\m(rosbief|prosciutto|parmaham|serranoham|mortadella|corned beef|beenham|schouderham|ontbijtspek|katenspek|zeeuws spek|bacon)\M'
       and n !~* '\m(green beans|bread|pasta|mezzelune|burger)\M'
        then 'cold_cuts'
      -- Volledige maaltijdnamen; bereidingsmixen en losse groenten vallen af.
      when n ~* '\m(nasi met|bami goreng|stamppot|roti daal|rendang|tikka masala|butter chicken|teriyaki pok|kant.?en.?klaar|maaltijd)\M'
       and n !~* '(mix voor|groente|verspakket|sauce|saus|kruiden)'
        then 'ready_meals'
      -- Zelfstandige vis/garnaalproducten, geen pasta/salade/saus met vis.
      when n ~* '\m(zalm|tonijn|kabeljauw|makreel|haring|garnaal|garnalen|visfilet|seafood)\M'
       and n !~* '(pasta|penne|salade|saus)'
        then 'fish_seafood'
      -- Aantoonbaar voorgegaard vlees is een maaltijdcomponent. Bowls zijn
      -- volledige maaltijden en blijven voor een aparte regel buiten deze tak.
      when n ~* '(gegaard|gebraden|gegrild|grilled|roasted|pulled|oven.?gebakken|oven baked)'
       and n ~* '\m(kip|chicken|kalkoen|turkey|rund|beef|varken|pork|gehakt)\M'
       and n !~* '\m(bowl|salade|pasta|wrap)\M'
        then 'meal_components'
      -- Rauwe pluimveevormen. Bereide/belegsignalen zijn expliciet uitgesloten.
      when n ~* '\m(kip|chicken|kalkoen|turkey|puten)\M'
       and n ~* '(filet|dij|bout|drumstick|gehakt|burger|shoarma|spies|kluif|vleugel|schnitzel|patties)'
       and n !~* '(gegaard|gebraden|gegrild|grilled|roasted|oven.?gebakken|oven baked|beleg)'
        then 'raw_poultry'
      -- Ondubbelzinnige rauwe roodvleesvormen.
      when n ~* '\m(rundergehakt|half.om gehakt|varkensgehakt|biefstuk|entrecote|ribeye|schnitzel|varkenshaas|karbonade|braadworst|hamburger|runderburger|varkenslap|shoarma)\M'
       and n !~* '(kruiden|seasoning|gegaard|gebraden|gegrild)'
        then 'raw_meat'
      else null
    end as target_family
  from candidates
)
insert into audit7_0111_decisions (barcode, target_family, decision_reason)
select barcode, target_family, 'naam/merk bewijst productvorm: ' || target_family
from decisions
where target_family is not null;

create table if not exists public._snapshot_0111_clusters_before as
select pf.*, p.name, p.brand, d.target_family, d.decision_reason
from audit7_0111_decisions d
join public.product_features pf using (barcode)
join public.products p using (barcode);

do $preflight$
declare
  v_targets integer;
  v_unknown integer;
begin
  select count(*) into v_targets from audit7_0111_decisions;
  if v_targets < 150 then
    raise exception '0111 verwacht minimaal 150 veilige targets, gevonden %', v_targets;
  end if;

  select count(*) into v_unknown
  from audit7_0111_decisions d
  left join public.swap_family_mapping m on m.swap_family = d.target_family
  where m.swap_family is null;
  if v_unknown <> 0 then
    raise exception '0111 bevat % onbekende doelfamilies', v_unknown;
  end if;
end
$preflight$;

update public.product_features pf
set swap_family = m.swap_family,
    category_cluster = m.category_cluster,
    snack_type = m.snack_type,
    product_form = m.product_form,
    consumption_mode = m.consumption_mode,
    secondary_consumption_modes = m.secondary_consumption_modes,
    usage_context = m.usage_context,
    is_swap_relevant = m.is_swap_relevant_default,
    swap_relevance_reason = 'audit7_0111: ' || d.decision_reason,
    classification_status = 'classified',
    classification_confidence = 0.92,
    classification_reason = 'audit7_0111_classified: ' || d.target_family,
    classified_at = now(),
    mapping_version = coalesce(pf.mapping_version, 1),
    is_sweet = coalesce(pf.is_sweet, defs.d_is_sweet),
    is_salty = coalesce(pf.is_salty, defs.d_is_salty),
    is_crunchy = coalesce(pf.is_crunchy, defs.d_is_crunchy),
    taste_profile = case
      when coalesce(cardinality(pf.taste_profile), 0) = 0
        then coalesce(defs.d_taste, pf.taste_profile, '{}'::text[])
      else pf.taste_profile end,
    texture_profile = case
      when coalesce(cardinality(pf.texture_profile), 0) = 0
        then coalesce(defs.d_texture, pf.texture_profile, '{}'::text[])
      else pf.texture_profile end,
    use_moment = case
      when coalesce(cardinality(pf.use_moment), 0) = 0
        then coalesce(defs.d_moment, pf.use_moment, '{}'::text[])
      else pf.use_moment end,
    updated_at = now()
from audit7_0111_decisions d
join public.swap_family_mapping m on m.swap_family = d.target_family
left join public.swap_family_profile_defaults defs on defs.swap_family = d.target_family
where pf.barcode = d.barcode;

refresh materialized view public.catalog_classification_audit;

do $postflight$
declare
  v_bad integer;
  v_pending integer;
begin
  select count(*) into v_bad
  from public.product_features pf
  join public._snapshot_0111_clusters_before s using (barcode)
  where pf.classification_status is distinct from 'classified'
     or pf.swap_family is distinct from s.target_family
     or (pf.is_swap_relevant is true and pf.classification_status <> 'classified');
  if v_bad <> 0 then
    raise exception '0111 postflight: % targets hebben een ongeldige eindstatus', v_bad;
  end if;

  select count(*) into v_pending
  from public.product_features pf
  join public._snapshot_0111_clusters_before s using (barcode)
  where pf.classification_reason like 'audit7_0110_pending%';
  if v_pending <> 0 then
    raise exception '0111 postflight: % targets bleven onterecht pending', v_pending;
  end if;

  select count(*) into v_bad
  from public.catalog_classification_audit
  where audit_bucket like 'invalid_%';
  if v_bad <> 0 then
    raise exception '0111 postflight: % harde auditinvarianten falen', v_bad;
  end if;
end
$postflight$;

commit;
