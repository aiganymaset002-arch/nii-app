-- =====================================================================
-- NII App — база данных в Supabase
-- Supabase → SQL Editor → New query → вставить весь файл → Run.
-- В конце появится таблица с кодами организатора и команды — сохраните их.
--
-- Все таблицы начинаются с nii_, поэтому файл можно выполнить и в новом,
-- и в уже существующем проекте Supabase. Повторный запуск безопасен.
--
-- Права (RLS) проверяет сама база:
--   участник (user)  — свой профиль, записи, заявки, заказы; опубликованный контент;
--   команда (team)   — свои задачи, сессии онлайн-лаборатории и встречи;
--   организатор (admin) — всё.
-- Роль нельзя выбрать самому: только кодом через nii_claim_role().
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- Секреты (коды ролей, хеш семейного пароля). Доступа из приложения нет. ----------
create table if not exists public.nii_secrets (
    key   text primary key,
    value text not null
);
alter table public.nii_secrets enable row level security;

insert into public.nii_secrets (key, value) values
    ('admin_code', 'ADMIN-' || substr(md5(gen_random_uuid()::text), 1, 8)),
    ('team_code',  'TEAM-'  || substr(md5(gen_random_uuid()::text), 1, 8)),
    -- bcrypt-хеш семейного пароля (сам пароль здесь не хранится)
    ('family_hash', '$2a$12$J2VcUAsWmBzHJPknmMFAkOc1cZoC5R8ooUMjulpn/fhUu.B5yDjJi')
on conflict (key) do nothing;

-- ---------- Профили ----------
create table if not exists public.nii_profiles (
    user_id      uuid primary key references auth.users (id) on delete cascade,
    full_name    text not null default '',
    role         text not null default 'user' check (role in ('admin', 'team', 'user')),
    phone        text not null default '',
    organization text not null default '',
    is_family    boolean not null default false,
    created_at   timestamptz not null default now()
);
alter table public.nii_profiles enable row level security;

create or replace function public.nii_role() returns text
language sql stable security definer set search_path = public as $$
    select role from public.nii_profiles where user_id = auth.uid()
$$;

create or replace function public.nii_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
    select coalesce(public.nii_role() = 'admin', false)
$$;

create or replace function public.nii_is_staff() returns boolean
language sql stable security definer set search_path = public as $$
    select coalesce(public.nii_role() in ('admin', 'team'), false)
$$;

-- Роль и семейный доступ меняются только через функции ниже или организатором
create or replace function public.nii_profile_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
    if current_setting('nii.trusted', true) = 'on' or public.nii_is_admin() then
        return new;
    end if;
    if tg_op = 'INSERT' then
        new.role := 'user';
        new.is_family := false;
    else
        new.role := old.role;
        new.is_family := old.is_family;
    end if;
    return new;
end $$;

drop trigger if exists nii_profile_guard on public.nii_profiles;
create trigger nii_profile_guard before insert or update on public.nii_profiles
for each row execute function public.nii_profile_guard();

drop policy if exists "profiles read" on public.nii_profiles;
create policy "profiles read" on public.nii_profiles for select
    using (user_id = auth.uid() or public.nii_is_staff());
drop policy if exists "profiles create own" on public.nii_profiles;
create policy "profiles create own" on public.nii_profiles for insert
    with check (user_id = auth.uid());
drop policy if exists "profiles update" on public.nii_profiles;
create policy "profiles update" on public.nii_profiles for update
    using (user_id = auth.uid() or public.nii_is_admin());

-- Код организатора / команды → роль
create or replace function public.nii_claim_role(code text) returns text
language plpgsql security definer set search_path = public as $$
declare
    new_role text;
begin
    if auth.uid() is null then raise exception 'Войдите в аккаунт'; end if;
    select case
        when code = (select value from nii_secrets where key = 'admin_code') then 'admin'
        when code = (select value from nii_secrets where key = 'team_code') then 'team'
    end into new_role;
    if new_role is null then
        perform pg_sleep(1);
        raise exception 'Неверный код доступа';
    end if;
    perform set_config('nii.trusted', 'on', true);
    update nii_profiles set role = new_role where user_id = auth.uid();
    return new_role;
