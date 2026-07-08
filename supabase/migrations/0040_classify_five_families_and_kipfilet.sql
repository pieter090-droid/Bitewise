-- Fase 1A (expliciet goedgekeurd). Past de 9 regels uit 0037 daadwerkelijk
-- toe op product_features: kipfilet/cold_cuts-correctie + de 5 nieuwe
-- families. Raakt NOOIT products. Pasta/aardappel/room blijven expliciet
-- buiten scope (geen regel hiervoor bestaat in swap_family_rules, dus die
-- producten worden door onderstaande UPDATE's niet aangeraakt).
--
-- Volgorde van de CASE hieronder is exact de priority-volgorde uit 0037
-- (rule_id 1..9), zodat matched_rule_id altijd overeenkomt met de regel die
-- daadwerkelijk als eerste (specifiekste) zou matchen.

-- Snapshot van de huidige staat van alle rijen die deze migratie MOGELIJK
-- raakt, zodat rollback de exacte oude waarden kan herstellen (niet alleen
-- de nieuwe kolommen op null zetten). Blijft staan na de migratie als
-- permanente audit-snapshot voor deze specifieke stap.
create table if not exists public._snapshot_0040_before as
select barcode, swap_family, is_swap_relevant
from public.product_features
where barcode in (
  select barcode from public.products
  where name ~* 'kipfilet|chicken breast|chicken fillet|hÃ¤hnchenbrust|hÃ¼hnerbrust|blanc de poulet'
     or name ~* 'kipdij|kipdrumstick|hele kip\M|kippenpoot|kipfiletlapjes'
     or name ~* 'rundergehakt|varkenshaas|biefstuk|runderlappen|speklap|kogelbiefstuk|varkensfilet|lamsvlees'
     or name ~* 'zalmfilet|\mzalm\M|tonijn|garnalen|kabeljauw|pangasius|forel|makreel'
     or name ~* 'mayo\M|mayonaise'
     or name ~* '\molie\M|\moil\M|frituurvet|bakvet'
);

with fingerprint as (
  -- md5() i.p.v. digest()/sha256: pgcrypto-extensie staat niet aan in dit
  -- project en is voor een change-detection-fingerprint (geen beveiliging)
  -- niet nodig -- md5() zit in Postgres core, geen extensie vereist.
  select barcode,
    md5(
      coalesce(name,'') || '|' || coalesce(category,'') || '|' ||
      coalesce(categories_tags,'') || '|' || coalesce(pnns_groups_1,'') || '|' ||
      coalesce(pnns_groups_2,'') || '|' || coalesce(ingredients_text,'') || '|' ||
      coalesce(ingredients_tags,'')
    ) as fp
  from public.products
),
kip as (
  select barcode from public.products
  where name ~* 'kipfilet|chicken breast|chicken fillet|hÃ¤hnchenbrust|hÃ¼hnerbrust|blanc de poulet'
),
classification as (
  select p.barcode,
    case
      when p.barcode in (select barcode from kip)
        and p.name ~* 'ovenschotel|salade|maaltijdsalade|stamppot|lasagne|\mcurry\M|\mwok\M|\mmaaltijd\M|kant.?en.?klaar|\mbowl\M|\mrijst\M|broccoli|\mgroente\M|pasta\M|aardappel|couscous|noedel'
        then 1
      when p.barcode in (select barcode from kip)
        and p.name ~* 'gerookt|geroosterd|roasted|flinterdun|plakjes|beleg|kanapka|carpaccio|vleeswaren|voor op brood'
        then 2
      when p.barcode in (select barcode from kip)
        and p.name ~* '\mrauw\M|blokjes|haasjes|reepjes|shoarma|kebab|sate|spiesjes|gemarineerd|schnitzel|chunks|tuinkruiden|provencaal|mexican|pikant|pittig|a la minute|ovengebakken|melkeiwit|naturel|kruiden|dijfilet|dijreepjes|^kipfilet$|filet$'
        then 3
      when p.barcode in (select barcode from kip) then 4
      when p.name ~* 'kipdij|kipdrumstick|hele kip\M|kippenpoot|kipfiletlapjes'
        and p.name !~* 'ovenschotel|salade|voor op brood|vleeswaren|beleg'
        then 5
      when p.name ~* 'rundergehakt|varkenshaas|biefstuk|runderlappen|speklap|kogelbiefstuk|varkensfilet|lamsvlees'
        and p.name !~* '\msoep\M|ovenschotel|salade|\mmaaltijd\M|stamppot|lasagne|\mcurry\M|\mwok\M'
        then 6
      when p.name ~* 'zalmfilet|\mzalm\M|tonijn|garnalen|kabeljauw|pangasius|forel|makreel'
        and p.name !~* 'ovenschotel|salade|sushi|pat[ée]\M'
        then 7
      when p.name ~* 'mayo\M|mayonaise'
        then 8
      when p.name ~* '\molie\M|\moil\M|frituurvet|bakvet'
        and p.name !~* 'in\s*\d*%?\s*(olie|oil)|artisjok|gedroogde tomaten|tonijn in|tuna.{0,3}in|ansjovis|sardientjes|vis in|groente(n)? in|pesto|marinade|maaltijd.*olie|zonnebloemolie in|packed in oil|grissini|cracker|beschuit|chips|crisps'
        then 9
      else null
    end as matched_rule_id
  from public.products p
)
update public.product_features pf set
  swap_family = r.swap_family,
  classification_status = r.classification_status,
  classification_confidence = r.confidence,
  classification_reason = r.rationale,
  matched_rule_id = r.rule_id,
  rule_version = r.rule_version,
  mapping_version = 1,
  source_fingerprint = f.fp,
  classified_at = now()
from classification cl
join public.swap_family_rules r on r.rule_id = cl.matched_rule_id
join fingerprint f on f.barcode = cl.barcode
where pf.barcode = cl.barcode
  and cl.matched_rule_id is not null;

-- POSTFLIGHT (read-only, uit te voeren na deze migratie):
-- select classification_status, count(*) from product_features group by 1;
-- select swap_family, count(*) from product_features where matched_rule_id is not null group by 1 order by 2 desc;
-- select count(*) from product_features where matched_rule_id is not null and source_fingerprint is null; -- moet 0 zijn

-- ROLLBACK (exact, via de snapshot-tabel):
-- update public.product_features pf set
--   swap_family = s.swap_family, is_swap_relevant = s.is_swap_relevant,
--   classification_status = null, classification_confidence = null,
--   classification_reason = null, matched_rule_id = null, rule_version = null,
--   mapping_version = null, source_fingerprint = null, classified_at = null
-- from public._snapshot_0040_before s
-- where pf.barcode = s.barcode;
-- drop table public._snapshot_0040_before; -- pas na bevestigde, succesvolle rollback
