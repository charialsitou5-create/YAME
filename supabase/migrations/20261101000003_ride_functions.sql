-- Écritures de courses côté client : une fonction par transition autorisée (remplace les règles `diff().affectedKeys()`).
-- SECURITY DEFINER : elles s'exécutent avec les droits du propriétaire, mais vérifient l'identité via public.uid().
-- Les transitions serveur (attribution, paiement, commission, remboursement) restent dans yame-admin (service_role).

create or replace function public.create_ride(
  p_pickup_lat double precision, p_pickup_lng double precision, p_pickup_address text,
  p_destination_lat double precision, p_destination_lng double precision, p_destination_address text,
  p_vehicle_type text, p_client_name text, p_price bigint default null,
  p_recipient_name text default null, p_recipient_phone text default null,
  p_recipient_instructions text default null, p_contact_requester_instead boolean default false
) returns text
language plpgsql security definer set search_path = public as $$
declare v_uid text := public.uid(); v_id text;
begin
  if v_uid is null then raise exception 'non authentifié'; end if;
  insert into public.ride_requests (
    client_uid, client_name, pickup_lat, pickup_lng, pickup_address,
    destination_lat, destination_lng, destination_address, vehicle_type, price,
    recipient_name, recipient_phone, recipient_instructions, contact_requester_instead)
  values (v_uid, p_client_name, p_pickup_lat, p_pickup_lng, p_pickup_address,
    p_destination_lat, p_destination_lng, p_destination_address, p_vehicle_type, p_price,
    p_recipient_name, p_recipient_phone, p_recipient_instructions, coalesce(p_contact_requester_instead, false))
  returning id into v_id;
  update public.users set client_active_ride_id = v_id where uid = v_uid;
  return v_id;
end $$;

-- Le client annule tant que la course n'a pas démarré.
create or replace function public.client_cancel_ride(p_ride_id text, p_reason text default null, p_comment text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid text := public.uid(); v_ride public.ride_requests;
begin
  select * into v_ride from public.ride_requests where id = p_ride_id for update;
  if not found or v_ride.client_uid is distinct from v_uid then raise exception 'course introuvable'; end if;
  if v_ride.status not in ('searching', 'accepted', 'arrived') then raise exception 'annulation impossible à ce stade'; end if;
  update public.ride_requests
     set status = 'cancelled', cancel_reason = p_reason, cancel_comment = p_comment
   where id = p_ride_id;
  update public.users set client_active_ride_id = null where uid = v_uid and client_active_ride_id = p_ride_id;
end $$;

-- Le chauffeur assigné fait avancer sa course d'une étape à la fois, ou l'annule avant la fin.
create or replace function public.driver_advance_ride(p_ride_id text, p_new_status text)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid text := public.uid(); v_ride public.ride_requests;
begin
  select * into v_ride from public.ride_requests where id = p_ride_id for update;
  if not found or v_ride.driver_uid is distinct from v_uid then raise exception 'course introuvable'; end if;
  if not (
       (v_ride.status = 'accepted' and p_new_status in ('arrived', 'cancelled'))
    or (v_ride.status = 'arrived' and p_new_status in ('inProgress', 'cancelled'))
    or (v_ride.status = 'inProgress' and p_new_status in ('completed', 'cancelled'))
  ) then raise exception 'transition % -> % interdite', v_ride.status, p_new_status; end if;
  update public.ride_requests set status = p_new_status where id = p_ride_id;
  if p_new_status in ('completed', 'cancelled') then
    update public.users set driver_active_ride_id = null where uid = v_uid and driver_active_ride_id = p_ride_id;
    update public.users set client_active_ride_id = null where uid = v_ride.client_uid and client_active_ride_id = p_ride_id;
    update public.driver_locations set active_client_uid = null where driver_uid = v_uid;
    update public.client_locations set active_driver_uid = null where client_uid = v_ride.client_uid;
  end if;
end $$;

-- Le client note le chauffeur une fois la course terminée.
create or replace function public.rate_ride(
  p_ride_id text, p_rating int, p_comment text default null,
  p_punctuality int default null, p_driving int default null, p_courtesy int default null, p_cleanliness int default null
) returns void language plpgsql security definer set search_path = public as $$
declare v_uid text := public.uid(); v_ride public.ride_requests;
begin
  select * into v_ride from public.ride_requests where id = p_ride_id for update;
  if not found or v_ride.client_uid is distinct from v_uid then raise exception 'course introuvable'; end if;
  if v_ride.status <> 'completed' then raise exception 'la course n''est pas terminée'; end if;
  update public.ride_requests
     set rating = p_rating, rating_comment = p_comment, rating_punctuality = p_punctuality,
         rating_driving = p_driving, rating_courtesy = p_courtesy, rating_cleanliness = p_cleanliness
   where id = p_ride_id;
end $$;

-- Inscription d'un signalement : mémorise aussi l'entrée dans users.my_reports (50 derniers), comme l'app actuelle.
create or replace function public.submit_incident(
  p_kind text, p_category text, p_message text, p_reporter_role text default null, p_ride_id text default null
) returns text language plpgsql security definer set search_path = public as $$
declare v_uid text := public.uid(); v_id text;
begin
  if v_uid is null then raise exception 'non authentifié'; end if;
  insert into public.incidents (reporter_uid, reporter_role, kind, category, message, ride_id)
  values (v_uid, p_reporter_role, p_kind, p_category, left(p_message, 2000), p_ride_id) returning id into v_id;
  update public.users
     set my_reports = (
       select coalesce(jsonb_agg(e order by (e ->> 'createdAt') desc), '[]'::jsonb) from (
         select e from jsonb_array_elements(
           jsonb_build_array(jsonb_build_object('id', v_id, 'kind', p_kind, 'category', p_category,
             'message', left(p_message, 500), 'createdAt', now())) || my_reports) e limit 50) s)
   where uid = v_uid;
  return v_id;
end $$;

revoke all on function public.create_ride, public.client_cancel_ride, public.driver_advance_ride,
  public.rate_ride, public.submit_incident from public, anon;
grant execute on function public.create_ride, public.client_cancel_ride, public.driver_advance_ride,
  public.rate_ride, public.submit_incident to authenticated;
