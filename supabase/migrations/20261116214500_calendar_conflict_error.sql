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
      using errcode = 'P0001';
  end if;

  return next_revision;
end;
$$;
