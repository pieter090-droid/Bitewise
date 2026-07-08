-- Fase 1A (expliciet goedgekeurd). Doel: is_swap_relevant_default als
-- expliciete, leidende kolom op
-- swap_family_mapping. Volgorde (per instructie): kolom toevoegen (nullable)
-- -> alle 48 rijen expliciet vullen -> controleren op 0 nulls -> pas dan
-- NOT NULL maken. Nooit coalesce() in de resolved view op dit veld.

-- Stap 1: kolom toevoegen, nog nullable.
alter table public.swap_family_mapping
  add column if not exists is_swap_relevant_default boolean;

-- Stap 2: alle 47 bestaande actieve families expliciet vullen (ongewijzigd
-- gedrag t.o.v. nu: elke bestaande familie was al feitelijk swap-relevant).
update public.swap_family_mapping set is_swap_relevant_default = true
where swap_family <> 'unknown' and is_swap_relevant_default is null;

-- 'unknown' krijgt expliciet false (geen family = geen relevantie).
update public.swap_family_mapping set is_swap_relevant_default = false
where swap_family = 'unknown' and is_swap_relevant_default is null;

-- Stap 3 (preflight voor stap 4): controleer dat geen enkele rij nog null is.
-- Dit SELECT moet 0 rijen teruggeven vóórdat stap 4 mag draaien.
-- select swap_family from public.swap_family_mapping where is_swap_relevant_default is null;

-- Stap 4: pas NOT NULL maken als stap 3 bevestigd 0 rijen teruggeeft.
alter table public.swap_family_mapping
  alter column is_swap_relevant_default set not null;

-- POSTFLIGHT: bevestig 48 rijen, 0 null, en dat 'unknown' de enige false is
-- (behalve de 3 nieuwe carnivore/vis-families die in migratie 0036 false
-- krijgen, maar die bestaan op dit punt nog niet).
-- select is_swap_relevant_default, count(*) from public.swap_family_mapping group by 1;

-- ROLLBACK: alter table public.swap_family_mapping drop column is_swap_relevant_default;
