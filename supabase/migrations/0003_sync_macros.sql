-- Bitewise – voegt koolhydraten en vet toe aan de gesynchroniseerde logs.
-- Veilig op een bestaande database (idempotent).

alter table public.user_day_logs
  add column if not exists carbs numeric not null default 0;

alter table public.user_day_logs
  add column if not exists fat numeric not null default 0;
