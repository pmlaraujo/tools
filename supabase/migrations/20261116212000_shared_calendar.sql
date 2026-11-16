create table if not exists public.calendar_shared_state (
  id text primary key check (id = 'essity'),
  data jsonb not null,
  revision bigint not null default 0,
  updated_at timestamptz not null default now()
);

insert into public.calendar_shared_state (id, data)
values (
  'essity',
  '{"employees":{"management":[],"carla":[],"angela":[]},"marks":[],"marketAssignments":[],"marketPlans":[],"marketCovers":[],"marketMarks":[],"vacationQuotas":[]}'::jsonb
)
on conflict (id) do nothing;

alter table public.calendar_shared_state enable row level security;

create policy "Anyone can read the shared Essity calendar"
  on public.calendar_shared_state for select to anon
  using (true);

grant select on public.calendar_shared_state to anon;
revoke insert, update, delete on public.calendar_shared_state from anon, authenticated;

create or replace function public.save_calendar_state(p_data jsonb, p_expected_revision bigint)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_revision bigint;
begin
  if jsonb_typeof(p_data) is distinct from 'object' then
    raise exception 'Calendar state must be a JSON object.'
      using errcode = '22023';
  end if;

  update public.calendar_shared_state
  set data = p_data,
      revision = revision + 1,
      updated_at = now()
  where id = 'essity'
    and revision = p_expected_revision
  returning revision into next_revision;

  if next_revision is null then
    raise exception 'Calendar changed elsewhere; reload the latest data before saving.'
      using errcode = '40001';
  end if;

  return next_revision;
end;
$$;

revoke all on function public.save_calendar_state(jsonb, bigint) from public;
grant execute on function public.save_calendar_state(jsonb, bigint) to anon;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'calendar_shared_state'
  ) then
    alter publication supabase_realtime
      add table public.calendar_shared_state;
  end if;
end;
$$;
