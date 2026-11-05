-- linhLink Pet House: cơ sở dữ liệu sản phẩm và nhóm sản phẩm trên Supabase
-- Cách dùng: Supabase Dashboard -> SQL Editor -> New query -> dán toàn bộ file này -> Run.
--
-- File này dùng được cho CẢ cài mới LẪN cài đặt cũ (đã có bảng products):
--   * Chạy lại nhiều lần vẫn an toàn.
--   * Dữ liệu sản phẩm đang có được giữ nguyên, nhóm cũ (pet, home, a, b, c...) được chuyển sang bảng categories.
--   * Quyền quản trị đã đặt trước đó KHÔNG bị ghi đè khi chạy lại.
--
-- CÀI MỚI: đổi EMAIL_QUAN_TRI@example.com ở mục 1 thành email bạn đăng nhập quản trị.
-- CÀI ĐẶT CŨ: không cần sửa gì, email quản trị hiện tại được giữ nguyên.
-- (Muốn đổi email quản trị về sau, chạy riêng lệnh "create or replace function public.is_admin() ..." trong SQL Editor.)

-- 1. Ai là quản trị viên (chỉ tạo khi chưa có) --------------------------------
do $do$
begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'is_admin'
  ) then
    execute $fn$
      create function public.is_admin()
      returns boolean
      language sql
      stable
      set search_path = ''
      as $body$
        select lower(coalesce(auth.jwt() ->> 'email', '')) = lower('linhlink0708@gmail.com')
      $body$
    $fn$;
  end if;
end
$do$;

-- 2. Bảng nhóm sản phẩm (sửa trực tiếp trong Table Editor) -----------------------
create table if not exists public.categories (
  id          bigint generated always as identity primary key,
  name        text    not null unique check (char_length(name) between 1 and 60),
  description text    check (description is null or char_length(description) <= 160),
  tone        text    not null default 'yellow' check (tone in ('yellow', 'pink', 'sky', 'mint')),
  icon        text    not null default 'paw' check (icon in ('paw', 'fountain', 'bed', 'scratch', 'collar', 'blender', 'lamp', 'purifier', 'bottle')),
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

insert into public.categories (name, description, tone, icon, sort_order)
select * from (values
  ('Đồ thú cưng', 'Ổ nằm, bình nước, cây cào móng và đồ đi dạo cho chó mèo.', 'pink', 'paw',  10),
  ('Đồ gia dụng', 'Máy xay, đèn ngủ, lọc không khí và đồ dùng gọn gàng cho căn hộ.', 'sky', 'lamp', 20)
) as v(name, description, tone, icon, sort_order)
where not exists (select 1 from public.categories);

-- 3. Bảng sản phẩm --------------------------------------------------------------
create table if not exists public.products (
  id          bigint generated always as identity primary key,
  name        text    not null check (char_length(name) between 1 and 120),
  category_id bigint  not null references public.categories (id) on delete restrict,
  price       integer not null check (price >= 0),
  image_url   text    check (image_url  is null or image_url  ~ '^https://'),
  shopee_url  text    check (shopee_url is null or shopee_url ~ '^https://'),
  tone        text    not null default 'yellow' check (tone in ('yellow', 'pink', 'sky', 'mint')),
  icon        text    not null default 'paw' check (icon in ('paw', 'fountain', 'bed', 'scratch', 'collar', 'blender', 'lamp', 'purifier', 'bottle')),
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- 4. Chuyển dữ liệu từ cột category cũ (nếu có) sang bảng categories ---------------
do $do$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'products' and column_name = 'category'
  ) then
    alter table public.products add column if not exists category_id bigint references public.categories (id) on delete restrict;

    -- Nhóm cũ nào chưa có tên tương ứng thì tạo mới, giữ nguyên chữ cũ làm tên nhóm
    insert into public.categories (name, sort_order)
    select distinct
      case p.category when 'pet' then 'Đồ thú cưng' when 'home' then 'Đồ gia dụng' else p.category end,
      100
    from public.products p
    on conflict (name) do nothing;

    update public.products p
       set category_id = c.id
      from public.categories c
     where p.category_id is null
       and c.name = case p.category when 'pet' then 'Đồ thú cưng' when 'home' then 'Đồ gia dụng' else p.category end;

    alter table public.products drop column category;
    alter table public.products alter column category_id set not null;
  end if;
end
$do$;

create index if not exists products_category_id_idx on public.products (category_id);

-- 5. Quyền truy cập (Row Level Security) ------------------------------------------
alter table public.categories enable row level security;
alter table public.products   enable row level security;

grant select on public.categories, public.products to anon;
grant select, insert, update, delete on public.categories, public.products to authenticated;
grant usage, select on sequence public.categories_id_seq, public.products_id_seq to authenticated;

-- Khách chỉ xem được nhóm và sản phẩm đang hiện
drop policy if exists categories_public_read on public.categories;
create policy categories_public_read on public.categories
  for select to anon, authenticated using (is_active = true);

drop policy if exists products_public_read on public.products;
create policy products_public_read on public.products
  for select to anon, authenticated using (is_active = true);

-- Quản trị viên xem và sửa tất cả
drop policy if exists categories_admin_read on public.categories;
create policy categories_admin_read on public.categories
  for select to authenticated using (public.is_admin());
drop policy if exists categories_admin_insert on public.categories;
create policy categories_admin_insert on public.categories
  for insert to authenticated with check (public.is_admin());
drop policy if exists categories_admin_update on public.categories;
create policy categories_admin_update on public.categories
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists categories_admin_delete on public.categories;
create policy categories_admin_delete on public.categories
  for delete to authenticated using (public.is_admin());

drop policy if exists products_admin_read on public.products;
create policy products_admin_read on public.products
  for select to authenticated using (public.is_admin());
drop policy if exists products_admin_insert on public.products;
create policy products_admin_insert on public.products
  for insert to authenticated with check (public.is_admin());
drop policy if exists products_admin_update on public.products;
create policy products_admin_update on public.products
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists products_admin_delete on public.products;
create policy products_admin_delete on public.products
  for delete to authenticated using (public.is_admin());

-- 6. Kho ảnh (Storage): ai cũng xem được ảnh, chỉ quản trị viên được tải lên ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists product_images_admin_read on storage.objects;
create policy product_images_admin_read on storage.objects
  for select to authenticated using (bucket_id = 'product-images' and public.is_admin());
drop policy if exists product_images_admin_insert on storage.objects;
create policy product_images_admin_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'product-images' and public.is_admin());
drop policy if exists product_images_admin_update on storage.objects;
create policy product_images_admin_update on storage.objects
  for update to authenticated using (bucket_id = 'product-images' and public.is_admin())
  with check (bucket_id = 'product-images' and public.is_admin());
