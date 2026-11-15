-- LOJA DO IPHONE | Etapa 2 | estrutura inicial independente
-- Execute APENAS no projeto Supabase exclusivo da LOJA DO IPHONE.
-- Nunca execute em CRM-PRE-VENDAS ou outros projetos.
create extension if not exists pgcrypto;
create schema if not exists app_private;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'seller' check (role in ('admin', 'seller')),
  active boolean not null default false,
  created_at timestamptz not null default now()
);

-- A função não está em um schema exposto à Data API.
-- Sua única finalidade é conferir a função atribuída pelo administrador.
create or replace function app_private.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and active and role = 'admin'
  );
$$;

create or replace function app_private.is_active()
returns boolean language sql stable security definer set search_path = ''
as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and active
  );
$$;

revoke all on schema app_private from public, anon;
grant usage on schema app_private to authenticated;
revoke all on function app_private.is_admin() from public, anon;
revoke all on function app_private.is_active() from public, anon;
grant execute on function app_private.is_admin() to authenticated;
grant execute on function app_private.is_active() to authenticated;

-- Perfis entram inativos, mesmo se alguém cadastrar conta indevidamente.
create or replace function app_private.create_new_profile()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, role, active)
  values (new.id, coalesce(split_part(new.email, '@', 1), 'Usuário'), 'seller', false)
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function app_private.create_new_profile() from public, anon, authenticated;
drop trigger if exists trg_loja_iphone_profile on auth.users;
create trigger trg_loja_iphone_profile
after insert on auth.users
for each row execute function app_private.create_new_profile();

-- Caso algum usuário já exista no projeto, iniciar também como inativo.
insert into public.profiles (id, full_name, role, active)
select id, coalesce(split_part(email,'@',1),'Usuário'), 'seller', false
from auth.users
on conflict (id) do nothing;

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (length(trim(full_name)) >= 2),
  phone text not null check (length(trim(phone)) >= 8),
  model_interest text,
  storage text,
  budget numeric(12,2) check (budget is null or budget >= 0),
  condition text,
  trade_in boolean not null default false,
  notes text,
  origin text not null default 'manual',
  status text not null default 'novo' check (status in ('novo','atendimento','proposta','vendido','perdido')),
  assigned_to uuid references public.profiles(id),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists leads_assigned_to_idx on public.leads(assigned_to);
create index if not exists leads_created_at_idx on public.leads(created_at desc);

create or replace function app_private.touch_updated_at()
returns trigger language plpgsql set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists trg_loja_iphone_leads_updated on public.leads;
create trigger trg_loja_iphone_leads_updated
before update on public.leads for each row
execute function app_private.touch_updated_at();

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null unique references public.leads(id) on delete cascade,
  last_message_at timestamptz,
  unread_count integer not null default 0 check(unread_count >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  direction text not null check (direction in ('incoming','outgoing')),
  body text,
  meta_message_id text unique,
  delivery_status text not null default 'received',
  created_at timestamptz not null default now()
);
create index if not exists messages_conversation_time_idx on public.messages(conversation_id, created_at desc);

create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  template_name text,
  status text not null default 'rascunho' check (status in ('rascunho','agendada','enviando','concluida','cancelada')),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.leads enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.campaigns enable row level security;

drop policy if exists "profiles_select_self_admin" on public.profiles;
create policy "profiles_select_self_admin" on public.profiles
for select to authenticated
using ((id=(select auth.uid()) and active) or app_private.is_admin());

drop policy if exists "profiles_insert_admin" on public.profiles;
create policy "profiles_insert_admin" on public.profiles
for insert to authenticated with check (app_private.is_admin());

drop policy if exists "profiles_update_admin" on public.profiles;
create policy "profiles_update_admin" on public.profiles
for update to authenticated
using (app_private.is_admin()) with check (app_private.is_admin());

drop policy if exists "leads_read_assigned_or_admin" on public.leads;
create policy "leads_read_assigned_or_admin" on public.leads
for select to authenticated
using (app_private.is_admin() or (app_private.is_active() and assigned_to=(select auth.uid())));

drop policy if exists "leads_insert_assigned_or_admin" on public.leads;
create policy "leads_insert_assigned_or_admin" on public.leads
for insert to authenticated
with check (
  app_private.is_admin() or
  (app_private.is_active() and assigned_to=(select auth.uid()) and created_by=(select auth.uid()))
);

drop policy if exists "leads_update_assigned_or_admin" on public.leads;
create policy "leads_update_assigned_or_admin" on public.leads
for update to authenticated
using (app_private.is_admin() or (app_private.is_active() and assigned_to=(select auth.uid())))
with check (app_private.is_admin() or (app_private.is_active() and assigned_to=(select auth.uid())));

drop policy if exists "leads_delete_admin" on public.leads;
create policy "leads_delete_admin" on public.leads
for delete to authenticated using (app_private.is_admin());

drop policy if exists "conversations_read_assigned" on public.conversations;
create policy "conversations_read_assigned" on public.conversations
for select to authenticated
using (exists (select 1 from public.leads where leads.id=lead_id));

-- Mensagens serão escritas somente pelo backend seguro da Cloud API,
-- não diretamente pelos navegadores dos vendedores.
drop policy if exists "messages_read_assigned" on public.messages;
create policy "messages_read_assigned" on public.messages
for select to authenticated
using (exists (
 select 1 from public.conversations c
 join public.leads l on l.id=c.lead_id
 where c.id=messages.conversation_id
));

drop policy if exists "campaigns_admin_all" on public.campaigns;
create policy "campaigns_admin_all" on public.campaigns
for all to authenticated
using (app_private.is_admin()) with check (app_private.is_admin());

grant usage on schema public to authenticated;
grant select, insert, update on public.leads to authenticated;
grant delete on public.leads to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select on public.conversations, public.messages to authenticated;
grant select, insert, update, delete on public.campaigns to authenticated;

-- Depois de convidar seu primeiro administrador no Supabase Auth:
-- UPDATE public.profiles SET role='admin', active=true
-- WHERE id = (SELECT id FROM auth.users WHERE email='EMAIL_DO_ADMIN');
-- Nunca compartilhe uma senha nem coloque service_role no GitHub Pages.
