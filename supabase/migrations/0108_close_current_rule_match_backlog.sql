-- 0108 — fase 7C, alle 388 nooit-beoordeelde rijen waarvoor de actuele
-- classifier een familie vindt.
--
-- Alle 388 namen/merken/categorieën zijn gelezen. Veilige matches worden
-- gepromoveerd; gevonden foutpositieven krijgen hieronder een expliciete,
-- barcode-verankerde bestemming. Eén te vaag product gaat naar review.
-- products blijft raw.

begin;
set local statement_timeout = '10min';

create table if not exists public._snapshot_0108_rule_match_before as
select
  pf.*,
  a.computed_swap_family,
  a.audit_bucket
from public.catalog_classification_audit a
left join public.product_features pf on pf.barcode = a.barcode
where a.audit_bucket = 'unreviewed_rule_match';

create temporary table audit7_0108_overrides (
  barcode text primary key,
  target_family text,
  reason text not null
) on commit drop;

insert into audit7_0108_overrides (barcode, target_family, reason) values
-- Sauzenregel ving complete gerechten, kaas, broodjes en rauw vlees.
('4335619414662','raw_meat','gemarineerde schouderfiletlapjes zijn rauw vlees'),
('8717228611056','ready_meals','gnocchi pesto tomaat is een gerecht'),
('8718907071802','cheese_snacks','Jerseykaas met mosterd is kaas'),
('8718452923106','sandwiches_wraps','wraphapje kip-pesto is een belegd wrapje'),
('8719587130391','ready_meals','kip ketjap is een bereid gerecht'),
('8718452925193','ready_meals','mihoen babi ketjap is een bereid gerecht'),
('8711842311033','cheese_snacks','mosterdkaas is kaas'),
('8711578604515','ready_meals','pasta pesto is een bereid gerecht'),
('8720326114992','ready_meals','pasta pesto is een bereid gerecht'),
('9507529498895','ready_meals','pasta pesto kip is een bereid gerecht'),
('8720195572893','ready_meals','stoom-en-klaar pasta pesto is een gerecht'),
('8718989750527','meat_alternatives_non_swap','tempeh ketjap is vleesvervanger'),

-- Maaltijdwoorden vingen kruidenmixen, grondstoffen en rauwe vis.
('3417960022787','sauces_dips','paellakruiden zijn smaakmaker'),
('8719587113929','fish_seafood','zalmblokjes zijn vis, niet een pokebowl'),
('8710624387877','sauces_dips','bami-gorengboemboe is smaakmaker'),
('8710161532013','sauces_dips','nasi-gorengboemboe is smaakmaker'),
('8717600337116','sauces_dips','burrito-nachokruiden zijn smaakmaker'),
('4068428011196',null,'naam Burritos en bronwaarden zijn onvoldoende eenduidig'),
('8718452916566','grain_starch_ingredients','lasagnebladen zijn droge pasta'),
('8718906615175','grain_starch_ingredients','glutenvrije lasagnebladen zijn droge pasta'),
('8720182014511','meal_components','lasagnettepakket vereist bereiding'),
('8718907326834','sauces_dips','nasi-gorengboemboe is smaakmaker'),
('8718907981095','sauces_dips','nasi-gorengboemboe is smaakmaker'),
('8711200403417','sauces_dips','boemboe voor nasi is smaakmaker'),
('8721201954696','meal_components','droge risottomix vereist bereiding'),
('8055176740740','meal_components','droge risottomix vereist bereiding'),
('8718989043186','grain_starch_ingredients','tagliatelle is droge pasta'),
('8718989081287','grain_starch_ingredients','tagliatelle is droge pasta'),
('8718754502733','sauces_dips','bumbu voor nasi/bami is smaakmaker'),

-- Los woord "melk" ving chocolade en bakproducten.
('8719587194836','chocolate_confectionery','melkcrème is chocoladeproduct'),
('8718885091281','baking_ingredients_non_swap','chocoladedruppels zijn bakproduct'),
('8712402001296','chocolate_confectionery','chocoladerozijnen melk'),
('8718907602709','chocolate_confectionery','melkchocoladeletter'),
('8719587083703','chocolate_confectionery','gevulde chocolade-eitjes'),
('8718989924485','chocolate_confectionery','gevulde chocolade-eitjes'),
('8718989924386','chocolate_confectionery','gevulde chocolade-eitjes'),
('8718989924362','chocolate_confectionery','praliné chocolade-eitjes'),
('8718452933174','chocolate_confectionery','chocoladerozijnen melk'),
('8718452878321','baking_ingredients_non_swap','smeltchocolade is bakproduct'),
('8720701148390','chocolate_confectionery','melkchocolade-koekjesmix'),
('8718452940967','chocolate_confectionery','melkchocoladebloemen'),
('9718787149874',null,'vage naam melk choco proteïne, productvorm onbekend'),
('8719587228883','chocolate_confectionery','melkchocolade-eitjes'),
('8715700127910','sweet_spreads_other','melkchocoladevlokken zijn broodbeleg'),
('8718907901086','chocolate_confectionery','pralinéblok melkchocolade'),
('8718452929320','chocolate_confectionery','melkchocoladetablet'),
('8719587090787','chocolate_confectionery','melkchocoladehuisje met crème'),

