-- Fase 1A (expliciet goedgekeurd). Vereist 0035+0036.

create table if not exists public.swap_family_rules (
  rule_id bigint generated always as identity primary key,
  priority int not null,
  classification_status text not null check (classification_status in
    ('classified','not_swap_relevant','review_required')),
  swap_family text references public.swap_family_mapping(swap_family),
  name_pattern text,
  category_pattern text,
  categories_tags_pattern text,
  pnns1_pattern text,
  pnns2_pattern text,
  include_all_patterns text[],
  include_any_patterns text[],
  exclude_patterns text[],
  confidence numeric check (confidence between 0 and 1),
  rule_version int not null default 1,
  is_active boolean not null default true,
  rationale text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_status_family check (
    (classification_status = 'classified' and swap_family is not null)
    or (classification_status in ('not_swap_relevant','review_required'))
  )
);

alter table public.swap_family_rules enable row level security;
drop policy if exists "rules readable" on public.swap_family_rules;
create policy "rules readable" on public.swap_family_rules for select using (true);

-- Trigger die controleert dat een `classified`-regel verwijst naar een
-- ACTIEVE familie (een CHECK-constraint kan geen subquery doen).
create or replace function public.validate_rule_active_family()
returns trigger language plpgsql as $$
begin
  if new.classification_status = 'classified' then
    if not exists (
      select 1 from public.swap_family_mapping m
      where m.swap_family = new.swap_family and m.swap_family <> 'unknown'
    ) then
      raise exception 'swap_family_rules.swap_family "%" bestaat niet of is niet actief', new.swap_family;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_rule_active_family on public.swap_family_rules;
create trigger trg_validate_rule_active_family
  before insert or update on public.swap_family_rules
  for each row execute function public.validate_rule_active_family();

-- Regels voor fase 1A: uitsluitend de 5 goedgekeurde families + de
-- kipfilet/cold_cuts-tiers. Geen pasta/aardappel/room-regels (die blijven
-- expliciet buiten scope deze ronde, zie 0040 dry-run-notities). Priority:
-- laag getal = eerst geëvalueerd, dus specifieker/hogere prioriteit.
insert into public.swap_family_rules
  (priority, classification_status, swap_family, name_pattern, include_any_patterns, exclude_patterns, confidence, rationale)
values
  (5, 'classified', 'ready_meals', 'kipfilet|chicken breast|chicken fillet|hÃ¤hnchenbrust|hÃ¼hnerbrust|blanc de poulet',
   array['ovenschotel','salade','maaltijdsalade','stamppot','lasagne','\mcurry\M','\mwok\M','\mmaaltijd\M','kant.?en.?klaar','\mbowl\M','\mrijst\M','broccoli','\mgroente\M','pasta\M','aardappel','couscous','noedel'],
   null, 0.75, 'Kipfilet + duidelijk maaltijdwoord/meerdere voedingsmiddelen -> kant-en-klaar gerecht, niet los kipfilet'),
  (10, 'classified', 'cold_cuts', 'kipfilet|chicken breast|chicken fillet|hÃ¤hnchenbrust|hÃ¼hnerbrust|blanc de poulet',
   array['gerookt','geroosterd','roasted','flinterdun','plakjes','beleg','kanapka','carpaccio','vleeswaren','voor op brood'],
   null, 0.75, 'Kipfilet met deli/beleg-signaal -> kant-en-klaar vleeswaren'),
  (15, 'classified', 'raw_poultry', 'kipfilet|chicken breast|chicken fillet|hÃ¤hnchenbrust|hÃ¼hnerbrust|blanc de poulet',
   array['\mrauw\M','blokjes','haasjes','reepjes','shoarma','kebab','sate','spiesjes','gemarineerd','schnitzel','chunks','tuinkruiden','provencaal','mexican','pikant','pittig','a la minute','ovengebakken','melkeiwit','naturel','kruiden','dijfilet','dijreepjes'],
   null, 0.65, 'Kipfilet met rauw/marinade-signaal -> zelf te bereiden rauw product'),
  (20, 'review_required', null, 'kipfilet|chicken breast|chicken fillet|hÃ¤hnchenbrust|hÃ¼hnerbrust|blanc de poulet',
   null, null, 0.3, 'Alleen smaakwoord (bv. Sweet Chili/Kerrie), geen vorm-signaal -- pnns_groups_2 bevestigd "unknown" voor deze groep, dus geen extra bewijs beschikbaar'),
  (30, 'classified', 'raw_poultry', 'kipdij|kipdrumstick|hele kip\M|kippenpoot|kipfiletlapjes',
   null, array['ovenschotel','salade','voor op brood','vleeswaren','beleg'], 0.7, null),
  (40, 'classified', 'raw_meat', 'rundergehakt|varkenshaas|biefstuk|runderlappen|speklap|kogelbiefstuk|varkensfilet|lamsvlees',
   null, array['\msoep\M','ovenschotel','salade','\mmaaltijd\M','stamppot','lasagne','\mcurry\M','\mwok\M'], 0.7, null),
  (50, 'classified', 'fish_seafood', 'zalmfilet|\mzalm\M|tonijn|garnalen|kabeljauw|pangasius|forel|makreel',
   null, array['ovenschotel','salade','sushi','pat[ée]\M'], 0.7, null),
  (60, 'classified', 'mayonnaise_sauces', 'mayo\M|mayonaise', null, null, 0.85, null),
  (70, 'classified', 'cooking_oils_fats', '\molie\M|\moil\M|frituurvet|bakvet',
   null, array['in\s*\d*%?\s*(olie|oil)','artisjok','gedroogde tomaten','tonijn in','tuna.{0,3}in','ansjovis','sardientjes','vis in','groente(n)? in','pesto','marinade','maaltijd.*olie','zonnebloemolie in','packed in oil','grissini','cracker','beschuit','chips','crisps'],
   0.8, null)
on conflict do nothing;

-- POSTFLIGHT: select count(*) from swap_family_rules; -- verwacht 9
-- select * from swap_family_rules where classification_status='classified' and swap_family is null; -- moet leeg zijn (constraint zou dit al voorkomen)

-- ROLLBACK: drop trigger trg_validate_rule_active_family on public.swap_family_rules;
--           drop function public.validate_rule_active_family();
--           drop table public.swap_family_rules;