drop policy if exists product_images_admin_delete on storage.objects;
create policy product_images_admin_delete on storage.objects
  for delete to authenticated using (bucket_id = 'product-images' and public.is_admin());

-- 7. Sản phẩm mẫu (chỉ thêm khi bảng còn trống; xóa hoặc sửa tùy ý sau) ----------------
insert into public.products (name, category_id, price, tone, icon, sort_order)
select v.name, c.id, v.price, v.tone, v.icon, v.sort_order
from (values
  ('Máy lọc nước tự động cho mèo',   'Đồ thú cưng', 590000,  'pink',   'fountain', 10),
  ('Giường nằm memory foam cao cấp', 'Đồ thú cưng', 690000,  'yellow', 'bed',      20),
  ('Cây cào móng kiêm tổ ấm',        'Đồ thú cưng', 890000,  'mint',   'scratch',  30),
  ('Bộ yếm và dây dắt đi dạo',       'Đồ thú cưng', 390000,  'sky',    'collar',   40),
  ('Máy xay mini không dây',         'Đồ gia dụng', 790000,  'sky',    'blender',  50),
  ('Đèn ngủ cảm ứng đổi màu',        'Đồ gia dụng', 450000,  'yellow', 'lamp',     60),
  ('Máy lọc không khí mini',         'Đồ gia dụng', 1290000, 'mint',   'purifier', 70),
  ('Bình giữ nhiệt 500 ml',          'Đồ gia dụng', 420000,  'pink',   'bottle',   80)
) as v(name, cat, price, tone, icon, sort_order)
join public.categories c on c.name = v.cat
where not exists (select 1 from public.products);
