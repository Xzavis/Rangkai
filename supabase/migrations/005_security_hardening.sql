-- 005: hardening keamanan (invite, storage, fungsi helper).
-- Jalankan di SQL Editor SETELAH 004. Idempotent: aman di-run ulang,
-- termasuk setelah percobaan sebelumnya error di tengah (sebagian
-- statement mungkin sudah terlanjur teraplikasi).
-- Bila masih error, jalankan per BAGIAN (1 s/d 4) lalu laporkan nomor
-- bagian + teks error persisnya.

-- ================= BAGIAN 1: invite kedaluwarsa =================
alter table invites
  add column if not exists expires_at timestamptz not null
    default (now() + interval '7 days');

-- ================= BAGIAN 2: policy invites =================
-- 001 memberi semua member akses penuh ke invites (termasuk hapus kode
-- orang lain). Persempit: lihat untuk member, kelola hanya owner/admin.
drop policy if exists i_all on invites;
drop policy if exists i_select on invites;
create policy i_select on invites for select using (is_member(workspace_id));
drop policy if exists i_manage on invites;
create policy i_manage on invites for all
  using (my_role(workspace_id) in ('owner', 'admin'))
  with check (my_role(workspace_id) in ('owner', 'admin')
              and auth.uid() = created_by);

-- join_with_code menolak kode kedaluwarsa (pesan tetap generik).
create or replace function join_with_code(invite_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare wid uuid;
begin
  if auth.uid() is null then
    raise exception 'Harus masuk dulu';
  end if;
  select workspace_id into wid from invites
  where code = upper(trim(invite_code)) and expires_at > now();
  if wid is null then raise exception 'Kode tidak dikenal'; end if;
  insert into memberships (workspace_id, user_id, role)
  values (wid, auth.uid(), 'member')
  on conflict do nothing;
  return wid;
end $$;
revoke execute on function join_with_code(text) from public, anon;
grant execute on function join_with_code(text) to authenticated;

-- ================= BAGIAN 3: fungsi helper anti-anon =================
-- my_role/is_member dipakai policy RLS; membiarkannya terbuka untuk anon
-- membocorkan eksistensi keanggotaan lewat RPC.
revoke execute on function my_role(uuid) from public, anon;
revoke execute on function is_member(uuid) from public, anon;
grant execute on function my_role(uuid) to authenticated;
grant execute on function is_member(uuid) to authenticated;

-- ================= BAGIAN 4: storage absensi =================
-- 003 mengizinkan user login mana pun meng-update/menghapus foto siapa
-- pun. Batasi update/delete ke pemilik objek; insert tetap authenticated.
-- Nama kolom pemilik beda antar versi Storage (owner uuid lama vs
-- owner_id text baru), jadi policy dibangun dinamis sesuai yang ada.
do $$
declare owner_expr text;
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'storage' and table_name = 'objects'
      and column_name = 'owner_id'
  ) then
    owner_expr := 'owner_id = auth.uid()::text';
  elsif exists (
    select 1 from information_schema.columns
    where table_schema = 'storage' and table_name = 'objects'
      and column_name = 'owner'
  ) then
    owner_expr := 'owner = auth.uid()';
  else
    raise notice 'Kolom pemilik storage.objects tidak ditemukan; policy dilewati.';
    return;
  end if;

  execute 'drop policy if exists abs_upsert on storage.objects';
  execute format(
    'create policy abs_upsert on storage.objects for update '
    'using (bucket_id = ''absensi'' and %s) '
    'with check (bucket_id = ''absensi'' and %s)',
    owner_expr, owner_expr
  );
  execute 'drop policy if exists abs_delete on storage.objects';
  execute format(
    'create policy abs_delete on storage.objects for delete '
    'using (bucket_id = ''absensi'' and %s)',
    owner_expr
  );
end $$;

-- Ukuran & tipe file foto dibatasi di bucket (maks 5 MB, gambar saja).
-- Dilewati diam-diam bila kolomnya tidak ada di versi Storage ini.
do $$ begin
  update storage.buckets
  set file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
  where id = 'absensi';
exception when undefined_column then
  raise notice 'Kolom limit bucket tidak tersedia; dilewati.';
end $$;