end $$;

-- Семейный пароль → бесплатный Pro
create or replace function public.nii_activate_family(code text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
declare
    stored text := (select value from nii_secrets where key = 'family_hash');
begin
    if auth.uid() is null then raise exception 'Войдите в аккаунт'; end if;
    if crypt(code, stored) <> stored then
        perform pg_sleep(1);
        raise exception 'Неверный семейный пароль';
    end if;
    perform set_config('nii.trusted', 'on', true);
    update nii_profiles set is_family = true where user_id = auth.uid();
    return true;
end $$;

revoke all on function public.nii_claim_role(text) from anon;
revoke all on function public.nii_activate_family(text) from anon;

-- ---------- Задачи и план «90 дней» ----------
create table if not exists public.nii_tasks (
    id          bigint generated always as identity primary key,
    title       text not null,
    description text not null default '',
    due_date    date,
    week        int,                       -- 0 = Точка А, 1–12 = недели плана
    priority    text not null default 'normal' check (priority in ('low', 'normal', 'high')),
    status      text not null default 'todo' check (status in ('todo', 'done')),
    assignee    uuid references auth.users (id) on delete set null,
    created_by  uuid references auth.users (id) on delete set null default auth.uid(),
    done_at     timestamptz,
    created_at  timestamptz not null default now()
);
alter table public.nii_tasks enable row level security;

drop policy if exists "tasks read" on public.nii_tasks;
create policy "tasks read" on public.nii_tasks for select
    using (public.nii_is_admin() or (public.nii_is_staff() and (assignee = auth.uid() or created_by = auth.uid())));
drop policy if exists "tasks create" on public.nii_tasks;
create policy "tasks create" on public.nii_tasks for insert
    with check (public.nii_is_admin() or (public.nii_is_staff() and assignee = auth.uid()));
drop policy if exists "tasks update" on public.nii_tasks;
create policy "tasks update" on public.nii_tasks for update
    using (public.nii_is_admin() or (public.nii_is_staff() and assignee = auth.uid()));
drop policy if exists "tasks delete" on public.nii_tasks;
create policy "tasks delete" on public.nii_tasks for delete using (public.nii_is_admin());

create table if not exists public.nii_kpis (
    id      int primary key,
    title   text not null,
    current int not null default 0,
    goal    int not null default 1
);
alter table public.nii_kpis enable row level security;
insert into public.nii_kpis (id, title, goal) values
    (1, 'Флагманских исследований', 10),
    (2, 'Прототипов / демонстраций', 10),
    (3, 'Участников первой конференции', 200),
    (4, 'Международных партнёров', 10),
    (5, 'Новых патентных заявок', 5),
    (6, 'Грантов и корпоративных пилотов', 3),
    (7, 'Conference & Research Center и Demo Hall (этапов)', 3),
    (8, 'Шагов международного позиционирования', 5)
on conflict (id) do nothing;
drop policy if exists "kpis read" on public.nii_kpis;
create policy "kpis read" on public.nii_kpis for select using (public.nii_is_staff());
drop policy if exists "kpis update" on public.nii_kpis;
create policy "kpis update" on public.nii_kpis for update using (public.nii_is_admin());

-- ---------- Мероприятия: конференции, семинары, онлайн-лаборатория, встречи ----------
create table if not exists public.nii_events (
    id           bigint generated always as identity primary key,
    type         text not null default 'conference' check (type in ('conference', 'seminar', 'lab', 'meeting')),
    title        text not null,
    description  text not null default '',
    starts_at    timestamptz not null,
    duration_min int not null default 60,
    location     text not null default '',
    capacity     int not null default 0,      -- 0 = без ограничения
    pro_only     boolean not null default false,
    published    boolean not null default true,
    host         uuid references auth.users (id) on delete set null,
    created_at   timestamptz not null default now()
);
alter table public.nii_events enable row level security;

create or replace function public.nii_can_manage_event(event_type text) returns boolean
language sql stable as $$
    select public.nii_is_admin() or (public.nii_is_staff() and event_type in ('lab', 'meeting'))
$$;

drop policy if exists "events read" on public.nii_events;
create policy "events read" on public.nii_events for select using (published or public.nii_is_staff());
drop policy if exists "events create" on public.nii_events;
create policy "events create" on public.nii_events for insert with check (public.nii_can_manage_event(type));
drop policy if exists "events update" on public.nii_events;
create policy "events update" on public.nii_events for update
    using (public.nii_can_manage_event(type)) with check (public.nii_can_manage_event(type));
drop policy if exists "events delete" on public.nii_events;
create policy "events delete" on public.nii_events for delete using (public.nii_can_manage_event(type));

create table if not exists public.nii_event_regs (
    event_id   bigint references public.nii_events (id) on delete cascade,
    user_id    uuid references auth.users (id) on delete cascade default auth.uid(),
    created_at timestamptz not null default now(),
    primary key (event_id, user_id)
);
alter table public.nii_event_regs enable row level security;

-- Ссылка Zoom видна только записавшимся и команде
create table if not exists public.nii_event_links (
    event_id bigint primary key references public.nii_events (id) on delete cascade,
    zoom_url text not null default ''
);
alter table public.nii_event_links enable row level security;

drop policy if exists "links read" on public.nii_event_links;
create policy "links read" on public.nii_event_links for select using (
    public.nii_is_staff()
    or exists (select 1 from public.nii_event_regs r where r.event_id = nii_event_links.event_id and r.user_id = auth.uid()));
drop policy if exists "links write" on public.nii_event_links;
create policy "links write" on public.nii_event_links for all
    using (public.nii_can_manage_event((select type from public.nii_events e where e.id = event_id)))
    with check (public.nii_can_manage_event((select type from public.nii_events e where e.id = event_id)));

-- Свободные места проверяет база
create or replace function public.nii_check_capacity() returns trigger
language plpgsql security definer set search_path = public as $$
declare
    cap int;
    taken int;
begin
    select capacity into cap from nii_events where id = new.event_id;
    select count(*) into taken from nii_event_regs where event_id = new.event_id;
    if cap > 0 and taken >= cap then
        raise exception 'Мест больше нет';
    end if;
    return new;
end $$;

drop trigger if exists nii_check_capacity on public.nii_event_regs;
create trigger nii_check_capacity before insert on public.nii_event_regs
for each row execute function public.nii_check_capacity();

drop policy if exists "regs read" on public.nii_event_regs;
create policy "regs read" on public.nii_event_regs for select using (user_id = auth.uid() or public.nii_is_staff());
drop policy if exists "regs create own" on public.nii_event_regs;
create policy "regs create own" on public.nii_event_regs for insert with check (user_id = auth.uid());
drop policy if exists "regs delete own" on public.nii_event_regs;
create policy "regs delete own" on public.nii_event_regs for delete using (user_id = auth.uid() or public.nii_is_admin());

-- Число записавшихся для всех (без имён)
create or replace function public.nii_event_counts() returns table (event_id bigint, taken bigint)
language sql stable security definer set search_path = public as $$
    select event_id, count(*) from nii_event_regs group by event_id
$$;

-- ---------- Курсы ----------
create table if not exists public.nii_courses (
    id          bigint generated always as identity primary key,
    title       text not null,
    description text not null default '',
    image_url   text not null default '',
    is_pro      boolean not null default false,
    published   boolean not null default true,
    created_at  timestamptz not null default now()
);
create table if not exists public.nii_lessons (
    id        bigint generated always as identity primary key,
    course_id bigint not null references public.nii_courses (id) on delete cascade,
    title     text not null,
    content   text not null default '',
    video_url text not null default '',
    sort      int not null default 0
);
create table if not exists public.nii_enrollments (
    user_id    uuid references auth.users (id) on delete cascade default auth.uid(),
    course_id  bigint references public.nii_courses (id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (user_id, course_id)
);
create table if not exists public.nii_progress (
    user_id   uuid references auth.users (id) on delete cascade default auth.uid(),
    lesson_id bigint references public.nii_lessons (id) on delete cascade,
    done_at   timestamptz not null default now(),
    primary key (user_id, lesson_id)
);
alter table public.nii_courses enable row level security;
alter table public.nii_lessons enable row level security;
alter table public.nii_enrollments enable row level security;
alter table public.nii_progress enable row level security;

drop policy if exists "courses read" on public.nii_courses;
create policy "courses read" on public.nii_courses for select using (published or public.nii_is_staff());
drop policy if exists "courses write" on public.nii_courses;
create policy "courses write" on public.nii_courses for all using (public.nii_is_admin()) with check (public.nii_is_admin());
drop policy if exists "lessons read" on public.nii_lessons;
create policy "lessons read" on public.nii_lessons for select using (
    public.nii_is_staff() or exists (select 1 from public.nii_courses c where c.id = course_id and c.published));
drop policy if exists "lessons write" on public.nii_lessons;
create policy "lessons write" on public.nii_lessons for all using (public.nii_is_admin()) with check (public.nii_is_admin());
drop policy if exists "enrollments own" on public.nii_enrollments;
create policy "enrollments own" on public.nii_enrollments for all
    using (user_id = auth.uid() or public.nii_is_admin()) with check (user_id = auth.uid());
drop policy if exists "progress own" on public.nii_progress;
create policy "progress own" on public.nii_progress for all
    using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- Программы и заявки ----------
create table if not exists public.nii_programs (
    id          bigint generated always as identity primary key,
    kind        text not null default 'Программа',
    title       text not null,
    description text not null default '',
    deadline    date,
    published   boolean not null default true,
    created_at  timestamptz not null default now()
);
create table if not exists public.nii_applications (
    id          bigint generated always as identity primary key,
    program_id  bigint not null references public.nii_programs (id) on delete cascade,
    user_id     uuid not null references auth.users (id) on delete cascade default auth.uid(),
    motivation  text not null default '',
    link        text not null default '',   -- ссылка на CV / проект
    status      text not null default 'submitted' check (status in ('submitted', 'accepted', 'rejected')),
    admin_note  text not null default '',
    created_at  timestamptz not null default now(),
    unique (program_id, user_id)
);
alter table public.nii_programs enable row level security;
alter table public.nii_applications enable row level security;

drop policy if exists "programs read" on public.nii_programs;
create policy "programs read" on public.nii_programs for select using (published or public.nii_is_staff());
drop policy if exists "programs write" on public.nii_programs;
create policy "programs write" on public.nii_programs for all using (public.nii_is_admin()) with check (public.nii_is_admin());

-- Решение по заявке принимает только организатор
create or replace function public.nii_application_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
    if not public.nii_is_admin() then
        if tg_op = 'INSERT' then
            new.status := 'submitted';
            new.admin_note := '';
        else
            new.status := old.status;
            new.admin_note := old.admin_note;
        end if;
    end if;
    return new;
end $$;
drop trigger if exists nii_application_guard on public.nii_applications;
create trigger nii_application_guard before insert or update on public.nii_applications
for each row execute function public.nii_application_guard();

drop policy if exists "applications read" on public.nii_applications;
create policy "applications read" on public.nii_applications for select using (user_id = auth.uid() or public.nii_is_admin());
drop policy if exists "applications create own" on public.nii_applications;
create policy "applications create own" on public.nii_applications for insert with check (user_id = auth.uid());
drop policy if exists "applications decide" on public.nii_applications;
create policy "applications decide" on public.nii_applications for update using (public.nii_is_admin());

-- ---------- Новости ----------
create table if not exists public.nii_news (
    id         bigint generated always as identity primary key,
    title      text not null,
    body       text not null default '',
    image_url  text not null default '',
    published  boolean not null default true,
    created_at timestamptz not null default now()
);
alter table public.nii_news enable row level security;
drop policy if exists "news read" on public.nii_news;
create policy "news read" on public.nii_news for select using (published or public.nii_is_admin());
drop policy if exists "news write" on public.nii_news;
create policy "news write" on public.nii_news for all using (public.nii_is_admin()) with check (public.nii_is_admin());

-- ---------- Мерч (физические товары: оплата переводом, не через App Store) ----------
create table if not exists public.nii_products (
    id          bigint generated always as identity primary key,
    title       text not null,
    description text not null default '',
    image_url   text not null default '',
    price       numeric(10,2) not null default 0,
    active      boolean not null default true
);
create table if not exists public.nii_orders (
    id         bigint generated always as identity primary key,
    user_id    uuid not null references auth.users (id) on delete cascade default auth.uid(),
    product_id bigint references public.nii_products (id) on delete set null,
    title      text not null default '',
    amount     numeric(10,2) not null default 0,
    note       text not null default '',          -- размер, цвет, адрес доставки
    status     text not null default 'new' check (status in ('new', 'paid', 'shipped', 'cancelled')),
    created_at timestamptz not null default now()
);
alter table public.nii_products enable row level security;
alter table public.nii_orders enable row level security;

drop policy if exists "products read" on public.nii_products;
create policy "products read" on public.nii_products for select using (active or public.nii_is_admin());
drop policy if exists "products write" on public.nii_products;
create policy "products write" on public.nii_products for all using (public.nii_is_admin()) with check (public.nii_is_admin());

-- Цена и название заказа берутся из товара, а не из приложения
create or replace function public.nii_order_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
    if tg_op = 'INSERT' then
        select title, price into new.title, new.amount from nii_products where id = new.product_id and active;
        if new.title is null then raise exception 'Товар не найден'; end if;
        new.status := 'new';
    elsif not public.nii_is_admin() then
        new := old;
    end if;
    return new;
end $$;
drop trigger if exists nii_order_guard on public.nii_orders;
create trigger nii_order_guard before insert or update on public.nii_orders
for each row execute function public.nii_order_guard();

drop policy if exists "orders read" on public.nii_orders;
create policy "orders read" on public.nii_orders for select using (user_id = auth.uid() or public.nii_is_admin());
drop policy if exists "orders create own" on public.nii_orders;
create policy "orders create own" on public.nii_orders for insert with check (user_id = auth.uid());
drop policy if exists "orders manage" on public.nii_orders;
create policy "orders manage" on public.nii_orders for update using (public.nii_is_admin());

-- ---------- Удаление аккаунта (требование App Store) ----------
-- Удаляет все данные НИИ. Сам вход (auth.users) удаляется, только если этот
-- e-mail не используется в KKSU Online (проект Supabase общий).
create or replace function public.nii_delete_account() returns boolean
language plpgsql security definer set search_path = public as $$
declare
    me uuid := auth.uid();
    in_kksu boolean := false;
begin
    if me is null then raise exception 'Войдите в аккаунт'; end if;
    delete from nii_event_regs where user_id = me;
    delete from nii_progress where user_id = me;
    delete from nii_enrollments where user_id = me;
    delete from nii_applications where user_id = me;
    delete from nii_orders where user_id = me;
    update nii_tasks set assignee = null where assignee = me;
    delete from nii_profiles where user_id = me;
    if to_regclass('public.kksu_members') is not null then
        execute 'select exists(select 1 from public.kksu_members where user_id = $1)' into in_kksu using me;
    end if;
    if not in_kksu then
        delete from auth.users where id = me;
    end if;
    return true;
end $$;
revoke all on function public.nii_delete_account() from anon, public;
grant execute on function public.nii_delete_account() to authenticated;

-- ---------- Доступ приложения к таблицам ----------
-- В новых проектах Supabase таблицы могут не открываться приложению автоматически.
-- Что именно можно читать и менять, всё равно решают правила RLS выше.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant execute on function public.nii_claim_role(text), public.nii_activate_family(text),
    public.nii_event_counts(), public.nii_delete_account() to authenticated;
revoke all on public.nii_secrets from anon, authenticated;
notify pgrst, 'reload schema';

-- ---------- Коды для регистрации организатора и команды ----------
select key as "Код", value as "Значение — сохраните!" from public.nii_secrets where key in ('admin_code', 'team_code');
