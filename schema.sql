-- Herbstmarkt Kasse: Datenbank (Supabase). Einmal im SQL-Editor ausführen.
-- Der Stand-Code schützt die Daten: Nur Geräte mit dem richtigen Code können lesen und schreiben.

create table config (code text not null);
alter table config enable row level security;  -- für die App unsichtbar

create table products (
  id bigint generated always as identity primary key,
  name text not null,
  price numeric(6,2) not null default 0,
  station text not null check (station in ('crepe','popcorn')),
  sort int not null default 0
);

create table orders (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  items jsonb not null,
  total numeric(8,2) not null,
  cancelled boolean not null default false,
  crepe_done_at timestamptz,
  popcorn_done_at timestamptz
);

create function stand_code_ok() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from config
    where code = current_setting('request.headers', true)::json->>'x-stand-code');
$$;

alter table products enable row level security;
alter table orders enable row level security;
create policy stand on products for all to anon using (stand_code_ok()) with check (stand_code_ok());
create policy stand on orders for all to anon using (stand_code_ok()) with check (stand_code_ok());

-- Alle Bestellungen löschen und Nummern wieder bei 1 starten (Knopf in „Sorten“)
create function reset_orders() returns void
language plpgsql security definer set search_path = public as $$
begin
  if not stand_code_ok() then raise exception 'Stand-Code falsch'; end if;
  truncate orders restart identity;
end $$;

-- Rechte: Die App (Rolle anon) darf nur an Sorten und Bestellungen, nie an den Code
revoke all on config from anon, authenticated;
grant select, insert, update, delete on products, orders to anon;
grant execute on function stand_code_ok(), reset_orders() to anon;

-- Wechselgeld am Anfang (eine Zeile, ergänzt 20.11.2026)
create table settings (id int primary key default 1 check (id = 1), float numeric(8,2) not null default 0);
alter table settings enable row level security;
create policy stand on settings for all to anon using (stand_code_ok()) with check (stand_code_ok());
grant select, update on settings to anon;
insert into settings default values;

-- Stand-Code festlegen (nicht hier im Code speichern, beim Ausführen eintragen):
-- insert into config values ('DEIN-CODE');
