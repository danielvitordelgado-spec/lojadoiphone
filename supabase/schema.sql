
-- LOJA DO IPHONE: tabelas isoladas no projeto Supabase "Daniel Delgado".
-- Não modifica public.leads, public.profiles, auth.users nem tabelas comerciais existentes.
-- Contas Auth são compartilhadas pelo projeto, mas só entram aqui se cadastradas
-- expressamente em public.iphone_team_members.
create schema if not exists iphone_private;

create table if not exists public.iphone_team_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role text not null default 'seller' check (role in ('admin','seller')),
  active boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function iphone_private.is_admin()
returns boolean language sql stable security definer set search_path=''
as $$
  select (select auth.uid()) is not null
   and exists (
      select 1 from public.iphone_team_members
      where user_id=(select auth.uid()) and active and role='admin'
   );
$$;

create or replace function iphone_private.is_member()
returns boolean language sql stable security definer set search_path=''
as $$
  select (select auth.uid()) is not null
   and exists (
      select 1 from public.iphone_team_members
      where user_id=(select auth.uid()) and active
   );
$$;

revoke all on schema iphone_private from public, anon;
grant usage on schema iphone_private to authenticated;
revoke all on function iphone_private.is_admin() from public, anon;
revoke all on function iphone_private.is_member() from public, anon;
grant execute on function iphone_private.is_admin() to authenticated;
grant execute on function iphone_private.is_member() to authenticated;

create table if not exists public.iphone_leads (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check(length(trim(full_name)) >= 2),
  phone text not null check(length(trim(phone)) >= 8),
  model_interest text,
  storage text,
  budget numeric(12,2) check(budget is null or budget >= 0),
  condition text,
  trade_in boolean not null default false,
  notes text,
  origin text not null default 'manual',
  status text not null default 'novo'
     check(status in ('novo','atendimento','proposta','vendido','perdido')),
  assigned_to uuid references public.iphone_team_members(user_id),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists iphone_leads_assigned_idx on public.iphone_leads(assigned_to);
create index if not exists iphone_leads_created_idx on public.iphone_leads(created_at desc);

create or replace function iphone_private.protect_lead_fields()
returns trigger language plpgsql set search_path=''
as $$
begin
  if tg_op='UPDATE' then
    if auth.uid() is not null and not iphone_private.is_admin() then
      if new.assigned_to is distinct from old.assigned_to
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at then
        raise exception 'O vendedor não pode mudar responsável, criador ou criação do lead';
      end if;
    end if;
    new.updated_at=now();
  end if;
  return new;
end
$$;
drop trigger if exists iphone_leads_protect on public.iphone_leads;
create trigger iphone_leads_protect
before update on public.iphone_leads
for each row execute function iphone_private.protect_lead_fields();

create table if not exists public.iphone_conversations (
 id uuid primary key default gen_random_uuid(),
 lead_id uuid not null unique references public.iphone_leads(id) on delete cascade,
 last_message_at timestamptz,
 unread_count integer not null default 0 check (unread_count>=0),
 created_at timestamptz not null default now()
);
create table if not exists public.iphone_messages (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.iphone_conversations(id) on delete cascade,
 direction text not null check(direction in ('incoming','outgoing')),
 body text,
 meta_message_id text unique,
 delivery_status text not null default 'received',
 created_at timestamptz not null default now()
);
create index if not exists iphone_messages_time_idx
on public.iphone_messages(conversation_id,created_at desc);

create table if not exists public.iphone_campaigns (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 template_name text,
 status text not null default 'rascunho'
  check(status in ('rascunho','agendada','enviando','concluida','cancelada')),
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);

alter table public.iphone_team_members enable row level security;
alter table public.iphone_leads enable row level security;
alter table public.iphone_conversations enable row level security;
alter table public.iphone_messages enable row level security;
alter table public.iphone_campaigns enable row level security;

drop policy if exists iphone_members_select on public.iphone_team_members;
create policy iphone_members_select on public.iphone_team_members
for select to authenticated
using ((user_id=(select auth.uid()) and active) or iphone_private.is_admin());
drop policy if exists iphone_members_insert on public.iphone_team_members;
create policy iphone_members_insert on public.iphone_team_members
for insert to authenticated with check (iphone_private.is_admin());
drop policy if exists iphone_members_update on public.iphone_team_members;
create policy iphone_members_update on public.iphone_team_members
for update to authenticated
using (iphone_private.is_admin()) with check (iphone_private.is_admin());

drop policy if exists iphone_leads_select on public.iphone_leads;
create policy iphone_leads_select on public.iphone_leads
for select to authenticated
using (iphone_private.is_admin()
  or (iphone_private.is_member() and assigned_to=(select auth.uid())));
drop policy if exists iphone_leads_insert on public.iphone_leads;
create policy iphone_leads_insert on public.iphone_leads
for insert to authenticated
with check (
  created_by=(select auth.uid()) and
  (iphone_private.is_admin()
    or (iphone_private.is_member() and assigned_to=(select auth.uid())))
);
drop policy if exists iphone_leads_update on public.iphone_leads;
create policy iphone_leads_update on public.iphone_leads
for update to authenticated
using (iphone_private.is_admin()
  or (iphone_private.is_member() and assigned_to=(select auth.uid())))
with check (iphone_private.is_admin()
  or (iphone_private.is_member() and assigned_to=(select auth.uid())));
drop policy if exists iphone_leads_delete on public.iphone_leads;
create policy iphone_leads_delete on public.iphone_leads
for delete to authenticated
using (iphone_private.is_admin());

drop policy if exists iphone_conversations_select on public.iphone_conversations;
create policy iphone_conversations_select on public.iphone_conversations
for select to authenticated
using (exists (select 1 from public.iphone_leads l where l.id=lead_id));
drop policy if exists iphone_messages_select on public.iphone_messages;
create policy iphone_messages_select on public.iphone_messages
for select to authenticated
using (exists (
  select 1 from public.iphone_conversations c
  join public.iphone_leads l on l.id=c.lead_id
  where c.id=conversation_id
));
drop policy if exists iphone_campaigns_admin on public.iphone_campaigns;
create policy iphone_campaigns_admin on public.iphone_campaigns
for all to authenticated
using (iphone_private.is_admin()) with check (iphone_private.is_admin());

-- Somente usuários autenticados; a segurança dos registros é imposta por RLS.
revoke all on public.iphone_team_members, public.iphone_leads,
public.iphone_conversations, public.iphone_messages, public.iphone_campaigns
from public, anon;
grant select,insert,update on public.iphone_team_members to authenticated;
grant select,insert,update,delete on public.iphone_leads to authenticated;
grant select on public.iphone_conversations,public.iphone_messages to authenticated;
grant select,insert,update,delete on public.iphone_campaigns to authenticated;

-- Primeiro administrador: criar usuário em Authentication > Users,
-- depois inserir a associação EXCLUSIVA da LOJA DO IPHONE:
-- insert into public.iphone_team_members(user_id,display_name,role,active)
-- select id,'Administrador','admin',true from auth.users
-- where email='EMAIL_DO_ADMIN' on conflict(user_id) do nothing;
