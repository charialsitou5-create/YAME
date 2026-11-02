-- Champs utilisés par les pages admin (signalements, modération) et absents du premier schéma.
alter table public.incidents
  add column reporter_name text,
  add column notes jsonb not null default '[]'::jsonb,   -- [{ text, by, at }]
  add column taken_at timestamptz,
  add column resolved_at timestamptz,
  add column last_reply_at timestamptz,
  add column last_reply_by text;

alter table public.moderation_log
  add column previous_status text,
  add column new_status text;
