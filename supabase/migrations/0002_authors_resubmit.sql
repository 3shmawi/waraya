-- Authors can send a level again after the gate says no (docs/phase-8-server.md).
--
-- Run once, in the SQL Editor, after 0001_levels.sql.
--
-- Without this, a rejected level could never be fixed under its own id: the
-- table had no update policy at all. This allows exactly one: an author may
-- put their own row back to 'pending' with new data, as long as it is not
-- published. A published level stays as the gate saw it — changing it means
-- a new id.
--
-- And the columns are narrowed, for insert as well as update, so a client
-- cannot pick its own sort_order or write its own verdict.

create policy "authors resubmit" on levels
  for update
  using (auth.uid() = author and status in ('pending', 'rejected'))
  with check (auth.uid() = author and status = 'pending');

-- Supabase grants every privilege on a new table to anon and authenticated
-- by default, and leaves it to row-level security. RLS already stops all of
-- this; taking the privileges away as well means one wrong policy later is
-- not enough to open it.
revoke insert, update, delete, truncate on levels from anon;
revoke insert, update, delete, truncate on levels from authenticated;
grant insert (id, data, author, status) on levels to authenticated;
grant update (data, status, verdict) on levels to authenticated;
