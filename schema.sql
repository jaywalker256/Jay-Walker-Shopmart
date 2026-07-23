-- ============================================================================
-- Jay Walker Shopmart — database setup
-- Run this ONCE in Supabase: Dashboard → SQL Editor → New query → paste all
-- of this → Run. It creates the products table, the admin allowlist, and the
-- security rules that let anyone READ products but only approved admins
-- WRITE (add/edit/delete) them.
-- ============================================================================

-- ---------- 1. Products table ----------
create table if not exists products (
  id text primary key,
  name text not null,
  category text not null,
  ship_units integer not null default 1,
  price numeric not null,
  edition_made integer not null default 0,
  edition_total integer not null default 0,
  description text not null default '',
  accent text,
  images jsonb default '[]'::jsonb,     -- [{ "src": "https://..." }, ...]
  sizes jsonb,                          -- ["S","M","L","XL"] or null
  size_stock jsonb,                     -- { "S": 6, "M": 0, ... } or null
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------- 2. Admin allowlist ----------
-- Only emails listed here (and only after they've also logged in through
-- Supabase Auth — see the invite step in the setup guide) can edit products.
create table if not exists admins (
  email text primary key,
  is_owner boolean not null default false,
  added_at timestamptz not null default now()
);

-- ---------- 3. Helper functions (security definer = these can check the
-- admins table even though RLS below restricts normal access to it) ----------
create or replace function is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from admins where email = auth.jwt() ->> 'email'
  );
$$;

create or replace function is_owner_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from admins where email = auth.jwt() ->> 'email' and is_owner = true
  );
$$;

-- ---------- 4. Row Level Security ----------
alter table products enable row level security;
alter table admins enable row level security;

-- Anyone (including logged-out shoppers) can read products — this is what
-- powers the public storefront.
drop policy if exists "Public can read products" on products;
create policy "Public can read products" on products
  for select using (true);

-- Only admins can add, edit, or delete products.
drop policy if exists "Admins can insert products" on products;
create policy "Admins can insert products" on products
  for insert with check (is_admin());

drop policy if exists "Admins can update products" on products;
create policy "Admins can update products" on products
  for update using (is_admin());

drop policy if exists "Admins can delete products" on products;
create policy "Admins can delete products" on products
  for delete using (is_admin());

-- Admins can see who the other admins are.
drop policy if exists "Admins can read admin list" on admins;
create policy "Admins can read admin list" on admins
  for select using (is_admin());

-- Only the owner can add or remove admins — regular admins can edit products
-- but can't grant themselves or anyone else more access.
drop policy if exists "Owner can add admins" on admins;
create policy "Owner can add admins" on admins
  for insert with check (is_owner_admin());

drop policy if exists "Owner can remove admins" on admins;
create policy "Owner can remove admins" on admins
  for delete using (is_owner_admin() and is_owner = false);

-- ---------- 5. Keep updated_at current automatically ----------
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists products_set_updated_at on products;
create trigger products_set_updated_at
  before update on products
  for each row execute function set_updated_at();

-- ---------- 6. Seed with your current 13 products ----------
-- (Safe to re-run: skips any id that already exists.)
insert into products (id, name, category, ship_units, price, edition_made, edition_total, description, accent, images, sizes, size_stock)
values
(
    'p1', 'Heavyweight Cotton Tee', 'Shirts', 1,
    65000, 18, 80, '240gsm combed cotton, boxy fit, garment-dyed for a slightly worn-in look from day one. Holds its shape wash after wash.',
    '#ff5a3c', '[{"src": "https://placehold.co/800x800/ff5a3c/ffffff?text=Heavyweight+Cotton+Tee%0AFront"}, {"src": "https://placehold.co/800x800/ff5a3c/ffffff?text=Heavyweight+Cotton+Tee%0ABack"}, {"src": "https://placehold.co/800x800/ff5a3c/ffffff?text=Heavyweight+Cotton+Tee%0ADetail"}]'::jsonb, '["S", "M", "L", "XL"]'::jsonb, '{"S": 6, "M": 0, "L": 7, "XL": 5}'::jsonb
  ),
(
    'p2', 'Straight-Leg Selvedge Denim', 'Denim', 2,
    210000, 9, 40, '14oz raw selvedge denim, straight cut through the leg with a slightly higher rise. Breaks in and fades with wear.',
    '#0ea5e9', '[{"src": "https://placehold.co/800x800/0ea5e9/ffffff?text=Straight-Leg+Selvedge+Denim%0AFront"}, {"src": "https://placehold.co/800x800/0ea5e9/ffffff?text=Straight-Leg+Selvedge+Denim%0ABack"}, {"src": "https://placehold.co/800x800/0ea5e9/ffffff?text=Straight-Leg+Selvedge+Denim%0ADetail"}]'::jsonb, '["28", "30", "32", "34", "36"]'::jsonb, NULL
  ),
