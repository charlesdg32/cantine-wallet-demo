-- Store a selectable emoji with every product; existing products get the coffee default.
alter table public.products
  add column if not exists emoji text not null default '☕';
