-- ---------------------------------------------------------------------------
-- 1. Opschoning van veilige ballast (geen tabellen/kolommen verwijderd, geen
--    "levende" data verloren):
--    a) vocab-waarden die door taxonomy v2 zijn vervangen en nergens meer
--       gebruikt worden (geverifieerd: 0 product_features-rijen gebruiken ze).
--    b) overtollige staging-historie: dezelfde barcode meerdere keren gestaged
--       (ontstaan door de eerder gevonden/gefixte dubbel-verwerkingsbug) --
--       we bewaren per barcode alleen de meest recente rij, de rest is pure
--       historische ruis zonder nog enig doel.
-- ---------------------------------------------------------------------------
delete from public.feature_vocabulary where field = 'swap_family' and value in ('soft_drinks', 'sweet_spreads');

delete from public.product_features_staging s
using (
  select id,
    row_number() over (partition by barcode order by created_at desc, id desc) as rn
  from public.product_features_staging
) ranked
where s.id = ranked.id and ranked.rn > 1;

-- ---------------------------------------------------------------------------
-- 2. Consistentiefix: approve_staged_features() zette tot nu toe nog steeds
--    snack_type/category_cluster rechtstreeks vanuit AI-staging-data, terwijl
--    die twee velden sinds taxonomy v2 (0026-0028) altijd deterministisch uit
--    swap_family_mapping horen te komen. Zolang de verrijkingspipeline niet
--    meer draaide viel dit niet op -- maar zodra hij ooit weer een batch
--    verwerkt, zou dit de net gebouwde consistentiegarantie stilzwijgend
--    doorbreken. Taste_profile/texture_profile/use_moment/swap_tags/
--    recommended_swap_directions/is_sweet/is_salty/is_crunchy blijven wel
--    AI-afkomstig (die vallen niet onder de swap_family-mapping).
-- ---------------------------------------------------------------------------
create or replace function public.approve_staged_features()
returns integer language plpgsql as $$
declare
  r         record;
  v_cluster text;
  v_count   int := 0;
begin
  for r in select * from public.product_features_staging
           where validation_status = 'approved' and applied_at is null loop
    select cluster_key into v_cluster from public.product_features where barcode = r.barcode;

    update public.product_features pf set
      taste_profile               = r.taste_profile,
      texture_profile              = r.texture_profile,
      use_moment                   = r.use_moment,
      swap_tags                    = r.swap_tags,
      recommended_swap_directions  = r.recommended_swap_directions,
      is_sweet                     = r.is_sweet,
      is_salty                     = r.is_salty,
      is_crunchy                   = r.is_crunchy,
      ai_confidence                = r.ai_confidence,
      ai_model                     = r.ai_model,
      ai_enriched_at               = now(),
      updated_at                   = now()
    where (v_cluster is not null and pf.cluster_key = v_cluster)
       or pf.barcode = r.barcode;

    update public.product_features_staging set applied_at = now() where id = r.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;
