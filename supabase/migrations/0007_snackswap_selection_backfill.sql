-- 0007_snackswap_selection_backfill.sql
-- Backfill van de selectie- en clusterkolommen voor de bestaande producten.
-- Rule-based, geen AI. Idempotent (herberekent puur uit products).

update public.product_features pf set
  swap_relevance_reason = public.compute_swap_relevance(p.pnns_groups_1, p.pnns_groups_2, p.categories_tags),
  is_swap_relevant      = public.compute_swap_relevance(p.pnns_groups_1, p.pnns_groups_2, p.categories_tags) is not null,
  cluster_key           = case
    when public.compute_swap_relevance(p.pnns_groups_1, p.pnns_groups_2, p.categories_tags) is not null
    then public.compute_cluster_key(p.categories_tags, p.main_category, p.kcal_100g, p.sugar_100g, p.protein_100g)
    else null end,
  updated_at            = now()
from public.products p
where pf.barcode = p.barcode;

-- Kies 1 representant per cluster.
select public.refresh_swap_representatives();
