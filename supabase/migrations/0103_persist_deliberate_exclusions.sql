-- 0103 — Bewuste "buiten het swap-model"-beslissingen worden duurzaam.
--
-- GEVONDEN met de duurzaamheidscontrole uit 0102. Migratie 0074 heeft een
-- handvol producten opzettelijk op swap_family = NULL gezet:
--
--   audit1_0074: teruggezet naar onbeslist -- condiment (zoetzure augurk),
--   chocolademelkpoeder, kant-en-klare pannenkoeken of drinkbouillon;
--   bewust buiten het swap-model
--
-- Die rijen hebben zowel swap_family als classification_status op NULL. Dat
-- is precies de combinatie die compute_product_features() als "nieuw
-- product" leest, dus bij de eerstvolgende aanraking van de products-rij
-- kregen ze alsnog een familie van de regel. Gemeten: 6 zulke rijen, 4
-- kwamen terug in het model.
--
-- De B2-bescherming uit 0102 hangt aan classification_status; zonder status
-- valt een rij daar per definitie buiten. Een bewust genomen beslissing
-- moet dus ook een status dragen.
--
-- KEUZE: review_required. De rijen zijn niet "nog niet beoordeeld" maar ook
-- niet in een familie geplaatst -- 0074 noemt ze letterlijk onbeslist. Dat
-- sluit aan bij de vaste regel van dit project: twijfel = review_required,
-- nooit gokken. De app toont review_required-rijen niet als swapkandidaat,
-- dus het gedrag naar buiten blijft hetzelfde; het verschil is dat de
-- beslissing nu blijft staan.
--
-- ROLLBACK: herstel via _snapshot_0103_before.

create table if not exists public._snapshot_0103_before as
select barcode, swap_family, classification_status, classification_reason
from public.product_features
where swap_family is null
  and classification_status is null
  and classification_reason is not null;

update public.product_features
set classification_status = 'review_required'
where swap_family is null
  and classification_status is null
  and classification_reason is not null;
