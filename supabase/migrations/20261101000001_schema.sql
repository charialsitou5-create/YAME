-- Yame : schéma initial (migration depuis Firestore). Voir docs/MIGRATION_SUPABASE_INVENTAIRE.md
-- Identité : UID Firebase (texte), lu dans le JWT via public.uid(). Montants en FCFA entiers (bigint).
-- La colonne `legacy` (jsonb) recueille les champs Firestore non modélisés à l'import.

create extension if not exists postgis with schema extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------- identité
create or replace function public.uid() returns text
language sql stable as $$ select nullif(auth.jwt() ->> 'sub', '') $$;

create or replace function public.is_service() returns boolean
language sql stable as $$
  select coalesce(auth.jwt() ->> 'role', '') = 'service_role' or auth.jwt() is null
$$;

create or replace function public.new_id() returns text
language sql volatile as $$ select replace(gen_random_uuid()::text, '-', '') $$;

-- ---------------------------------------------------------------- données app
create table public.users (
  uid text primary key,
  name text not null default '',
  phone text not null default '',
  email text,
  active_mode text not null default 'client' check (active_mode in ('client', 'driver')),
  driver_vehicle_type text check (driver_vehicle_type in ('car', 'moto')),
  vehicle_registered boolean not null default false,
  client_active_ride_id text,
  driver_active_ride_id text,
  fcm_token text,
  my_reports jsonb not null default '[]'::jsonb,
  moderation_status text not null default 'active' check (moderation_status in ('active', 'blocked', 'suspended')),
  moderation_until timestamptz,
  moderation_reason text,
  created_at timestamptz not null default now(),
  legacy jsonb not null default '{}'::jsonb
);

create table public.driver_profiles (
  uid text primary key references public.users(uid) on delete cascade,
  vehicle_type text check (vehicle_type in ('car', 'moto')),
  model text,
  year int,
  plate text,
  seats int,
  color text,
  status text not null default 'pending_verification',
  driver_online boolean not null default false,
  rating_avg numeric(3, 2),
  rating_count int not null default 0,
  suspended_until timestamptz,
  moderation_status text,
  moderation_until timestamptz,
  moderation_reason text,
  reviewed_by text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  legacy jsonb not null default '{}'::jsonb
);
create index on public.driver_profiles (status);
create index on public.driver_profiles (driver_online) where driver_online;

create table public.driver_wallets (
  driver_uid text primary key references public.driver_profiles(uid) on delete cascade,
  balance bigint not null default 0,
  updated_at timestamptz not null default now()
);

create table public.driver_locations (
  driver_uid text primary key references public.driver_profiles(uid) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  heading double precision,
  active_client_uid text,
  updated_at timestamptz not null default now(),
  geo geography(Point, 4326) generated always as (extensions.st_point(lng, lat)::geography) stored
);
create index on public.driver_locations using gist (geo);

create table public.client_locations (
  client_uid text primary key references public.users(uid) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  active_driver_uid text,
  updated_at timestamptz not null default now()
);

create table public.driver_documents (
  driver_uid text primary key references public.driver_profiles(uid) on delete cascade,
  photo_urls jsonb not null default '{}'::jsonb,        -- chemins Storage, plus des URLs Firebase
  registration_card_url text,
  license_url text,
  updated_at timestamptz not null default now()
);

create table public.ride_requests (
  id text primary key default public.new_id(),
  client_uid text not null references public.users(uid),
  client_name text,
  pickup_lat double precision not null,
  pickup_lng double precision not null,
  pickup_address text,
  destination_lat double precision not null,
  destination_lng double precision not null,
  destination_address text,
  pickup_geo geography(Point, 4326) generated always as (extensions.st_point(pickup_lng, pickup_lat)::geography) stored,
  vehicle_type text not null check (vehicle_type in ('car', 'moto')),
  status text not null default 'searching'
    check (status in ('searching', 'accepted', 'arrived', 'inProgress', 'completed', 'cancelled', 'noDriverFound')),
  driver_uid text references public.users(uid),
  driver_name text,
  offered_uid text,
  offer_expires_at timestamptz,
  price bigint,
  recipient_name text,
  recipient_phone text,
  recipient_instructions text,
  contact_requester_instead boolean not null default false,
  dispatch_started boolean not null default false,
  -- champs financiers : posés par le serveur uniquement
  fare bigint,
  fare_frozen_amount bigint,
  fare_flagged boolean not null default false,
  payment_status text,
  payment_amount bigint,
  payment_method text,
  paid_at timestamptz,
  commission_status text,
  commission_amount bigint,
  driver_net_amount bigint,
  refund_status text,
  refund_amount bigint,
  -- notation par le client
  rating int check (rating between 1 and 5),
  rating_comment text,
  rating_punctuality int,
  rating_driving int,
  rating_courtesy int,
  rating_cleanliness int,
  cancel_reason text,
  cancel_comment text,
  created_at timestamptz not null default now(),
  legacy jsonb not null default '{}'::jsonb
);
create index on public.ride_requests (client_uid, status);
create index on public.ride_requests (driver_uid, status);
create index on public.ride_requests (offered_uid) where offered_uid is not null;
create index on public.ride_requests (created_at desc);

