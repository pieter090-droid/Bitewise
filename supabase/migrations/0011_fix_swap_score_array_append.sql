-- ---------------------------------------------------------------------------
-- Bugfix: calculate_swap_score gooide "malformed array literal" zodra de
-- allergenen-waarschuwing werd toegevoegd. Oorzaak: `text[] || 'plain string'`
-- laat Postgres de anyarray||anyarray-operator kiezen (want de RHS heeft nog
-- geen concreet type), waardoor de losse string als array-literal ("{...}")
-- geparsed wordt in plaats van als los element aangehangen. Bevestigd
-- reproduceerbaar via: select ('{}'::text[]) || 'zomaar een tekst';
-- Fix: array_append() gebruiken, dat is nooit ambigu. (De `format(...)`-varianten
-- verderop in dezelfde functie hadden dit probleem niet, want format() geeft
-- al een concreet `text`-type terug.)
-- ---------------------------------------------------------------------------
create or replace function public.calculate_swap_score(
  p_from text, p_to text, p_goal text default null, p_day_context jsonb default '{}'::jsonb
) returns table(score numeric, breakdown jsonb, reasons text[], warnings text[])
language plpgsql stable as $$
declare
  f record; t record; w record;
  v_goal_match numeric := 0;
  v_nutrition  numeric := 0;
  v_daycontext numeric := 0;
  v_similarity numeric; v_sim_breakdown jsonb;
  v_processing numeric := 0;
  v_dataquality numeric := 0;
  v_total numeric;
  v_reasons text[] := '{}';
  v_warnings text[] := '{}';
  v_kcal_remaining numeric;
  v_sugar_remaining numeric;
