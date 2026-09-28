-- Telemetry: every go at every level (docs/phase-8-server.md, 8.4).
--
-- Run once, in the SQL Editor, after 0002.
--
-- Insert-only. The game can write a row and nothing else: no reading, no
-- changing, no deleting. A go is sent when the level is finished, when
-- another level is picked, and when the app is put away mid-level — so one
-- go can be more than one row, and the last row per attempt_id is the go.
-- `level_stats` below does that.

create table if not exists attempts (
  id          bigint generated always as identity primary key,
  attempt_id  uuid not null,
  device_id   uuid not null,     -- random per install; no account behind it
  level_id    text not null check (char_length(level_id) <= 100),
  delays      real[] not null,
  outcome     text not null check (outcome in ('finished', 'left', 'hidden')),
  seconds     real not null check (seconds >= 0 and seconds < 86400),
  reloads     int  not null check (reloads between 0 and 100000),
  deaths      jsonb not null default '[]'
              check (jsonb_typeof(deaths) = 'array'
                     and jsonb_array_length(deaths) <= 200),
  created_at  timestamptz not null default now()
);

create index if not exists attempts_level on attempts (level_id);

alter table attempts enable row level security;

create policy "anyone records a go" on attempts
  for insert to anon, authenticated
  with check (true);

revoke all on attempts from anon, authenticated;
grant insert (attempt_id, device_id, level_id, delays, outcome, seconds,
              reloads, deaths)
  on attempts to anon, authenticated;

-- One line per level, for reading in the dashboard.
--
--   select * from level_stats order by gave_up_pct desc;
--
-- security_invoker, so the view obeys the table's RLS instead of its
-- owner's rights — without it, a view in `public` is a way round the
-- policies above for anyone with the publishable key.
create or replace view level_stats with (security_invoker = true) as
with last as (
  select distinct on (attempt_id) *
  from attempts
  order by attempt_id, seconds desc, created_at desc
)
select
  level_id,
  count(*)                                           as goes,
  count(distinct device_id)                          as players,
  count(*) filter (where outcome = 'finished')       as finished,
  round(100.0 * count(*) filter (where outcome <> 'finished') / count(*), 1)
                                                     as gave_up_pct,
  round(avg(reloads) filter (where outcome = 'finished'), 1)
                                                     as reloads_to_finish,
  round((percentile_cont(0.5) within group (order by seconds)
         filter (where outcome = 'finished'))::numeric, 1)
                                                     as median_seconds
from last
group by level_id;

revoke all on level_stats from anon, authenticated;

-- Where people die in one level, most first, in squares of 50 world units
-- (a body is 44 wide, so two deaths in the same square are the same spot):
--
--   select round((d->>0)::numeric / 50) * 50 as x,
--          round((d->>1)::numeric / 50) * 50 as y,
--          count(*)
--   from attempts, jsonb_array_elements(deaths) d
--   where level_id = 'two-not-one'
--   group by 1, 2 order by 3 desc limit 20;
