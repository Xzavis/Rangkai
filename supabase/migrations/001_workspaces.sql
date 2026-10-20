-- CPI workspace + sharing schema (jalankan di Supabase Dashboard -> SQL Editor)
-- Urutan penting: tabel dulu, baru RLS + policy. Aman di-run ulang (IF NOT EXISTS).

-- ---------- Tabel ----------
create table if not exists workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  type text not null default 'community' check (type in ('personal', 'community')),
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create table if not exists memberships (
  workspace_id uuid not null references workspaces (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member')),
  created_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create table if not exists invites (
  code text primary key check (code ~ '^[A-Z0-9]{6}$'),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

-- Rencana & transaksi milik workspace (kolom planId/tx lokal tetap untuk cache).
create table if not exists plans (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  title text not null,
  place text not null default '',
  lat double precision,
  lng double precision,
  budget numeric not null default 0,
  date date,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create table if not exists rundowns (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references plans (id) on delete cascade,
  day date not null,
  time text not null default '09:00' check (time ~ '^[0-9]{2}:[0-9]{2}$'),
  title text not null,
  cost numeric not null default 0,
  done boolean not null default false,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  title text not null,
  amount numeric not null,
  date timestamptz not null default now(),
  plan_id uuid references plans (id) on delete set null,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

-- Absen: checkpoint per plan + 1 bukti per checkpoint.
create table if not exists checkpoints (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references plans (id) on delete cascade,
  name text not null,
  position int not null default 0,
  required boolean not null default true
);

create table if not exists attendance (
  checkpoint_id uuid primary key references checkpoints (id) on delete cascade,
  photo_url text not null,
  lat double precision not null,
  lng double precision not null,
  accuracy double precision,
  headcount int not null check (headcount > 0),
  recorded_by uuid not null references auth.users (id),
  recorded_at timestamptz not null default now()
);

-- ---------- Helper: role saya di workspace ----------
create or replace function my_role(wid uuid)
returns text language sql security definer set search_path = public as $$
  select role from memberships where workspace_id = wid and user_id = auth.uid()
$$;

create or replace function is_member(wid uuid)
returns boolean language sql security definer set search_path = public as $$
  select exists (select 1 from memberships where workspace_id = wid and user_id = auth.uid())
$$;

-- ---------- Gabung via kode (bypass RLS terkontrol) ----------
-- Calon anggota belum bisa baca tabel invites, jadi gabung lewat fungsi ini.
create or replace function join_with_code(invite_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare wid uuid;
begin
  select workspace_id into wid from invites where code = upper(trim(invite_code));
  if wid is null then raise exception 'Kode % tidak dikenal', invite_code; end if;
  insert into memberships (workspace_id, user_id, role)
  values (wid, auth.uid(), 'member')
  on conflict do nothing;
  return wid;
end $$;
grant execute on function join_with_code(text) to authenticated;

-- ---------- Workspace pribadi otomatis untuk user baru ----------
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare wid uuid;
begin
  insert into workspaces (name, type, created_by)
  values ('Pribadi', 'personal', new.id) returning id into wid;
  insert into memberships (workspace_id, user_id, role) values (wid, new.id, 'owner');
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users for each row execute function handle_new_user();

-- ---------- RLS ----------
alter table workspaces enable row level security;
alter table memberships enable row level security;
alter table invites enable row level security;
alter table plans enable row level security;
alter table rundowns enable row level security;
alter table transactions enable row level security;
alter table checkpoints enable row level security;
alter table attendance enable row level security;

-- workspaces: lihat & buat; ubah/hapus hanya owner.
drop policy if exists ws_select on workspaces;
create policy ws_select on workspaces for select using (is_member(id));
drop policy if exists ws_insert on workspaces;
create policy ws_insert on workspaces for insert with check (auth.uid() = created_by);
drop policy if exists ws_update on workspaces;
create policy ws_update on workspaces for update using (my_role(id) = 'owner');
drop policy if exists ws_delete on workspaces;
create policy ws_delete on workspaces for delete using (my_role(id) = 'owner');

-- memberships: member lihat teman satu workspace; tambah/hapus hanya admin+.
drop policy if exists m_select on memberships;
create policy m_select on memberships for select using (is_member(workspace_id));
drop policy if exists m_insert on memberships;
create policy m_insert on memberships for insert
  with check (my_role(workspace_id) in ('owner', 'admin'));
drop policy if exists m_delete on memberships;
create policy m_delete on memberships for delete
  using (my_role(workspace_id) in ('owner', 'admin') and user_id <> auth.uid());
drop policy if exists m_update on memberships;
create policy m_update on memberships for update
  using (my_role(workspace_id) in ('owner', 'admin'));

-- invites: admin+ kelola; member pakai kode untuk gabung (validasi di aplikasi).
drop policy if exists i_all on invites;
create policy i_all on invites for all using (is_member(workspace_id));

-- plans: member baca; buat: member+; ubah/hapus: admin+ (budget dilindungi).
drop policy if exists p_select on plans;
create policy p_select on plans for select using (is_member(workspace_id));
drop policy if exists p_insert on plans;
create policy p_insert on plans for insert
  with check (is_member(workspace_id) and auth.uid() = created_by);
drop policy if exists p_update on plans;
create policy p_update on plans for update
  using (my_role(workspace_id) in ('owner', 'admin'));
drop policy if exists p_delete on plans;
create policy p_delete on plans for delete
  using (my_role(workspace_id) in ('owner', 'admin'));

-- rundowns: semua member kelola (sesuai kontrak: siapapun boleh isi rundown).
drop policy if exists r_select on rundowns;
create policy r_select on rundowns for select
  using (exists (select 1 from plans where plans.id = plan_id and is_member(workspace_id)));
drop policy if exists r_write on rundowns;
create policy r_write on rundowns for all
  using (exists (select 1 from plans where plans.id = plan_id and is_member(workspace_id)))
  with check (exists (select 1 from plans where plans.id = plan_id and is_member(workspace_id)));

-- transactions: semua member kelola.
drop policy if exists t_select on transactions;
create policy t_select on transactions for select using (is_member(workspace_id));
drop policy if exists t_write on transactions;
create policy t_write on transactions for all
  using (is_member(workspace_id))
  with check (is_member(workspace_id) and auth.uid() = created_by);

-- checkpoints: baca member; tulis admin+ (plus perwakilan absen diatur aplikasi).
drop policy if exists c_select on checkpoints;
create policy c_select on checkpoints for select
  using (exists (select 1 from plans where plans.id = plan_id and is_member(workspace_id)));
drop policy if exists c_write on checkpoints;
create policy c_write on checkpoints for all
  using (exists (select 1 from plans where plans.id = plan_id
    and my_role(workspace_id) in ('owner', 'admin')))
  with check (exists (select 1 from plans where plans.id = plan_id
    and my_role(workspace_id) in ('owner', 'admin')));

-- attendance: baca member; tulis member (aplikasi membatasi hanya perwakilan).
drop policy if exists a_select on attendance;
create policy a_select on attendance for select
  using (exists (select 1 from checkpoints
    join plans on plans.id = checkpoints.plan_id
    where checkpoints.id = checkpoint_id and is_member(plans.workspace_id)));
drop policy if exists a_write on attendance;
create policy a_write on attendance for all
  using (exists (select 1 from checkpoints
    join plans on plans.id = checkpoints.plan_id
    where checkpoints.id = checkpoint_id and is_member(plans.workspace_id)))
  with check (auth.uid() = recorded_by);
