-- Duurzaamheidscontrole — read-only, hoort nul rijen terug te geven.
--
-- Bewaakt wat migratie 0102 heeft dichtgezet: een handmatig beoordeelde
-- classificatie mag niet stilletjes terugvallen op de regel zodra iets een
-- products-rij aanraakt (OFF-sync, herscan, backfill).
--
-- Draai dit na elke wijziging aan compute_product_features() of aan de
-- classificatieregels, en na een grote import.

-- A. Zou de familie verschuiven als de rij nu werd aangeraakt?
--    Alleen rijen mét een classification_status tellen: die zijn beoordeeld.
select 'family_would_drift' as issue, pf.barcode, p.name, p.brand,
       pf.swap_family as vastgelegd,
       public.compute_swap_family(p.name, p.category, p.categories_tags,
         p.pnns_groups_1, p.pnns_groups_2, p.brand) as regel_zegt,
       pf.classification_status, pf.classification_reason
from public.product_features pf
join public.products p using (barcode)
where pf.classification_status is not null
  and pf.swap_family is distinct from
      public.compute_swap_family(p.name, p.category, p.categories_tags,
        p.pnns_groups_1, p.pnns_groups_2, p.brand)
  -- Alleen melden wat de trigger ook echt zou overschrijven. Sinds 0102 is
  -- dat niets meer; blijft deze query leeg, dan staat de bescherming er nog.
  and exists (
    select 1 from pg_trigger t
    where t.tgrelid = 'public.products'::regclass
      and t.tgname = 'products_compute_features'
      and pg_get_functiondef('public.compute_product_features()'::regprocedure)
          not like '%swap_family            = case when pf.classification_status is null%'
  );

-- B. Handmatig beoordeelde rij zonder status: valt door het "nieuw
--    product"-gat en wordt alsnog herberekend.
select 'reviewed_row_without_status' as issue, pf.barcode, p.name,
       pf.swap_family, pf.classification_reason
from public.product_features pf
join public.products p using (barcode)
where pf.classification_status is null
  and pf.swap_family is not null
  and (pf.classification_reason like 'audit1_%'
    or pf.classification_reason like 'correction_%');

-- C. Non-swapfamilie die toch als swapkandidaat geldt. De relevantie hoort
--    bij de familie die er werkelijk staat, niet bij de herberekende.
select 'non_swap_marked_relevant' as issue, pf.barcode, p.name,
       pf.swap_family, pf.is_swap_relevant
from public.product_features pf
join public.products p using (barcode)
where pf.swap_family like '%\_non\_swap' escape '\'
  and pf.is_swap_relevant is true;

-- D. Bewuste "buiten het swap-model"-beslissing zonder status.
--
--    Migratie 0074 zette een aantal producten opzettelijk op
--    swap_family = NULL. Met óók classification_status op NULL leest de
--    trigger zo'n rij als een nieuw product en geeft hem alsnog een familie
--    van de regel -- de beslissing verdampt dan. 0103 heeft die rijen een
--    status gegeven; deze query bewaakt dat er geen nieuwe bijkomen.
--
--    Let op: een rij met familie NULL en herkomst NULL is géén probleem.
--    Die is nooit beoordeeld en hoort juist door de regel te lopen.
select 'deliberate_exclusion_without_status' as issue, pf.barcode, p.name,
       pf.swap_family, pf.classification_reason
from public.product_features pf
join public.products p using (barcode)
where pf.swap_family is null
  and pf.classification_status is null
  and pf.classification_reason is not null;
