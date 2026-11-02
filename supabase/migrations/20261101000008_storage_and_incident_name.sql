-- Documents chauffeur : bucket PRIVÉ (liens signés à durée limitée, générés côté serveur admin).
-- Chemin : {uid}/{fichier}. Le chauffeur n'écrit/lit que son dossier ; l'admin passe par la clé service_role.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('driver-documents', 'driver-documents', false, 8388608,
        array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy driver_documents_storage_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = public.uid());
create policy driver_documents_storage_update on storage.objects for update to authenticated
  using (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = public.uid())
  with check (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = public.uid());
create policy driver_documents_storage_select on storage.objects for select to authenticated
  using (bucket_id = 'driver-documents' and (storage.foldername(name))[1] = public.uid());

-- Le signalement enregistre aussi le nom de l'auteur (affiché dans l'admin).
drop function if exists public.submit_incident(text, text, text, text, text);
create or replace function public.submit_incident(
  p_kind text, p_category text, p_message text, p_reporter_role text default null, p_ride_id text default null,
  p_reporter_name text default null
) returns text language plpgsql security definer set search_path = public as $$
declare v_uid text := public.uid(); v_id text;
begin
  if v_uid is null then raise exception 'non authentifié'; end if;
  insert into public.incidents (reporter_uid, reporter_name, reporter_role, kind, category, message, ride_id)
  values (v_uid, left(p_reporter_name, 200), p_reporter_role, p_kind, p_category, left(p_message, 2000), p_ride_id)
  returning id into v_id;
  update public.users
     set my_reports = (
       select coalesce(jsonb_agg(e order by (e ->> 'createdAt') desc), '[]'::jsonb) from (
         select e from jsonb_array_elements(
           jsonb_build_array(jsonb_build_object('id', v_id, 'kind', p_kind, 'category', p_category,
             'message', left(p_message, 500), 'createdAt', now())) || my_reports) e limit 50) s)
   where uid = v_uid;
  return v_id;
end $$;
revoke all on function public.submit_incident(text, text, text, text, text, text) from public, anon;
grant execute on function public.submit_incident(text, text, text, text, text, text) to authenticated;
