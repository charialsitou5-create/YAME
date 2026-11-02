-- Aligne ride_requests sur les champs réellement écrits par le dispatch (lib/fare.ts : buildFrozenFare).
alter table public.ride_requests rename column fare_frozen_amount to fare_frozen;
alter table public.ride_requests
  add column fare_frozen_km numeric,
  add column fare_frozen_commission_rate numeric,
  add column fare_frozen_at timestamptz;
