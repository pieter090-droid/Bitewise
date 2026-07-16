-- Invariant-fix: elke *_non_swap-familie moet is_swap_relevant=false hebben.
-- Postflight van 0079 vond 57 overtredingen: 16 uit auditmigraties 0074-0079
-- (updates zetten familie maar vergaten de vlag), 33 dairy_cooking_cream uit
-- batch5_promotion_r1, en enkele oudere. Barcode-onafhankelijk maar strak
-- afgebakend op de familienaam-conventie.
--
-- `products` wordt nergens aangeraakt. `products` blijft raw.

create table if not exists public._snapshot_0080_before as
select barcode, swap_family, is_swap_relevant, classification_status,
       classification_confidence, classification_reason, matched_rule_id,
       rule_version, mapping_version, source_fingerprint, classified_at
from public.product_features
where swap_family like '%\_non\_swap' escape '\' and is_swap_relevant;

update public.product_features
set is_swap_relevant = false
where swap_family like '%\_non\_swap' escape '\' and is_swap_relevant;

-- POSTFLIGHT:
--   select count(*) from product_features
--   where swap_family like '%_non_swap' and is_swap_relevant; -- 0
-- ROLLBACK: herstel is_swap_relevant vanuit _snapshot_0080_before.
