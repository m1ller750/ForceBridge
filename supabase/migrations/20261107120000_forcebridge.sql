-- ForceBridge: схема базы данных.
-- Пользователи, профили, карточки-объявления, отклики, избранное,
-- категории (их расставляет ИИ) и кэш оценок совместимости.

create extension if not exists pg_net;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- Настройки, которые не должны быть видны клиенту (адрес серверных функций).
create table if not exists private.settings (
  key   text primary key,
  value text not null
);

-- ---------------------------------------------------------------------------
-- Справочник категорий фильтра. Ключи использует ИИ и приложение.
-- ---------------------------------------------------------------------------
create table public.categories (
  key   text primary key,
  title text not null,
  grp   text not null check (grp in ('format', 'field')),
  sort  int  not null default 0
);

insert into public.categories (key, title, grp, sort) values
  ('hackathon',   'Хакатоны',                  'format', 1),
  ('olympiad',    'Олимпиады',                 'format', 2),
  ('contest',     'Конкурсы и чемпионаты',     'format', 3),
  ('research',    'Научные исследования',      'format', 4),
  ('startup',     'Стартапы и проекты',        'format', 5),
  ('it',          'IT и разработка',           'field', 10),
  ('ai',          'ИИ и данные',               'field', 11),
  ('design',      'Дизайн',                    'field', 12),
  ('engineering', 'Инженерия и робототехника', 'field', 13),
  ('biomed',      'Биология и медицина',       'field', 14),
  ('physchem',    'Физика и химия',            'field', 15),
  ('math',        'Математика',                'field', 16),
  ('ecology',     'Экология',                  'field', 17),
  ('business',    'Бизнес и маркетинг',        'field', 18),
  ('social',      'Социальные проекты',        'field', 19),
  ('media',       'Медиа и искусство',         'field', 20),
  ('education',   'Образование',               'field', 21);

-- ---------------------------------------------------------------------------
-- Профили
-- ---------------------------------------------------------------------------
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  full_name    text not null check (char_length(full_name) between 2 and 80),
  age          int  check (age between 10 and 99),
  city         text not null default '',
  occupation   text not null default '',
  about        text not null default '' check (char_length(about) <= 1500),
  skills       text[] not null default '{}',
  projects     text[] not null default '{}',
  achievements text[] not null default '{}',
  messenger    text not null check (messenger in ('telegram', 'whatsapp', 'instagram', 'tiktok', 'vk', 'discord', 'phone', 'other')),
  contact      text not null check (char_length(contact) between 2 and 80),
  resume_path  text,
  resume_name  text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Карточки-объявления