create table public.ride_messages (
  id text primary key default public.new_id(),
  ride_id text not null references public.ride_requests(id) on delete cascade,
  sender_uid text not null,
  type text not null default 'text',
  text text,
  location_address text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);
create index on public.ride_messages (ride_id, created_at);

create table public.incidents (
  id text primary key default public.new_id(),
  reporter_uid text not null,
  reporter_role text,
  kind text,
  category text,
  message text,
  ride_id text,
  status text not null default 'open',
  taken_by text,
  resolved_by text,
  internal_notes text,
  created_at timestamptz not null default now(),
  legacy jsonb not null default '{}'::jsonb
);
create index on public.incidents (reporter_uid);
create index on public.incidents (status, created_at desc);

create table public.incident_replies (
  id text primary key default public.new_id(),
  incident_id text not null references public.incidents(id) on delete cascade,
  author text not null default 'admin',
  author_uid text,
  text text not null,
  created_at timestamptz not null default now()
);
create index on public.incident_replies (incident_id, created_at);

create table public.app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- données serveur
create table public.transactions (
  id text primary key default public.new_id(),   -- ids déterministes = clés d'idempotence (withdrawal_{id}, commission par course…)
  type text not null,
  driver_id text,
  client_id text,
  ride_id text,
  withdrawal_id text,
  amount bigint not null,
  method text,
  phone text,
  status text not null default 'completed',
  earnings_balance_after bigint,
  created_by text,
  created_at timestamptz not null default now(),
  legacy jsonb not null default '{}'::jsonb
);
create index on public.transactions (type, created_at);
create index on public.transactions (type, amount);
create index on public.transactions (driver_id, created_at desc);
create index on public.transactions (ride_id);

create table public.withdrawal_requests (
  id text primary key,                            -- dérivé de driver + clé d'idempotence
  driver_id text not null,
  amount bigint not null check (amount > 0),
  method text,
  phone text,
  status text not null default 'requested' check (status in ('requested', 'approved', 'rejected', 'failed')),
  rejection_reason text,
  rejected_by text,
  rejected_at timestamptz,
  created_at timestamptz not null default now(),
  legacy jsonb not null default '{}'::jsonb
);
create index on public.withdrawal_requests (driver_id);
create index on public.withdrawal_requests (status, created_at);

create table public.recharge_requests (
  reference text primary key,
  driver_id text not null,
  amount bigint not null,
  phone_number text,
  provider text,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.refunds (
  id text primary key default public.new_id(),
  ride_id text,
  driver_id text,
  client_id text,
  amount bigint,
  status text,
  created_by text,
  created_at timestamptz not null default now(),
  legacy jsonb not null default '{}'::jsonb
);
create index on public.refunds (ride_id);

create table public.service_areas (
  id text primary key default public.new_id(),
  name text not null,
  active boolean not null default false,
  center_lat double precision,
  center_lng double precision,
  radius_km numeric,
  polygon geography(Polygon, 4326),
  created_at timestamptz not null default now(),
  legacy jsonb not null default '{}'::jsonb
);

create table public.admin_profiles (
  uid text primary key,
  email text,
  role text not null default 'admin' check (role in ('admin', 'superadmin')),
  created_at timestamptz not null default now(),
  legacy jsonb not null default '{}'::jsonb
);

create table public.admin_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table public.alert_acks (
  id text primary key,
  acked_by text,
  acked_at timestamptz not null default now(),
  legacy jsonb not null default '{}'::jsonb
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor_uid text not null,
  actor_email text,
  actor_role text,
  action text not null,
  target_type text,
  target_id text,
  ok boolean not null default true,
  details jsonb not null default '{}'::jsonb
);
create index on public.audit_log (at desc);

create table public.app_events (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  source text not null,
  category text not null,
  level text not null default 'info',
  event text not null,
  user_uid text,
  email_masked text,
  email_hash text,
  data jsonb not null default '{}'::jsonb,
  expire_at timestamptz not null default (now() + interval '90 days')
);
create index on public.app_events (at desc);
create index on public.app_events (expire_at);

create table public.finance_expenses (
  id text primary key default public.new_id(),
  label text,
  category text,
  amount bigint not null,
  spent_on date,
  created_by text,
  created_at timestamptz not null default now(),
  legacy jsonb not null default '{}'::jsonb
);

create table public.moderation_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  target_type text not null,
  target_uid text not null,
  action text not null,
  reason text,
  until timestamptz,
  actor_uid text,
  actor_email text
);
create index on public.moderation_log (target_uid, at desc);
