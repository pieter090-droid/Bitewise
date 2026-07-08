-- Fase 1A (expliciet goedgekeurd).

alter table public.product_features
  add column if not exists classification_status text check (classification_status in ('classified','not_swap_relevant','review_required')),
  add column if not exists matched_rule_id bigint references public.swap_family_rules(rule_id),
  add column if not exists rule_version int,
  add column if not exists mapping_version int,
  add column if not exists classification_confidence numeric,
  add column if not exists classification_reason text,
  add column if not exists source_fingerprint text,
  add column if not exists classified_at timestamptz;

-- FK van product_features.swap_family naar swap_family_mapping, on
-- update/delete restrict (voorkomt per ongeluk een familie verwijderen of
-- hernoemen zolang er nog producten naar verwijzen). 0 orphans bevestigd in
-- fase 1, dus dit zou zonder conflicten moeten slagen.
alter table public.product_features
  add constraint fk_swap_family
  foreign key (swap_family) references public.swap_family_mapping(swap_family)
  on update restrict on delete restrict;

-- POSTFLIGHT: select column_name from information_schema.columns where
--   table_name='product_features' and column_name in
--   ('classification_status','matched_rule_id','rule_version','mapping_version',
--    'classification_confidence','classification_reason','source_fingerprint','classified_at');
--   -- moet 8 rijen zijn

-- ROLLBACK: alter table public.product_features drop constraint fk_swap_family;
--           alter table public.product_features
--             drop column classification_status, drop column matched_rule_id,
--             drop column rule_version, drop column mapping_version,
--             drop column classification_confidence, drop column classification_reason,
--             drop column source_fingerprint, drop column classified_at;
