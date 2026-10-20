-- Perwakilan absen per plan (dibutuhkan Step 4).
-- Jalankan di SQL Editor bila belum masuk via CLI.
create table if not exists plan_reps (
  plan_id uuid primary key references plans (id) on delete cascade,
  user_id uuid not null references auth.users (id),
  set_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

alter table plan_reps enable row level security;

drop policy if exists pr_select on plan_reps;
create policy pr_select on plan_reps for select
  using (exists (select 1 from plans where plans.id = plan_id and is_member(workspace_id)));
drop policy if exists pr_write on plan_reps;
create policy pr_write on plan_reps for all
  using (exists (select 1 from plans where plans.id = plan_id
    and my_role(workspace_id) in ('owner', 'admin')))
  with check (exists (select 1 from plans where plans.id = plan_id
    and my_role(workspace_id) in ('owner', 'admin')));
