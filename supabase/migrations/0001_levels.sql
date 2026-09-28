-- The levels table (docs/phase-8-server.md §4).
--
-- Run once, in the Supabase dashboard: SQL Editor → New query → paste → Run.
-- It is safe to read: nothing here holds a secret. What protects the table is
-- the row-level security below, not the anon key the app ships with.

create table if not exists levels (
  id          text primary key,
  data        jsonb not null,              -- Level.toJson(), solution and all
  author      uuid references auth.users,
  status      text not null default 'pending'
              check (status in ('pending', 'published', 'rejected')),
  verdict     text,                        -- why the gate said no
  checked_by  text,                        -- the build that judged it
  sort_order  int not null default 1000,
  created_at  timestamptz not null default now()
);

alter table levels enable row level security;

-- The game reads published levels with the anon key and nothing else.
create policy "anyone reads published" on levels
  for select using (status = 'published');

-- An author sees their own submissions, verdicts included.
create policy "authors read their own" on levels
  for select using (auth.uid() = author);

-- An author can submit, and only as pending: publishing is the gate's alone.
create policy "authors submit" on levels
  for insert with check (auth.uid() = author and status = 'pending');

-- No update and no delete from any client. The gate uses the service key,
-- which bypasses row-level security, and that key lives in GitHub secrets.

grant select on levels to anon, authenticated;
grant insert on levels to authenticated;