-- Noten-/rozijnsignalen vingen bakkerij, snoep en chips.
('8718907844611','bread_bakery','ciabattina rozijn is brood'),
('8719587254592','cakes_pastries','appel-pecan-karamelslof is gebak'),
('8713834094016','bread_bakery','rozijnen-krentenbol is brood'),
('8718452871759','chocolate_confectionery','chocopinda’s zijn chocoladeproduct'),
('8718734491743','cereal_bars','dadel-appelreepjes zijn fruitrepen'),
('9588800660026','candy_sweets','chewy peanut candy is snoep'),
('8719587013229','chocolate_confectionery','Dubbel Pinda is chocoladeproduct'),
('8720986893565','protein_bars','eiwitcrisp pinda is eiwitsnack'),
('8718452924097','crackers_rice_cakes','knäckebröd met pitten is cracker'),
('8720326109011','bread_bakery','maple-pecan bread is bakkerijproduct'),
('8718907709101','chocolate_confectionery','pindarots is chocoladeproduct'),
('8718989920753','crisps_chips','pindaflips zijn chips/zoutjes'),
('8718989891985','bread_bakery','rozijnen-krentenbollen zijn brood'),
('8718452994595','bread_bakery','rozijnenbollen zijn brood'),
('8718907429054','bread_bakery','rozijnen-krentenbollen zijn brood'),
('8718452994489','bread_bakery','rozijnen-krentenbollen zijn brood'),
('8718204145336','bread_bakery','rozijnen-krentenbollen zijn brood'),
('8718989970581','cakes_pastries','eierkoeken met rozijnen zijn gebak'),
('8719587314012','cakes_pastries','scones met rozijnen zijn gebak'),
('8718452948598','cookies_biscuits','Snelle Jelle rozijnen is ontbijtkoek'),
('4056489373827','cookies_biscuits','Vlugge Japie rozijnen is ontbijtkoek'),

-- Brood-, havermout-, stroopwafel- en roomwoorden met andere productvorm.
('8720986897907','dairy_desserts','eiwit-rijstpudding is dessert'),
('8717982005337','dairy_drinks','Müllermilk banaan is zuiveldrank'),
('8719587211724','cakes_pastries','bananenmuffin is gebak'),
('8719587260319','ready_meals','tortilla de patatas is aardappelomelet'),
('8720986894104','supplements_powders','80% eiwit banaan-kaneel is supplementpoeder'),
('8717903722602','crackers_rice_cakes','gepofte meergranenwafels zijn crackers'),
('8717903000601','crackers_rice_cakes','gepofte tarwewafels zijn crackers'),
('8718907252386','sweet_spreads_other','stroopwafelpasta is broodbeleg'),
('8719587257371','cakes_pastries','stroopwafelvlaai is gebak'),
('8721008491189','cakes_pastries','stroopwafelbrownie is gebak'),
('8718907425506','cakes_pastries','aardbei-slagroomvlaai is gebak'),
('8726900027047','cakes_pastries','aardbeienslof met slagroom is gebak'),
('7613035187979','meal_components','ovenschotelmix crème-fraîche/zuurkool'),
('8718907474887','chocolate_confectionery','slagroomtruffels zijn chocolade'),
('8031301884749','sauces_dips','citroensap als condiment/kookproduct'),
('8720986893084','supplements_powders','eiwit-ijstheepoeder met 80% eiwit');

do $preflight$
declare
  v_targets integer;
  v_features integer;
  v_bad_family integer;
begin
  select count(*) into v_targets
  from public.catalog_classification_audit
  where audit_bucket = 'unreviewed_rule_match';
  if v_targets <> 388 then
    raise exception '0108 verwacht auditcheckpoint met 388 targets, gevonden %', v_targets;
  end if;

  select count(*) into v_features
  from public.product_features pf
  join public.catalog_classification_audit a using (barcode)
  where a.audit_bucket = 'unreviewed_rule_match';
  if v_features <> v_targets then
    raise exception '0108 mist product_features-rijen: targets %, features %', v_targets, v_features;
  end if;

  select count(*) into v_bad_family
  from audit7_0108_overrides o
  left join public.swap_family_mapping m on m.swap_family = o.target_family
  where o.target_family is not null and m.swap_family is null;
  if v_bad_family <> 0 then
    raise exception '0108 bevat % onbekende overridefamilies', v_bad_family;
  end if;
