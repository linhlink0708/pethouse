-- linhLink Pet House: cơ sở dữ liệu sản phẩm trên Supabase
-- Cách dùng: Supabase Dashboard -> SQL Editor -> New query -> dán toàn bộ file này -> Run.
--
-- BẮT BUỘC: đổi EMAIL_QUAN_TRI@example.com (dòng có chữ is_admin bên dưới) thành
-- email bạn dùng để đăng nhập quản trị. Chỉ tài khoản có đúng email này mới được
-- thêm, sửa, xóa sản phẩm và tải ảnh lên. Khách truy cập chỉ được xem sản phẩm đang bán.
-- File chạy lại nhiều lần vẫn an toàn.

-- 1. Bảng sản phẩm ------------------------------------------------------------
create table if not exists public.products (
  id          bigint generated always as identity primary key,
  name        text    not null check (char_length(name) between 1 and 120),
  category    text    not null check (category in ('pet', 'home')),
  price       integer not null check (price >= 0),
  image_url   text    check (image_url  is null or image_url  ~ '^https://'),
  shopee_url  text    check (shopee_url is null or shopee_url ~ '^https://'),
  tone        text    not null default 'yellow' check (tone in ('yellow', 'pink', 'sky', 'mint')),
  icon        text    not null default 'paw' check (icon in ('paw', 'fountain', 'bed', 'scratch', 'collar', 'blender', 'lamp', 'purifier', 'bottle')),
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- 2. Ai là quản trị viên ------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
set search_path = ''
as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) = lower('linhlink0708@gmail.com')
$$;

-- 3. Quyền truy cập bảng (Row Level Security) ---------------------------------
alter table public.products enable row level security;

grant select on public.products to anon;
grant select, insert, update, delete on public.products to authenticated;
grant usage, select on sequence public.products_id_seq to authenticated;

drop policy if exists products_public_read on public.products;
create policy products_public_read on public.products
  for select to anon, authenticated
  using (is_active = true);

drop policy if exists products_admin_read on public.products;
create policy products_admin_read on public.products
  for select to authenticated
  using (public.is_admin());

drop policy if exists products_admin_insert on public.products;
create policy products_admin_insert on public.products
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists products_admin_update on public.products;
create policy products_admin_update on public.products
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists products_admin_delete on public.products;
create policy products_admin_delete on public.products
  for delete to authenticated
  using (public.is_admin());

-- 4. Kho ảnh (Storage): ai cũng xem được ảnh, chỉ quản trị viên được tải lên ----
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists product_images_admin_read on storage.objects;
create policy product_images_admin_read on storage.objects
  for select to authenticated
  using (bucket_id = 'product-images' and public.is_admin());

drop policy if exists product_images_admin_insert on storage.objects;
create policy product_images_admin_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'product-images' and public.is_admin());

drop policy if exists product_images_admin_update on storage.objects;
create policy product_images_admin_update on storage.objects
  for update to authenticated
  using (bucket_id = 'product-images' and public.is_admin())
  with check (bucket_id = 'product-images' and public.is_admin());

drop policy if exists product_images_admin_delete on storage.objects;
create policy product_images_admin_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'product-images' and public.is_admin());

-- 5. Sản phẩm mẫu (chỉ thêm khi bảng còn trống; xóa hoặc sửa tùy ý sau) ---------
insert into public.products (name, category, price, tone, icon, sort_order)
select * from (values
  ('Máy lọc nước tự động cho mèo',   'pet',  590000,  'pink',   'fountain', 10),
  ('Giường nằm memory foam cao cấp', 'pet',  690000,  'yellow', 'bed',      20),
  ('Cây cào móng kiêm tổ ấm',        'pet',  890000,  'mint',   'scratch',  30),
  ('Bộ yếm và dây dắt đi dạo',       'pet',  390000,  'sky',    'collar',   40),
  ('Máy xay mini không dây',         'home', 790000,  'sky',    'blender',  50),
  ('Đèn ngủ cảm ứng đổi màu',        'home', 450000,  'yellow', 'lamp',     60),
  ('Máy lọc không khí mini',         'home', 1290000, 'mint',   'purifier', 70),
  ('Bình giữ nhiệt 500 ml',          'home', 420000,  'pink',   'bottle',   80)
) as v(name, category, price, tone, icon, sort_order)
where not exists (select 1 from public.products);