(
    'p3', 'Waxed Field Jacket', 'Outerwear', 3,
    330000, 6, 30, 'Waxed cotton shell with a wool-blend lining, four-pocket utility front, and a corduroy collar. Built for rain and cold mornings.',
    '#7c3aed', '[{"src": "https://placehold.co/800x800/7c3aed/ffffff?text=Waxed+Field+Jacket%0AFront"}, {"src": "https://placehold.co/800x800/7c3aed/ffffff?text=Waxed+Field+Jacket%0ABack"}, {"src": "https://placehold.co/800x800/7c3aed/ffffff?text=Waxed+Field+Jacket%0ADetail"}]'::jsonb, '["S", "M", "L", "XL"]'::jsonb, NULL
  ),
(
    'p4', 'Wrap Midi Dress', 'Dresses', 1,
    145000, 22, 70, 'Soft drape viscose in a wrap silhouette with an adjustable tie waist. Cut to move — dresses down for day, up for evening.',
    '#ec4899', '[{"src": "https://placehold.co/800x800/ec4899/ffffff?text=Wrap+Midi+Dress%0AFront"}, {"src": "https://placehold.co/800x800/ec4899/ffffff?text=Wrap+Midi+Dress%0ABack"}, {"src": "https://placehold.co/800x800/ec4899/ffffff?text=Wrap+Midi+Dress%0ADetail"}]'::jsonb, '["XS", "S", "M", "L"]'::jsonb, NULL
  ),
(
    'p5', 'Merino Crew Sweater', 'Shirts', 1,
    175000, 27, 90, 'Fine-gauge merino wool, breathable enough for layering, warm enough on its own. Ribbed cuffs and hem hold their shape.',
    '#eab308', '[{"src": "https://placehold.co/800x800/eab308/ffffff?text=Merino+Crew+Sweater%0AFront"}, {"src": "https://placehold.co/800x800/eab308/ffffff?text=Merino+Crew+Sweater%0ABack"}, {"src": "https://placehold.co/800x800/eab308/ffffff?text=Merino+Crew+Sweater%0ADetail"}]'::jsonb, '["S", "M", "L", "XL"]'::jsonb, NULL
  ),
(
    'p6', 'Tapered Chino Trousers', 'Denim', 2,
    120000, 29, 80, 'Mid-weight cotton twill, tapered through the leg with a clean front. Works as easily with a tee as with a blazer.',
    '#84cc16', '[{"src": "https://placehold.co/800x800/84cc16/ffffff?text=Tapered+Chino+Trousers%0AFront"}, {"src": "https://placehold.co/800x800/84cc16/ffffff?text=Tapered+Chino+Trousers%0ABack"}, {"src": "https://placehold.co/800x800/84cc16/ffffff?text=Tapered+Chino+Trousers%0ADetail"}]'::jsonb, '["28", "30", "32", "34", "36"]'::jsonb, NULL
  ),
(
    'p7', 'Quilted Vest', 'Outerwear', 3,
    130000, 41, 80, 'Lightweight quilted shell over a recycled-fill lining. An easy layer for cool evenings without the bulk of a full jacket.',
    '#1fa088', '[{"src": "https://placehold.co/800x800/1fa088/ffffff?text=Quilted+Vest%0AFront"}, {"src": "https://placehold.co/800x800/1fa088/ffffff?text=Quilted+Vest%0ABack"}, {"src": "https://placehold.co/800x800/1fa088/ffffff?text=Quilted+Vest%0ADetail"}]'::jsonb, '["S", "M", "L", "XL"]'::jsonb, NULL
  ),
(
    'p8', 'Hand-Loomed Cotton Wrap Scarf', 'Accessories', 1,
    85000, 51, 120, 'Woven on a manual loom in small runs, finished with a hand-rolled edge. Soft, breathable cotton in a colorway that shifts slightly with each dye lot.',
    '#22c55e', '[{"src": "https://placehold.co/800x800/22c55e/ffffff?text=Hand-Loomed+Cotton+Wrap+Scarf%0AFront"}, {"src": "https://placehold.co/800x800/22c55e/ffffff?text=Hand-Loomed+Cotton+Wrap+Scarf%0ABack"}, {"src": "https://placehold.co/800x800/22c55e/ffffff?text=Hand-Loomed+Cotton+Wrap+Scarf%0ADetail"}]'::jsonb, NULL, NULL
  ),
