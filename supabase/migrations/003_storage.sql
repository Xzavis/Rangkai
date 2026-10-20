-- Bucket foto absen di Supabase Storage (gantikan R2).
-- Jalankan di SQL Editor bila belum masuk via CLI.
insert into storage.buckets (id, name, public)
values ('absensi', 'absensi', true)
on conflict (id) do nothing;

-- Baca: anggota workspace mana pun (foto absen memang dibagikan ke tim).
-- Tulis/hapus: user login (kepemilikan baris dicek aplikasi via attendance).
drop policy if exists abs_read on storage.objects;
create policy abs_read on storage.objects for select
  using (bucket_id = 'absensi');
drop policy if exists abs_write on storage.objects;
create policy abs_write on storage.objects for insert
  with check (bucket_id = 'absensi' and auth.role() = 'authenticated');
drop policy if exists abs_upsert on storage.objects;
create policy abs_upsert on storage.objects for update
  using (bucket_id = 'absensi' and auth.role() = 'authenticated');
drop policy if exists abs_delete on storage.objects;
create policy abs_delete on storage.objects for delete
  using (bucket_id = 'absensi' and auth.role() = 'authenticated');
