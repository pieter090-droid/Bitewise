-- ---------------------------------------------------------------------------
-- Voorbereiding voor de portie-bewuste doel-scoreformules (gebouwd door
-- Codex, zie projectgeheugen): een berekende saturated_fat_serving-kolom
-- (voorkomt dat de app deze rekensom zelf moet doen en overal consistent
-- moet houden), en opschoning van de 2 producten met een ongeldige
-- (<=0) portiegrootte -- die zouden een deling-door-nul of onzinnige
-- per-portie-waarde opleveren.
-- ---------------------------------------------------------------------------
alter table public.products
  add column if not exists saturated_fat_serving numeric;

update public.products
set saturated_fat_serving = round(saturated_fat_100g * serving_quantity / 100.0, 2)
where saturated_fat_100g is not null
  and serving_quantity is not null
  and serving_quantity > 0
  and saturated_fat_serving is distinct from round(saturated_fat_100g * serving_quantity / 100.0, 2);

-- Ongeldige portiegroottes: NULL is eerlijker dan een onzinnig getal (nooit
-- gokken, zelfde NULL-veilige principe als de rest van dit model).
update public.products
set serving_quantity = null, kcal_serving = null, proteins_serving = null,
    sugars_serving = null, fiber_serving = null, salt_serving = null,
    saturated_fat_serving = null
where serving_quantity is not null and serving_quantity <= 0;

-- Trigger die saturated_fat_serving automatisch bijhoudt voor nieuwe/
-- bijgewerkte producten (zelfde patroon als de rest: 1x berekenen, nooit
-- los laten driften).
create or replace function public.compute_saturated_fat_serving()
returns trigger language plpgsql as $$
begin
  NEW.saturated_fat_serving := case
    when NEW.saturated_fat_100g is not null and NEW.serving_quantity is not null and NEW.serving_quantity > 0
      then round(NEW.saturated_fat_100g * NEW.serving_quantity / 100.0, 2)
    else null
  end;
  return NEW;
end $$;

drop trigger if exists products_compute_saturated_fat_serving on public.products;
create trigger products_compute_saturated_fat_serving
  before insert or update on public.products
  for each row execute function public.compute_saturated_fat_serving();