end
$preflight$;

with decisions as (
  select
    a.barcode,
    coalesce(o.target_family, a.computed_swap_family) as target_family,
    o.reason as override_reason,
    o.barcode is not null and o.target_family is null as needs_review
  from public.catalog_classification_audit a
  left join audit7_0108_overrides o using (barcode)
  where a.audit_bucket = 'unreviewed_rule_match'
)
update public.product_features pf
set swap_family = case when d.needs_review then null else d.target_family end,
    category_cluster = case when d.needs_review then null else m.category_cluster end,
    snack_type = case when d.needs_review then null else m.snack_type end,
    product_form = case when d.needs_review then null else m.product_form end,
    consumption_mode = case when d.needs_review then null else m.consumption_mode end,
    secondary_consumption_modes = case when d.needs_review then '{}'::text[] else m.secondary_consumption_modes end,
    usage_context = case when d.needs_review then '{}'::text[] else m.usage_context end,
    is_swap_relevant = case when d.needs_review then false else m.is_swap_relevant_default end,
    swap_relevance_reason = case
      when d.needs_review then 'audit7_0108: onvoldoende eenduidige productvorm'
      when d.override_reason is not null then 'audit7_0108: ' || d.override_reason
      else 'audit7_0108: actuele regelmatch inhoudelijk bevestigd'
    end,
    classification_status = case when d.needs_review then 'review_required' else 'classified' end,
    classification_confidence = case when d.needs_review then 0.50 else 0.90 end,
    classification_reason = case
      when d.needs_review then 'audit7_0108_review: ' || d.override_reason
      when d.override_reason is not null then 'audit7_0108_override: ' || d.override_reason
      else 'audit7_0108_rule_confirmed: ' || d.target_family
    end,
    classified_at = now(),
    mapping_version = coalesce(pf.mapping_version, 1),
    is_sweet = case when d.needs_review then pf.is_sweet else coalesce(pf.is_sweet, defs.d_is_sweet) end,
    is_salty = case when d.needs_review then pf.is_salty else coalesce(pf.is_salty, defs.d_is_salty) end,
    is_crunchy = case when d.needs_review then pf.is_crunchy else coalesce(pf.is_crunchy, defs.d_is_crunchy) end,
    taste_profile = case
      when not d.needs_review and coalesce(cardinality(pf.taste_profile), 0) = 0
        then coalesce(defs.d_taste, pf.taste_profile, '{}'::text[])
      else pf.taste_profile end,
    texture_profile = case
      when not d.needs_review and coalesce(cardinality(pf.texture_profile), 0) = 0
        then coalesce(defs.d_texture, pf.texture_profile, '{}'::text[])
      else pf.texture_profile end,
    use_moment = case
      when not d.needs_review and coalesce(cardinality(pf.use_moment), 0) = 0
        then coalesce(defs.d_moment, pf.use_moment, '{}'::text[])
      else pf.use_moment end,
    updated_at = now()
from decisions d
left join public.swap_family_mapping m on m.swap_family = d.target_family
left join public.swap_family_profile_defaults defs on defs.swap_family = d.target_family
where pf.barcode = d.barcode;

refresh materialized view public.catalog_classification_audit;

do $postflight$
declare
  v_bad integer;
  v_unreviewed integer;
begin
  select count(*) into v_bad
  from public.product_features pf
  join public._snapshot_0108_rule_match_before s using (barcode)
  where pf.classification_status is null
     or (pf.classification_status = 'classified' and pf.swap_family is null)
     or (pf.classification_status = 'review_required' and pf.is_swap_relevant is true);
  if v_bad <> 0 then
    raise exception '0108 postflight: % targets hebben ongeldige eindstatus', v_bad;
  end if;

  select count(*) into v_unreviewed
  from public.catalog_classification_audit
  where audit_bucket = 'unreviewed_rule_match';
  if v_unreviewed <> 0 then
    raise exception '0108 postflight: nog % actuele regelmatches onbeoordeeld', v_unreviewed;
  end if;

  select count(*) into v_bad
  from public.catalog_classification_audit
  where audit_bucket like 'invalid_%';
  if v_bad <> 0 then
    raise exception '0108 postflight: % harde auditinvarianten falen', v_bad;
  end if;
end
$postflight$;

commit;
