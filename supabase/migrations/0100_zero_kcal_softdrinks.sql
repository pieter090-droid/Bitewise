-- 0100 — Frisdranken met 0 kcal die in soft_drinks_regular staan.
--
-- GEVONDEN VIA: de vangrail-sweep over alle vier de swapdoelen. Een cola
-- van 0,0 kcal/100g kreeg onder doel "Minder kcal" geen enkele suggestie,
-- want lager dan 0 bestaat niet. Terecht leeg, maar het wees op de
-- werkelijke fout: het product is geen regular cola.
--
-- Alle vier de gevallen hebben 0 kcal, (vrijwel) 0 suiker en zoetstoffen.
-- Dat is de nutritionele handtekening van een light/zero-drank.
--
-- WAAROM GEEN REGELWORTEL: compute_swap_family() krijgt alleen naam,
-- categorieën en merk mee, geen voedingswaarden. Deze fout is per definitie
-- niet op de naam te zien -- "Cola regular" heet regular maar is het niet.
-- Structureel hoort dit in de trigger die de voedingswaarden wél kent; dat
-- is fase 5-werk en staat als zodanig in AUDIT_VOORTGANG.md.
--
-- TWIJFEL = REVIEW: "Cola regular" spreekt zichzelf tegen (naam zegt
-- regular, voeding zegt zero). Dat is geen keuze die ik hier mag maken, dus
-- die gaat naar review_required in plaats van naar een familie.
--
-- ROLLBACK: herstel via _snapshot_0100_before.

create table if not exists public._snapshot_0100_before as
select pf.*
from public.product_features pf
join public.products p on p.barcode = pf.barcode
where pf.swap_family in ('soft_drinks_regular', 'water')
  and p.kcal_100g = 0;

-- 1. Gezoete 0-kcal frisdranken -> light/zero.
update public.product_features pf
set swap_family = 'soft_drinks_light_zero',
    classification_reason = 'audit1_0100: 0 kcal + zoetstoffen = light/zero, niet regular'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'soft_drinks_regular'
  and p.kcal_100g = 0
  and coalesce(p.sugar_100g, 0) <= 0.5
  and pf.has_sweeteners is true
  and p.name !~* '\mregular\M';

-- 2. Naam en voeding spreken elkaar tegen -> review, niet gokken.
update public.product_features pf
set classification_status = 'review_required',
    classification_reason = 'audit1_0100: naam zegt regular, voeding zegt zero — conflict'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'soft_drinks_regular'
  and p.kcal_100g = 0
  and coalesce(p.sugar_100g, 0) <= 0.5
  and p.name ~* '\mregular\M';

-- 3. Ongezoet bronwater in de frisdrankfamilie -> water.
update public.product_features pf
set swap_family = 'water',
    classification_reason = 'audit1_0100: bronwater, geen frisdrank'
from public.products p
where p.barcode = pf.barcode
  and pf.swap_family = 'soft_drinks_regular'
  and p.kcal_100g = 0
  and pf.has_sweeteners is not true
  and (p.brand ~* '\mspa\M|\mchaudfontaine\M|\mbar le duc\M' or p.name ~* '\mbronwater\M');