(
    'p9', 'Canvas Weekender Bag', 'Accessories', 1,
    210000, 18, 50, 'Heavy waxed canvas body with leather straps and a brass zip. Fits an overnight''s worth of clothes without looking like a gym bag.',
    '#06b6d4', '[{"src": "https://placehold.co/800x800/06b6d4/ffffff?text=Canvas+Weekender+Bag%0AFront"}, {"src": "https://placehold.co/800x800/06b6d4/ffffff?text=Canvas+Weekender+Bag%0ABack"}, {"src": "https://placehold.co/800x800/06b6d4/ffffff?text=Canvas+Weekender+Bag%0ADetail"}]'::jsonb, NULL, NULL
  ),
(
    'p10', 'Leather Chelsea Boots', 'Footwear', 2,
    275000, 27, 90, 'Full-grain leather uppers on a stacked leather heel, elastic side panels for an easy on-off. Resoleable, built to last years.',
    '#a8763e', '[{"src": "https://placehold.co/800x800/a8763e/ffffff?text=Leather+Chelsea+Boots%0AFront"}, {"src": "https://placehold.co/800x800/a8763e/ffffff?text=Leather+Chelsea+Boots%0ABack"}, {"src": "https://placehold.co/800x800/a8763e/ffffff?text=Leather+Chelsea+Boots%0ADetail"}]'::jsonb, '["39", "40", "41", "42", "43", "44"]'::jsonb, NULL
  ),
(
    'p11', 'Linen Button-Down Shirt', 'Shirts', 1,
    98000, 37, 100, 'Lightweight European linen, relaxed fit, mother-of-pearl buttons. Breathable enough for hot afternoons, sharp enough for the office.',
    '#f97316', '[{"src": "https://placehold.co/800x800/f97316/ffffff?text=Linen+Button-Down+Shirt%0AFront"}, {"src": "https://placehold.co/800x800/f97316/ffffff?text=Linen+Button-Down+Shirt%0ABack"}, {"src": "https://placehold.co/800x800/f97316/ffffff?text=Linen+Button-Down+Shirt%0ADetail"}]'::jsonb, '["S", "M", "L", "XL"]'::jsonb, NULL
  ),
(
    'p12', 'Minimalist Leather Belt', 'Accessories', 1,
    65000, 60, 150, 'A single strip of vegetable-tanned leather with a solid brass buckle, hand-burnished at the edges. Darkens nicely with age.',
    '#a855f7', '[{"src": "https://placehold.co/800x800/a855f7/ffffff?text=Minimalist+Leather+Belt%0AFront"}, {"src": "https://placehold.co/800x800/a855f7/ffffff?text=Minimalist+Leather+Belt%0ABack"}, {"src": "https://placehold.co/800x800/a855f7/ffffff?text=Minimalist+Leather+Belt%0ADetail"}]'::jsonb, '["S", "M", "L"]'::jsonb, NULL
  ),
(
    'p13', 'Canvas Low-Top Sneakers', 'Footwear', 2,
    120000, 29, 80, 'Durable cotton canvas uppers on a cushioned rubber sole. An everyday sneaker that pairs with almost anything in the closet.',
    '#5b6470', '[{"src": "https://placehold.co/800x800/5b6470/ffffff?text=Canvas+Low-Top+Sneakers%0AFront"}, {"src": "https://placehold.co/800x800/5b6470/ffffff?text=Canvas+Low-Top+Sneakers%0ABack"}, {"src": "https://placehold.co/800x800/5b6470/ffffff?text=Canvas+Low-Top+Sneakers%0ADetail"}]'::jsonb, '["38", "39", "40", "41", "42", "43", "44"]'::jsonb, NULL
  )
on conflict (id) do nothing;

-- ---------- 7. Make YOURSELF the first admin/owner ----------
-- IMPORTANT: replace the email below with your own login email, then run
-- this statement (you can re-run just this part any time — it's idempotent).
-- This only adds you to the allowlist — you still need to create your actual
-- login (Supabase Dashboard → Authentication → Users → Add user, or invite
-- yourself) with this exact email. See ADMIN_SETUP.md for the full sequence.
insert into admins (email, is_owner)
values ('YOUR-EMAIL@example.com', true)
on conflict (email) do update set is_owner = true;
