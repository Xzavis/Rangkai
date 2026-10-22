-- 004: kategori/catatan transaksi + rentang tanggal rencana (UI v4).
-- Additive & aman di-run ulang. Baris lama tetap valid lewat DEFAULT.
-- Jalankan di Supabase Dashboard -> SQL Editor SETELAH 001-003.
-- Aplikasi tetap bisa tulis sebelum migrasi ini jalan (fallback tanpa
-- kolom baru di CloudSync), tapi kategori/catatan/end_date baru
-- tersinkron penuh setelah file ini diterapkan.

alter table transactions
  add column if not exists category text not null default 'Umum'
    check (char_length(category) between 1 and 40),
  add column if not exists note text not null default ''
    check (char_length(note) <= 500);

alter table plans
  add column if not exists end_date date;

-- end_date tidak boleh mendahului date (bila keduanya terisi).
do $$ begin
  alter table plans add constraint plans_end_after_start
    check (end_date is null or date is null or end_date >= date);
exception when duplicate_object then null;
end $$;

-- Batas waras server-side (klien juga memvalidasi; server yang pegang kunci).
do $$ begin
  alter table transactions add constraint transactions_title_len
    check (char_length(title) between 1 and 120);
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table transactions add constraint transactions_amount_sane
    check (amount <> 0 and abs(amount) <= 999000000000);
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table plans add constraint plans_title_len
    check (char_length(title) between 1 and 120);
exception when duplicate_object then null;
end $$;

do $$ begin
  alter table plans add constraint plans_budget_sane
    check (budget >= 0 and budget <= 999000000000);
exception when duplicate_object then null;
end $$;

create index if not exists transactions_workspace_date_idx
  on transactions (workspace_id, date desc);
