-- RLS : traduction de YAME/firestore.rules. Toutes les tables sont privées par défaut.
-- Les tables sans policy (transactions, retraits…) ne sont accessibles qu'avec la clé service_role (serveur Next.js).
-- Les écritures sensibles (statuts de course, finances) passent par des fonctions SECURITY DEFINER (migration 3).

alter table public.users enable row level security;
alter table public.driver_profiles enable row level security;
alter table public.driver_wallets enable row level security;
alter table public.driver_locations enable row level security;
alter table public.client_locations enable row level security;
alter table public.driver_documents enable row level security;
alter table public.ride_requests enable row level security;
alter table public.ride_messages enable row level security;
alter table public.incidents enable row level security;
alter table public.incident_replies enable row level security;
alter table public.app_config enable row level security;
alter table public.transactions enable row level security;
alter table public.withdrawal_requests enable row level security;
alter table public.recharge_requests enable row level security;
alter table public.refunds enable row level security;
alter table public.service_areas enable row level security;
alter table public.admin_profiles enable row level security;
alter table public.admin_settings enable row level security;
alter table public.alert_acks enable row level security;
alter table public.audit_log enable row level security;
alter table public.app_events enable row level security;
alter table public.finance_expenses enable row level security;
alter table public.moderation_log enable row level security;

-- Ne rien accorder par défaut à anon ; les clients connectés (rôle authenticated) passent par les policies.
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;
grant select, insert, update on public.users, public.driver_profiles, public.driver_locations,
  public.client_locations, public.driver_documents to authenticated;
grant select, insert on public.driver_wallets, public.ride_messages, public.incidents to authenticated;
grant select on public.ride_requests, public.incident_replies, public.app_config to authenticated;

-- ---------------------------------------------------------------- users
create policy users_select_own on public.users for select to authenticated using (uid = public.uid());
create policy users_insert_own on public.users for insert to authenticated with check (uid = public.uid());
create policy users_update_own on public.users for update to authenticated
  using (uid = public.uid()) with check (uid = public.uid());

-- Champs de modération et bascule de mode : gardés par trigger (les privilèges de colonne ne savent pas comparer les valeurs).
create or replace function public.guard_users() returns trigger language plpgsql as $$
begin
  if public.is_service() then return new; end if;
  if tg_op = 'INSERT' then
    if new.moderation_status <> 'active' or new.moderation_until is not null or new.moderation_reason is not null then
      raise exception 'champs de modération réservés à l''administration';
    end if;
    return new;
  end if;
  if new.moderation_status is distinct from old.moderation_status
     or new.moderation_until is distinct from old.moderation_until
     or new.moderation_reason is distinct from old.moderation_reason then
    raise exception 'champs de modération réservés à l''administration';
  end if;
  if new.active_mode is distinct from old.active_mode then
    if old.active_mode = 'client' and old.client_active_ride_id is not null then
      raise exception 'course client en cours : bascule impossible';
    end if;
    if old.active_mode = 'driver' and old.driver_active_ride_id is not null then
      raise exception 'course chauffeur en cours : bascule impossible';
    end if;
  end if;
  return new;
end $$;
create trigger guard_users before insert or update on public.users
  for each row execute function public.guard_users();

-- ---------------------------------------------------------------- driver_profiles
create policy driver_profiles_select on public.driver_profiles for select to authenticated
  using (uid = public.uid() or status = 'approved');
create policy driver_profiles_insert on public.driver_profiles for insert to authenticated
  with check (uid = public.uid() and status = 'pending_verification');
create policy driver_profiles_update on public.driver_profiles for update to authenticated
  using (uid = public.uid()) with check (uid = public.uid());