-- ---------------------------------------------------------------------------
create table public.cards (
  id              uuid primary key default gen_random_uuid(),
  author_id       uuid not null references public.profiles (id) on delete cascade,
  kind            text not null check (kind in ('teammate', 'research', 'join')),
  title           text not null check (char_length(title) between 3 and 120),
  description     text not null check (char_length(description) between 10 and 3000),
  event_name      text not null default '',
  roles           text[] not null default '{}',
  city            text not null default '',
  format          text not null default 'any' check (format in ('online', 'offline', 'any')),
  deadline        date,
  categories      text[] not null default '{}',
  ai_status       text not null default 'pending' check (ai_status in ('pending', 'done', 'error')),
  content_version int  not null default 1,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index cards_categories_idx on public.cards using gin (categories);
create index cards_created_idx    on public.cards (created_at desc);
create index cards_author_idx     on public.cards (author_id);
create index cards_pending_idx    on public.cards (ai_status) where ai_status <> 'done';

-- ---------------------------------------------------------------------------
-- Отклики
-- ---------------------------------------------------------------------------
create table public.responses (
  id         uuid primary key default gen_random_uuid(),
  card_id    uuid not null references public.cards (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  message    text not null default '' check (char_length(message) <= 500),
  hidden     boolean not null default false,
  created_at timestamptz not null default now(),
  unique (card_id, user_id)
);

create index responses_card_idx on public.responses (card_id);
create index responses_user_idx on public.responses (user_id);

-- ---------------------------------------------------------------------------
-- Избранное
-- ---------------------------------------------------------------------------
create table public.favorites (
  owner_id   uuid not null references public.profiles (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, profile_id),
  check (owner_id <> profile_id)
);

create index favorites_profile_idx on public.favorites (profile_id);

-- ---------------------------------------------------------------------------
-- Кэш оценок совместимости (пишет только серверная функция)
-- ---------------------------------------------------------------------------
create table public.compatibility (
  card_id         uuid not null references public.cards (id) on delete cascade,
  user_id         uuid not null references public.profiles (id) on delete cascade,
  score           int  not null check (score between 0 and 100),
  summary         text not null default '',
  strengths       text[] not null default '{}',
  gaps            text[] not null default '{}',
  card_version    timestamptz not null,
  profile_version timestamptz not null,
  created_at      timestamptz not null default now(),
  primary key (card_id, user_id)
);

create index compatibility_user_idx on public.compatibility (user_id);

-- ---------------------------------------------------------------------------
-- Триггеры
-- ---------------------------------------------------------------------------
create or replace function private.touch_profile()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  new.created_at := old.created_at;
  return new;
end;
$$;

create trigger profiles_touch
  before update on public.profiles
  for each row execute function private.touch_profile();

-- Категории может ставить только ИИ (серверная функция).
-- Любое изменение текста карточки сбрасывает категории и запускает повторный анализ.
create or replace function private.cards_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  is_client boolean := coalesce(auth.role(), '') in ('authenticated', 'anon');
begin
  if tg_op = 'INSERT' then
    if is_client then
      new.author_id  := auth.uid();
      new.categories := '{}';
      new.ai_status  := 'pending';
      new.created_at := now();
    end if;
    new.content_version := 1;
    new.updated_at := now();
    return new;
  end if;

  new.id         := old.id;
  new.author_id  := old.author_id;
  new.created_at := old.created_at;

  if new.title       is distinct from old.title
  or new.description is distinct from old.description
  or new.event_name  is distinct from old.event_name
  or new.roles       is distinct from old.roles
  or new.kind        is distinct from old.kind then
    new.content_version := old.content_version + 1;
    new.categories      := '{}';
    new.ai_status       := 'pending';
    new.updated_at      := now();
  else
    new.content_version := old.content_version;
    if is_client then
      new.categories := old.categories;
      new.ai_status  := old.ai_status;
    end if;
    if new.city     is distinct from old.city
    or new.format   is distinct from old.format
    or new.deadline is distinct from old.deadline then
      new.updated_at := now();
    else
      new.updated_at := old.updated_at;
    end if;
  end if;
  return new;
end;
$$;

create trigger cards_before_write
  before insert or update on public.cards
  for each row execute function private.cards_before_write();

-- После сохранения новой или изменённой карточки просим ИИ её классифицировать.
create or replace function private.cards_after_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  base text;
begin
  if new.ai_status <> 'pending' then
    return null;
  end if;
  if tg_op = 'UPDATE' and new.content_version = old.content_version then
    return null;
  end if;
  select value into base from private.settings where key = 'functions_url';
  if base is null then
    return null;
  end if;
  perform net.http_post(
    url := base || '/classify-card',
    body := jsonb_build_object('card_id', new.id, 'version', new.content_version),
    headers := '{"Content-Type": "application/json"}'::jsonb,
    timeout_milliseconds := 30000
  );
  return null;
end;
$$;

create trigger cards_after_write
  after insert or update on public.cards
  for each row execute function private.cards_after_write();

-- ---------------------------------------------------------------------------
-- Лента: карточка + автор + число откликов
-- ---------------------------------------------------------------------------
create view public.card_feed
with (security_invoker = true)
as
select
  c.id, c.author_id, c.kind, c.title, c.description, c.event_name, c.roles,
  c.city, c.format, c.deadline, c.categories, c.ai_status,
  c.created_at, c.updated_at,
  p.full_name  as author_name,
  p.city       as author_city,
  p.occupation as author_occupation,
  (select count(*) from public.responses r where r.card_id = c.id and not r.hidden)::int as responses_count
from public.cards c
join public.profiles p on p.id = c.author_id;

-- Поиск и фильтр. Внутри группы категорий — «или», между группами — «и».
create or replace function public.search_cards(
  p_formats text[] default '{}',
  p_fields  text[] default '{}',
  p_query   text   default '',
  p_kind    text   default '',
  p_sort    text   default 'new'
)
returns setof public.card_feed
language sql
stable
security invoker
set search_path = ''
as $$
  select f.*
  from public.card_feed f
  where (cardinality(p_formats) = 0 or f.categories && p_formats)
    and (cardinality(p_fields) = 0 or f.categories && p_fields)
    and (coalesce(p_kind, '') = '' or f.kind = p_kind)
    and (
      coalesce(trim(p_query), '') = ''
      or f.title       ilike '%' || trim(p_query) || '%'
      or f.description ilike '%' || trim(p_query) || '%'
      or f.event_name  ilike '%' || trim(p_query) || '%'
      or f.author_name ilike '%' || trim(p_query) || '%'
    )
  order by
    case when p_sort = 'old' then f.created_at end asc,
    case when p_sort = 'deadline' then f.deadline end asc nulls last,
    f.created_at desc
  limit 300;
$$;

-- Сколько карточек в каждой категории (для фильтра).
create or replace function public.category_counts()
returns table (key text, total int)
language sql
stable
security invoker
set search_path = ''
as $$
  select k.key, count(c.id)::int
  from public.categories k
  left join public.cards c on k.key = any (c.categories)
  group by k.key;
$$;

revoke execute on function public.search_cards(text[], text[], text, text, text) from public, anon;
revoke execute on function public.category_counts() from public, anon;
grant execute on function public.search_cards(text[], text[], text, text, text) to authenticated;
grant execute on function public.category_counts() to authenticated;

-- ---------------------------------------------------------------------------
-- Политики доступа (RLS)
-- ---------------------------------------------------------------------------
alter table public.categories    enable row level security;
alter table public.profiles      enable row level security;
alter table public.cards         enable row level security;
alter table public.responses     enable row level security;
alter table public.favorites     enable row level security;
alter table public.compatibility enable row level security;

create policy "categories are public" on public.categories
  for select to anon, authenticated using (true);

create policy "profiles readable by members" on public.profiles
  for select to authenticated using (true);
create policy "create own profile" on public.profiles
  for insert to authenticated with check (id = (select auth.uid()));
create policy "update own profile" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "delete own profile" on public.profiles
  for delete to authenticated using (id = (select auth.uid()));

create policy "cards readable by members" on public.cards
  for select to authenticated using (true);
create policy "create own cards" on public.cards
  for insert to authenticated with check (author_id = (select auth.uid()));
create policy "update own cards" on public.cards
  for update to authenticated using (author_id = (select auth.uid())) with check (author_id = (select auth.uid()));
create policy "delete own cards" on public.cards
  for delete to authenticated using (author_id = (select auth.uid()));

create policy "responses visible to respondent and card owner" on public.responses
  for select to authenticated using (
    user_id = (select auth.uid())
    or exists (select 1 from public.cards c where c.id = card_id and c.author_id = (select auth.uid()))
  );
create policy "respond to other people's cards" on public.responses
  for insert to authenticated with check (
    user_id = (select auth.uid())
    and not exists (select 1 from public.cards c where c.id = card_id and c.author_id = (select auth.uid()))
  );
create policy "card owner hides responses" on public.responses
  for update to authenticated using (
    exists (select 1 from public.cards c where c.id = card_id and c.author_id = (select auth.uid()))
  );
create policy "withdraw own response" on public.responses
  for delete to authenticated using (user_id = (select auth.uid()));

-- Владелец карточки может менять только флаг «скрыт».
revoke update on public.responses from anon, authenticated;
grant update (hidden) on public.responses to authenticated;

create policy "own favorites" on public.favorites
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "own compatibility scores" on public.compatibility
  for select to authenticated using (user_id = (select auth.uid()));

revoke insert, update, delete on public.compatibility from anon, authenticated;
revoke insert, update, delete on public.categories from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Хранилище резюме
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'resumes', 'resumes', false, 10485760,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg',
    'image/png'
  ]
)
on conflict (id) do nothing;

create policy "members read resumes" on storage.objects
  for select to authenticated using (bucket_id = 'resumes');
create policy "upload own resume" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "replace own resume" on storage.objects
  for update to authenticated using (
    bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "delete own resume" on storage.objects
  for delete to authenticated using (
    bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