begin
  select * into w from public.swap_score_weights where is_active = true order by created_at desc limit 1;

  select p.kcal_100g, p.sugar_100g, p.protein_100g, p.fiber_100g, p.salt_100g, p.allergens,
         pf.category_cluster, pf.processing_quality_score, pf.data_quality_score, pf.ai_confidence
    into f
    from public.products p join public.product_features pf on pf.barcode = p.barcode
    where p.barcode = p_from;

  select p.kcal_100g, p.sugar_100g, p.protein_100g, p.fiber_100g, p.salt_100g, p.allergens,
         pf.category_cluster, pf.processing_quality_score, pf.data_quality_score, pf.ai_confidence
    into t
    from public.products p join public.product_features pf on pf.barcode = p.barcode
    where p.barcode = p_to;

  -- Harde poort: nooit chocolade -> komkommer. Buiten hetzelfde cluster
  -- komt een kandidaat niet eens in de ranking terecht.
  if f.category_cluster is null or f.category_cluster is distinct from t.category_cluster then
    return query select 0::numeric,
      jsonb_build_object('excluded_reason', 'category_cluster_mismatch'),
      array[]::text[], array['dit product is niet vergelijkbaar genoeg om als swap te tonen']::text[];
    return;
  end if;

  -- Voedingsverbetering (NULL-veilig: ontbrekend = overslaan, nooit 0).
  if f.sugar_100g is not null and t.sugar_100g is not null and f.sugar_100g > 0 then
    v_nutrition := v_nutrition + greatest(-1, least(1, (f.sugar_100g - t.sugar_100g) / f.sugar_100g)) * 40;
    if t.sugar_100g < f.sugar_100g then
      v_reasons := v_reasons || format('%s%% minder suiker', round((1 - t.sugar_100g/f.sugar_100g)*100));
    end if;
  end if;
  if f.kcal_100g is not null and t.kcal_100g is not null and f.kcal_100g > 0 then
    v_nutrition := v_nutrition + greatest(-1, least(1, (f.kcal_100g - t.kcal_100g) / f.kcal_100g)) * 30;
  end if;
  if f.protein_100g is not null and t.protein_100g is not null then
    v_nutrition := v_nutrition + greatest(-1, least(1, (t.protein_100g - f.protein_100g) / greatest(f.protein_100g,5))) * 20;
    if t.protein_100g > f.protein_100g then
      v_reasons := v_reasons || format('%sg meer eiwit', round(t.protein_100g - f.protein_100g));
    end if;
  end if;
  if f.fiber_100g is not null and t.fiber_100g is not null then
    v_nutrition := v_nutrition + greatest(-1, least(1, (t.fiber_100g - f.fiber_100g) / greatest(f.fiber_100g,3))) * 10;
  end if;
  v_nutrition := greatest(0, least(100, 50 + v_nutrition));

  -- Doel-match (afhankelijk van gekozen gebruikersdoel; NULL-veilig).
  v_goal_match := case p_goal
    when 'minder_suiker'    then (case when t.sugar_100g is null then 50
                                   when f.sugar_100g is null or f.sugar_100g = 0 then 50
                                   else greatest(0, least(100, 50 + (1 - t.sugar_100g/greatest(f.sugar_100g,0.1))*50)) end)
    when 'afvallen'         then (case when t.kcal_100g is null then 50
                                   when f.kcal_100g is null or f.kcal_100g = 0 then 50
                                   else greatest(0, least(100, 50 + (1 - t.kcal_100g/greatest(f.kcal_100g,1))*50)) end)
    when 'spieropbouw'      then (case when t.protein_100g is null then 50
                                   else greatest(0, least(100, 50 + (t.protein_100g - coalesce(f.protein_100g,0))*3)) end)
    when 'gezonder_eten'    then coalesce(t.processing_quality_score, 50)
    when 'gewicht_behouden' then (case when f.kcal_100g is null or t.kcal_100g is null then 50
                                   else 100 - least(100, abs(f.kcal_100g - t.kcal_100g)) end)
    else 50
  end;

  -- Dagcontext: ontbrekend = neutraal (halve bijdrage), nooit hard afstraffen.
  v_kcal_remaining := (p_day_context->>'kcal_remaining')::numeric;
  v_sugar_remaining := (p_day_context->>'sugar_remaining_g')::numeric;
  if v_kcal_remaining is not null and t.kcal_100g is not null then
    v_daycontext := case when v_kcal_remaining < 300 and t.kcal_100g < coalesce(f.kcal_100g, t.kcal_100g+1)
                          then 90 else 50 end;
  else
    v_daycontext := 50;
  end if;
  if v_sugar_remaining is not null and t.sugar_100g is not null and v_sugar_remaining < 10
     and f.sugar_100g is not null and t.sugar_100g < f.sugar_100g then
    v_daycontext := least(100, v_daycontext + 20);
  end if;

  select * into v_similarity, v_sim_breakdown from public.calculate_similarity_score(p_from, p_to);

  v_processing := coalesce(t.processing_quality_score, 50);
  v_dataquality := coalesce(t.data_quality_score, 50) * 0.7 + coalesce(t.ai_confidence, 0.5) * 100 * 0.3;

  v_total :=
      (v_goal_match   * w.weight_goal_match
     + v_nutrition    * w.weight_nutrition_improvement
     + v_daycontext   * w.weight_day_context
     + v_similarity   * w.weight_similarity
     + v_processing   * w.weight_processing_quality
     + v_dataquality  * w.weight_data_quality)
    / (w.weight_goal_match + w.weight_nutrition_improvement + w.weight_day_context
     + w.weight_similarity + w.weight_processing_quality + w.weight_data_quality);

  -- Allergenen: nooit "onbekend = veilig" (punt 7 uit de dubbelcheck-lijst).
  -- array_append (niet `||`) om de anyarray||anyarray-valkuil te vermijden.
  if f.allergens is null or t.allergens is null or trim(coalesce(t.allergens,'')) = '' then
    v_warnings := array_append(v_warnings, 'allergeneninformatie is onvolledig -- controleer het etiket');
  elsif t.allergens is not null and f.allergens is not null and t.allergens <> f.allergens then
    v_warnings := array_append(v_warnings, 'allergenen kunnen verschillen van het origineel -- controleer het etiket');
  end if;

  return query select round(v_total, 1),
    jsonb_build_object(
      'goal_match', round(v_goal_match,1), 'nutrition_improvement', round(v_nutrition,1),
      'day_context', round(v_daycontext,1), 'similarity', round(v_similarity,1),
      'similarity_breakdown', v_sim_breakdown,
      'processing_quality', round(v_processing,1), 'data_quality', round(v_dataquality,1)
    ),
    v_reasons, v_warnings;
end $$;
