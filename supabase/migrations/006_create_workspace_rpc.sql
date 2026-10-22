-- 006: buat workspace lewat RPC security definer.
-- 001 punya chicken-and-egg: ws_select (is_member) memblokir RETURNING
-- hasil insert workspace, dan m_insert mensyaratkan role owner/admin
-- yang belum ada. Akibatnya buat komunitas dari aplikasi selalu 42501.
-- Pola sama seperti join_with_code/handle_new_user: satu fungsi atomik
-- menyisipkan workspace + membership owner.

create or replace function create_workspace(ws_name text, ws_type text default 'community')
returns uuid language plpgsql security definer set search_path = public as $$
declare
  wid uuid;
  clean text;
begin
  if auth.uid() is null then
    raise exception 'Harus masuk dulu';
  end if;
  clean := regexp_replace(trim(ws_name), '\s+', ' ', 'g');
  if char_length(clean) < 1 or char_length(clean) > 80 then
    raise exception 'Nama workspace harus 1-80 karakter';
  end if;
  if ws_type not in ('personal', 'community') then
    raise exception 'Tipe workspace tidak dikenal';
  end if;
  insert into workspaces (name, type, created_by)
  values (clean, ws_type, auth.uid())
  returning id into wid;
  insert into memberships (workspace_id, user_id, role)
  values (wid, auth.uid(), 'owner');
  return wid;
end $$;

revoke execute on function create_workspace(text, text) from public, anon;
grant execute on function create_workspace(text, text) to authenticated;
