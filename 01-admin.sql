-- PHẦN 1/2: QUẢN TRỊ VIÊN (ai được phép đăng nhập quản lý)
-- Cách dùng: Supabase Dashboard -> SQL Editor -> New query -> dán toàn bộ file này -> Run.
-- Chạy file này TRƯỚC, sau đó chạy 02-products.sql.
--
-- Danh sách quản trị viên nằm trong bảng "admins". Bạn thêm, xóa email quản trị
-- trực tiếp trong Table Editor, không cần sửa code hay chạy lại file này.
--
-- Hai bước còn lại bạn tự làm trên giao diện Supabase:
--   1. Authentication -> Users -> Add user: tạo tài khoản với đúng email quản trị, tích Auto Confirm User.
--   2. Authentication -> tắt cho phép người dùng tự đăng ký (Allow new users to sign up).
--
-- CÀI MỚI: đổi EMAIL_QUAN_TRI@example.com ở mục 3 thành email của bạn (hoặc sửa sau trong bảng admins).
-- CÀI ĐẶT CŨ: email quản trị đang dùng được tự động chuyển sang bảng admins, không cần sửa gì.
-- File chạy lại nhiều lần vẫn an toàn.

-- 1. Bảng danh sách quản trị viên ---------------------------------------------------
create table if not exists public.admins (
  email      text primary key check (char_length(email) between 3 and 254),
  note       text,
  created_at timestamptz not null default now()
);

-- Bảng này chỉ sửa được trong Dashboard. Khách và trang web không đọc, không ghi được.
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

-- 2. Chuyển email quản trị từ cài đặt cũ (nếu có) -------------------------------------
do $do$
declare
  old_def   text;
  old_email text;
begin
  if to_regprocedure('public.is_admin()') is not null then
    select pg_get_functiondef(to_regprocedure('public.is_admin()')) into old_def;
    old_email := substring(old_def from 'lower\(''([^'']+)''\)');
    if old_email is not null and lower(old_email) <> 'email_quan_tri@example.com' then
      insert into public.admins (email, note)
      values (lower(old_email), 'Chuyển từ cài đặt cũ')
      on conflict (email) do nothing;
    end if;
  end if;
end
$do$;

-- 3. Cài mới: thêm email quản trị đầu tiên (chỉ khi bảng còn trống) ------------------------
insert into public.admins (email, note)
select 'email_quan_tri@example.com', 'ĐỔI thành email thật của bạn (Table Editor, bảng admins)'
where not exists (select 1 from public.admins);

-- 4. Hàm kiểm tra "người đang đăng nhập có phải quản trị viên không" ---------------------
-- Các quy tắc quyền trong 02-products.sql và trang web đều gọi hàm này.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admins a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;
