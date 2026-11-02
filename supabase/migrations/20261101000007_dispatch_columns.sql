-- Champs du dispatch serveur (lib/dispatch/workflow.ts).
alter table public.driver_profiles add column current_offer_ride_id text;

alter table public.ride_requests
  add column dispatch_candidates text[] not null default '{}',
  add column rejected_by text[] not null default '{}',
  add column fare_flag_reason text;

-- Les courses en recherche (par véhicule) et les chauffeurs candidats : index de sélection
create index on public.driver_profiles (vehicle_type, status) where driver_online;
create index on public.driver_locations (updated_at);