create or replace function public.guard_driver_profiles() returns trigger language plpgsql as $$
begin
  if public.is_service() then return new; end if;
  if tg_op = 'INSERT' then
    if new.suspended_until is not null or new.moderation_status is not null or new.moderation_until is not null
       or new.moderation_reason is not null or new.reviewed_by is not null or new.reviewed_at is not null
       or new.rating_avg is not null or new.rating_count <> 0 then
      raise exception 'champs réservés à l''administration';
    end if;
    return new;
  end if;
  if new.status is distinct from old.status
     or new.suspended_until is distinct from old.suspended_until
     or new.moderation_status is distinct from old.moderation_status
     or new.moderation_until is distinct from old.moderation_until
     or new.moderation_reason is distinct from old.moderation_reason
     or new.reviewed_by is distinct from old.reviewed_by
     or new.reviewed_at is distinct from old.reviewed_at
     or new.rating_avg is distinct from old.rating_avg
     or new.rating_count is distinct from old.rating_count then
    raise exception 'champs réservés à l''administration';
  end if;
  return new;
end $$;
create trigger guard_driver_profiles before insert or update on public.driver_profiles
  for each row execute function public.guard_driver_profiles();

-- ---------------------------------------------------------------- wallet : lecture propriétaire, création à 0, jamais de modification client
create policy driver_wallets_select on public.driver_wallets for select to authenticated
  using (driver_uid = public.uid());
create policy driver_wallets_insert on public.driver_wallets for insert to authenticated
  with check (driver_uid = public.uid() and balance = 0);

-- ---------------------------------------------------------------- positions GPS (accès croisé limité à 2 h)
create policy driver_locations_select on public.driver_locations for select to authenticated
  using (driver_uid = public.uid()
         or (active_client_uid = public.uid() and updated_at > now() - interval '2 hours'));
create policy driver_locations_insert on public.driver_locations for insert to authenticated
  with check (driver_uid = public.uid());
create policy driver_locations_update on public.driver_locations for update to authenticated
  using (driver_uid = public.uid()) with check (driver_uid = public.uid());

create policy client_locations_select on public.client_locations for select to authenticated
  using (client_uid = public.uid()
         or (active_driver_uid = public.uid() and updated_at > now() - interval '2 hours'));
create policy client_locations_insert on public.client_locations for insert to authenticated
  with check (client_uid = public.uid());
create policy client_locations_update on public.client_locations for update to authenticated
  using (client_uid = public.uid()) with check (client_uid = public.uid());

-- ---------------------------------------------------------------- documents d'identité : propriétaire seulement
create policy driver_documents_all on public.driver_documents for all to authenticated
  using (driver_uid = public.uid()) with check (driver_uid = public.uid());

-- ---------------------------------------------------------------- courses : lecture par les parties ; écritures via fonctions
create policy ride_requests_select on public.ride_requests for select to authenticated
  using (client_uid = public.uid() or driver_uid = public.uid() or offered_uid = public.uid());

create or replace function public.is_ride_party(p_ride_id text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.ride_requests r
                 where r.id = p_ride_id and (r.client_uid = public.uid() or r.driver_uid = public.uid()))
$$;

create policy ride_messages_select on public.ride_messages for select to authenticated
  using (public.is_ride_party(ride_id));
create policy ride_messages_insert on public.ride_messages for insert to authenticated
  with check (sender_uid = public.uid() and public.is_ride_party(ride_id));

-- ---------------------------------------------------------------- signalements : l'auteur crée, ne relit pas ; il lit les réponses
create policy incidents_insert on public.incidents for insert to authenticated
  with check (reporter_uid = public.uid() and status = 'open');

create or replace function public.is_incident_reporter(p_incident_id text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.incidents i where i.id = p_incident_id and i.reporter_uid = public.uid())
$$;
create policy incident_replies_select on public.incident_replies for select to authenticated
  using (public.is_incident_reporter(incident_id));

-- ---------------------------------------------------------------- config : lecture pour tout utilisateur connecté
create policy app_config_select on public.app_config for select to authenticated using (true);

-- ---------------------------------------------------------------- temps réel (le Realtime applique la RLS)
alter publication supabase_realtime add table
  public.users, public.driver_profiles, public.driver_wallets, public.driver_locations,
  public.client_locations, public.ride_requests, public.ride_messages, public.incident_replies;
