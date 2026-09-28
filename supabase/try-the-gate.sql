-- Two levels for trying the gate on the real table.
--
-- Run in the Supabase dashboard (SQL Editor → New query → paste → Run), then
-- either wait for the hourly run or press "Run workflow" on the gate in the
-- repository's Actions tab. Afterwards, the select at the bottom shows:
--
--   try-the-gate-good  published
--   try-the-gate-bad   rejected   wrongIdeaFinishes: wrong idea 5 finishes it in 9.2s
--
-- The good one is "stand on yourself" under a new id. The bad one is "go in
-- low" with its own solution added as a wrong idea — a wrong idea that
-- finishes the level is the thing the gate exists to catch.
--
-- Safe to run again: it puts both back to pending. The delete at the very
-- bottom removes them; published, the good one shows up at the end of every
-- player's level list.

insert into levels (id, data, status) values
  ('try-the-gate-good', $json${"id":"try-the-gate-good","name":"اوقف على نفسك","requires":["crouched-solid"],"teaches":"انت الوحيد اللي ممكن تبقى السلّمة.","delaySeconds":2.5,"delays":[2.5],"spawnX":500.0,"floorTop":620.0,"shadowIsSolid":true,"shadowSolidWhen":"crouched","shadowKills":false,"solution":[{"s":3.3,"x":-1.0},{"s":2.5,"c":true},{"s":0.9,"x":1.0},{"s":0.15},{"s":0.4,"x":-1.0},{"s":0.55,"x":-1.0,"j":true},{"s":0.6,"x":-1.0,"j":true},{"s":1.5,"x":-1.0}],"wrongIdeas":[[{"s":3.0,"x":-1.0},{"s":0.8,"x":-1.0,"j":true},{"s":2.0,"x":-1.0},{"s":0.8,"x":-1.0,"j":true},{"s":2.0,"x":-1.0}]],"goal":[-620.0,358.0,-540.0,430.0],"blocks":[[-1800.0,620.0,1800.0,2200.0],[-700.0,430.0,-280.0,470.0]],"lights":[],"markers":[],"plates":[],"toggles":[],"doors":[]}$json$::jsonb, 'pending'),
  ('try-the-gate-bad',  $json${"id":"try-the-gate-bad","name":"خُش واطي","requires":["crouched-solid"],"teaches":"تحت السقف مفيش وقوف على حاجة. المكان الوحيد هو الفتحة.","delaySeconds":3.0,"delays":[3.0],"spawnX":330.0,"floorTop":620.0,"shadowIsSolid":true,"shadowSolidWhen":"crouched","shadowKills":false,"solution":[{"s":0.5,"x":-1.0},{"s":2.9,"x":-1.0,"c":true},{"s":2.0,"c":true},{"s":1.2,"x":-1.0,"c":true},{"s":1.2,"x":1.0,"c":true},{"s":0.1},{"s":0.5,"x":1.0,"j":true},{"s":0.6,"x":1.0,"j":true},{"s":1.2,"x":1.0}],"wrongIdeas":[[{"s":0.5,"x":-1.0},{"s":3.5,"x":-1.0},{"s":1.0},{"s":0.6,"x":1.0,"j":true},{"s":0.6,"x":1.0,"j":true},{"s":2.0}],[{"s":0.9,"x":-1.0},{"s":0.3},{"s":0.6,"j":true},{"s":0.6,"j":true},{"s":0.4,"x":-1.0,"c":true},{"s":0.6,"j":true},{"s":2.0}],[{"s":0.5,"x":-1.0},{"s":2.0,"x":-1.0,"c":true},{"s":1.2,"c":true},{"s":0.9,"x":-1.0,"c":true},{"s":1.4,"c":true},{"s":0.5,"x":1.0,"c":true},{"s":0.6,"x":1.0,"j":true},{"s":0.6,"x":1.0,"j":true},{"s":1.5}],[{"s":2.5},{"s":0.7,"x":1.0},{"s":1.2},{"s":0.12,"x":-1.0},{"s":0.55,"x":-1.0,"j":true},{"s":0.1},{"s":0.6,"x":-1.0,"j":true},{"s":1.4,"x":-1.0}],[{"s":0.5,"x":-1.0},{"s":2.9,"x":-1.0,"c":true},{"s":2.0,"c":true},{"s":1.2,"x":-1.0,"c":true},{"s":1.2,"x":1.0,"c":true},{"s":0.1},{"s":0.5,"x":1.0,"j":true},{"s":0.6,"x":1.0,"j":true},{"s":1.2,"x":1.0}]],"goal":[100.0,388.0,180.0,460.0],"blocks":[[-1500.0,620.0,1500.0,2200.0],[-420.0,360.0,-180.0,540.0],[0.0,460.0,220.0,540.0],[190.0,300.0,220.0,460.0]],"lights":[],"markers":[],"plates":[],"toggles":[],"doors":[]}$json$::jsonb, 'pending')
on conflict (id) do update
  set data = excluded.data, status = 'pending', verdict = null,
      checked_by = null;

-- After the gate has run:
-- select id, status, verdict, checked_by from levels where id like 'try-the-gate-%';

-- To remove them:
-- delete from levels where id like 'try-the-gate-%';
