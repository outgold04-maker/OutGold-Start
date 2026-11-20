-- OutGold Vagas 5D: ESBOÇO de migração segura para Supabase.
-- Revisar em projeto Supabase de teste antes de executar em produção.
-- NUNCA utilizar este script contra a planilha original do Google Apps Script.
create extension if not exists pgcrypto;
create table if not exists public.og_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.og_companies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references auth.users(id) on delete cascade,
  company_name text not null check (length(company_name) between 3 and 120),
  email text not null,
  phone text,
  cnpj text unique check (cnpj is null or cnpj ~ '^[0-9]{14}$'),
  city text not null,
  state text not null check (length(state)=2),
  status text not null default 'ACTIVE' check (status in ('ACTIVE','SUSPENDED')),
  plan_code text not null default 'TRIAL' check (plan_code in ('TRIAL','START','PRO','MAX')),
  plan_status text not null default 'TRIAL' check (plan_status in ('TRIAL','ACTIVE','EXPIRED')),
  trial_started_at timestamptz not null default now(),
  trial_ends_at timestamptz not null default (now() + interval '7 days'),
  plan_ends_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now()
);
create table if not exists public.og_jobs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.og_companies(id) on delete cascade,
  title text not null check (length(title) between 3 and 140),
  category text not null check (length(category) between 2 and 90),
  city text not null,
  state text not null check (length(state)=2),
  modality text not null check (modality in ('Presencial','Híbrido','Remoto')),
  contract text not null check (contract in ('CLT','PJ','Temporário','Estágio','Jovem Aprendiz','Freelancer','Autônomo','Outro')),
  salary text check (length(salary)<140),
  description text not null check (length(description) between 20 and 8000),
  requirements text default '',
  benefits text default '',
  status text not null default 'ACTIVE' check (status in ('ACTIVE','PAUSED','CLOSED')),
  deadline date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.og_applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.og_jobs(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete cascade,
  candidate_name text not null check (length(candidate_name) between 3 and 120),
  candidate_email text not null,
  candidate_phone text not null,
  candidate_city text,
  candidate_message text,
  resume_path text not null check (length(resume_path) between 20 and 400),
  status text not null default 'RECEBIDA'
    check (status in ('RECEBIDA','EM ANALISE','ENTREVISTA','FINALISTA','ENCERRADA')),
  created_at timestamptz not null default now(),
  unique (job_id,candidate_id)
);
create table if not exists public.og_payments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.og_companies(id) on delete cascade,
  plan_code text not null check (plan_code in ('START','PRO','MAX')),
  period text not null check (period in ('monthly','annual')),
  amount_cents integer generated always as (
    case
      when plan_code='START' and period='monthly' then 1990
      when plan_code='START' and period='annual' then 19900
      when plan_code='PRO' and period='monthly' then 3990
      when plan_code='PRO' and period='annual' then 39900
      when plan_code='MAX' and period='monthly' then 7990
      when plan_code='MAX' and period='annual' then 79900
      else 0
    end
  ) stored,
  status text not null default 'PENDING'
    check (status in ('PENDING','SENT','APPROVED','REJECTED')),
  payment_reference text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  activated_until timestamptz
);
create index if not exists og_jobs_listing_idx on public.og_jobs(status,created_at desc);
create index if not exists og_jobs_company_idx on public.og_jobs(company_id);
create index if not exists og_apps_job_idx on public.og_applications(job_id);
create index if not exists og_payments_company_idx on public.og_payments(company_id,created_at desc);

-- Security model: no direct creation or edits to subscriptions, company status,
-- billing or moderation from browser JS.
alter table public.og_admins enable row level security;
alter table public.og_companies enable row level security;
alter table public.og_jobs enable row level security;
alter table public.og_applications enable row level security;
alter table public.og_payments enable row level security;

revoke all on public.og_admins from anon,authenticated;
revoke all on public.og_companies from anon,authenticated;
revoke all on public.og_jobs from anon,authenticated;
revoke all on public.og_applications from anon,authenticated;
revoke all on public.og_payments from anon,authenticated;

grant select on public.og_admins to authenticated;
grant select on public.og_companies to authenticated;
grant select,insert,update on public.og_jobs to authenticated;
grant select,insert on public.og_applications to authenticated;
grant select on public.og_payments to authenticated;
-- Public jobs are returned only by the vetted og_public_jobs() RPC; no direct anonymous table SELECT.

create policy og_admin_self on public.og_admins for select to authenticated
using (user_id=auth.uid());
create policy og_companies_owner_read on public.og_companies for select to authenticated
using (owner_id=auth.uid() or exists(select 1 from public.og_admins a where a.user_id=auth.uid()));
create policy og_jobs_owner_read on public.og_jobs for select to authenticated
using (
  exists(select 1 from public.og_companies c where c.id=company_id and c.owner_id=auth.uid())
  or exists(select 1 from public.og_admins a where a.user_id=auth.uid())
);
-- Remove anonymous direct-table access: companies are private behind RLS.
create or replace function public.og_job_open_for_application(p_job uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
select exists(select 1 from public.og_jobs j
join public.og_companies c on c.id=j.company_id
where j.id=p_job and j.status='ACTIVE'
and (j.deadline is null or j.deadline>=current_date)
and c.status='ACTIVE' and c.plan_status in ('TRIAL','ACTIVE')
and c.plan_ends_at>now());
$$;
revoke all on function public.og_job_open_for_application(uuid) from public;
grant execute on function public.og_job_open_for_application(uuid) to authenticated;

create policy og_apps_candidate_read on public.og_applications for select to authenticated
using (candidate_id=auth.uid());
create policy og_apps_company_read on public.og_applications for select to authenticated
using (
  exists(select 1 from public.og_jobs j
    join public.og_companies c on c.id=j.company_id
    where j.id=job_id and c.owner_id=auth.uid())
  or exists(select 1 from public.og_admins a where a.user_id=auth.uid())
);
create policy og_apps_candidate_insert on public.og_applications for insert to authenticated
with check (
  candidate_id=auth.uid()
  and split_part(resume_path,'/',1)=auth.uid()::text
  and public.og_job_open_for_application(job_id)
);
create policy og_payments_owner_read on public.og_payments for select to authenticated
using (
  exists(select 1 from public.og_companies c where c.id=company_id and c.owner_id=auth.uid())
  or exists(select 1 from public.og_admins a where a.user_id=auth.uid())
);

-- Candidate cannot mint a favourable application status or impersonate a different email.
create or replace function public.og_validate_application()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $
declare v_email text;
begin
 if auth.uid() is null or new.candidate_id<>auth.uid() then raise exception 'Candidato não autorizado'; end if;
 select lower(email) into v_email from auth.users where id=auth.uid() and email_confirmed_at is not null;
 if v_email is null then raise exception 'Confirme seu e-mail'; end if;
 if split_part(new.resume_path,'/',1)<>auth.uid()::text then raise exception 'Currículo inválido'; end if;
 if not public.og_job_open_for_application(new.job_id) then raise exception 'Vaga não disponível'; end if;
 new.candidate_email=v_email;
 new.status='RECEBIDA';
 return new;
end $;
drop trigger if exists og_validate_application_before_insert on public.og_applications;
create trigger og_validate_application_before_insert before insert on public.og_applications
for each row execute function public.og_validate_application();

-- DB functions perform server-side checks that cannot be bypassed by editing HTML.
create or replace function public.og_register_company(
  p_name text,p_phone text,p_cnpj text,p_city text,p_state text
) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid := auth.uid(); v_email text; v_id uuid;
begin
  if v_uid is null then raise exception 'Faça login'; end if;
  select lower(email) into v_email from auth.users
    where id=v_uid and email_confirmed_at is not null;
  if v_email is null then raise exception 'Confirme seu e-mail primeiro'; end if;
  if length(trim(p_name))<3 or length(trim(p_city))<2 or length(trim(p_state))<>2 then
    raise exception 'Dados da empresa inválidos'; end if;
  if nullif(p_cnpj,'') is not null and p_cnpj!~'^[0-9]{14}
    raise exception 'CNPJ deve conter 14 números'; end if;
  insert into public.og_companies(owner_id,company_name,email,phone,cnpj,city,state)
  values(v_uid,trim(p_name),v_email,trim(p_phone),nullif(p_cnpj,''),trim(p_city),upper(trim(p_state)))
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.og_register_company(text,text,text,text,text) from public;
grant execute on function public.og_register_company(text,text,text,text,text) to authenticated;

create or replace function public.og_max_jobs(p_code text)
returns integer language sql immutable as $$
 select case p_code when 'TRIAL' then 3 when 'START' then 1
    when 'PRO' then 5 when 'MAX' then 20 else 0 end
$$;
create or replace function public.og_check_job_mutation()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.og_companies%rowtype; n integer;
begin
 if tg_op='UPDATE' and new.company_id<>old.company_id then
   raise exception 'Não é permitido trocar a empresa proprietária'; end if;
 select * into c from public.og_companies where id=new.company_id for update;
 if not found or (c.owner_id<>auth.uid() and not exists(select 1 from public.og_admins a where a.user_id=auth.uid())) then raise exception 'Empresa não autorizada'; end if;
 if new.status='ACTIVE' then
  if not(c.status='ACTIVE' and c.plan_ends_at>now()
    and c.plan_status in ('TRIAL','ACTIVE')) then
      raise exception 'Teste ou plano expirado'; end if;
  if tg_op='INSERT' or old.status<>'ACTIVE' then
   select count(*) into n from public.og_jobs
     where company_id=new.company_id and status='ACTIVE';
   if n>=public.og_max_jobs(c.plan_code) then raise exception 'Limite de vagas atingido'; end if;
  end if;
 end if;
 new.updated_at=now();
 return new;
end $$;
drop trigger if exists og_validate_job on public.og_jobs;
create trigger og_validate_job before insert or update on public.og_jobs
for each row execute function public.og_check_job_mutation();
create policy og_jobs_owner_insert on public.og_jobs for insert to authenticated
with check (exists(select 1 from public.og_companies c where c.id=company_id and c.owner_id=auth.uid()));
create policy og_jobs_owner_update on public.og_jobs for update to authenticated
using (exists(select 1 from public.og_companies c where c.id=company_id and c.owner_id=auth.uid()))
with check (exists(select 1 from public.og_companies c where c.id=company_id and c.owner_id=auth.uid()));

create or replace function public.og_public_jobs()
returns table (id uuid,title text,category text,city text,state text,modality text,
 contract text,salary text,description text,requirements text,benefits text,
 deadline date,company_name text,contact_email text,featured boolean,created_at timestamptz)
language sql stable security definer set search_path=public,pg_temp as $$
select j.id,j.title,j.category,j.city,j.state,j.modality,j.contract,j.salary,
 j.description,j.requirements,j.benefits,j.deadline,c.company_name,c.email,
 (c.plan_code='MAX'),j.created_at
from public.og_jobs j join public.og_companies c on c.id=j.company_id
where j.status='ACTIVE' and (j.deadline is null or j.deadline>=current_date)
 and c.status='ACTIVE' and c.plan_ends_at>now() and c.plan_status in ('TRIAL','ACTIVE')
order by (c.plan_code='MAX') desc,j.created_at desc limit 500;
$$;
revoke all on function public.og_public_jobs() from public;
grant execute on function public.og_public_jobs() to anon,authenticated;

create or replace function public.og_request_plan(p_code text,p_period text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_company uuid; v_id uuid;
begin
 if p_code not in ('START','PRO','MAX') or p_period not in ('monthly','annual')
 then raise exception 'Plano inválido'; end if;
 select id into v_company from public.og_companies where owner_id=auth.uid();
 if v_company is null then raise exception 'Cadastre a empresa primeiro'; end if;
 insert into public.og_payments(company_id,plan_code,period) values(v_company,p_code,p_period)
 returning id into v_id;
 return v_id;
end $$;
revoke all on function public.og_request_plan(text,text) from public;
grant execute on function public.og_request_plan(text,text) to authenticated;

create or replace function public.og_mark_payment_sent(p_id uuid,p_reference text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 update public.og_payments p set status='SENT',
   payment_reference=left(trim(p_reference),100)
 where p.id=p_id and p.status='PENDING'
   and exists(select 1 from public.og_companies c
      where c.id=p.company_id and c.owner_id=auth.uid());
 if not found then raise exception 'Pagamento não encontrado'; end if;
end $$;
revoke all on function public.og_mark_payment_sent(uuid,text) from public;
grant execute on function public.og_mark_payment_sent(uuid,text) to authenticated;

create or replace function public.og_admin_review_payment(p_id uuid,p_approve boolean)
returns timestamptz language plpgsql security definer set search_path=public,pg_temp as $$
declare p public.og_payments%rowtype; c public.og_companies%rowtype; v_end timestamptz;
begin
 if auth.uid() is null or not exists(select 1 from public.og_admins where user_id=auth.uid())
 then raise exception 'Acesso negado'; end if;
 select * into p from public.og_payments where id=p_id for update;
 if not found or p.status not in ('PENDING','SENT') then raise exception 'Solicitação já analisada'; end if;
 select * into c from public.og_companies where id=p.company_id for update;
 if p_approve then
   if c.status<>'ACTIVE' then raise exception 'Empresa suspensa'; end if;
   v_end=greatest(now(),c.plan_ends_at)
     + case when p.period='annual' then interval '365 days' else interval '30 days' end;
   update public.og_companies set plan_code=p.plan_code,plan_status='ACTIVE',plan_ends_at=v_end
    where id=c.id;
   update public.og_jobs set status='PAUSED'
     where company_id=c.id and status='ACTIVE' and id in
     (select id from public.og_jobs where company_id=c.id and status='ACTIVE'
         order by created_at desc offset public.og_max_jobs(p.plan_code));
 end if;
 update public.og_payments set status=case when p_approve then 'APPROVED' else 'REJECTED' end,
   reviewed_at=now(),reviewed_by=auth.uid(),activated_until=v_end where id=p.id;
 return v_end;
end $$;
revoke all on function public.og_admin_review_payment(uuid,boolean) from public;
grant execute on function public.og_admin_review_payment(uuid,boolean) to authenticated;

-- PRIVATE CV storage. Admin must review MIME filters and test RLS before live launch.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('og-resumes','og-resumes',false,3145728,ARRAY[
'application/pdf','application/msword',
'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
])
on conflict (id) do nothing;

create policy og_resumes_insert on storage.objects for insert to authenticated
with check (bucket_id='og-resumes'
 and (storage.foldername(name))[1]=auth.uid()::text);
create policy og_resumes_read on storage.objects for select to authenticated
using (bucket_id='og-resumes' and (
 (storage.foldername(name))[1]=auth.uid()::text
 or exists(select 1 from public.og_applications a
   join public.og_jobs j on j.id=a.job_id
   join public.og_companies c on c.id=j.company_id
   where a.resume_path=name and c.owner_id=auth.uid())
 or exists(select 1 from public.og_admins ad where ad.user_id=auth.uid())
));

-- Set status for a company-owned application without permitting arbitrary browser UPDATE.
create or replace function public.og_company_set_application_status(p_application uuid,p_status text)
returns void language plpgsql security definer set search_path=public,pg_temp as $
begin
 if p_status not in ('RECEBIDA','EM ANALISE','ENTREVISTA','FINALISTA','ENCERRADA')
 then raise exception 'Status inválido'; end if;
 update public.og_applications a set status=p_status
 where a.id=p_application and exists(
   select 1 from public.og_jobs j join public.og_companies c on c.id=j.company_id
   where j.id=a.job_id and c.owner_id=auth.uid());
 if not found then raise exception 'Candidatura não localizada'; end if;
end $;
revoke all on function public.og_company_set_application_status(uuid,text) from public;
grant execute on function public.og_company_set_application_status(uuid,text) to authenticated;

create or replace function public.og_admin_moderate_company(p_company uuid,p_status text)
returns void language plpgsql security definer set search_path=public,pg_temp as $
begin
 if auth.uid() is null or not exists(select 1 from public.og_admins where user_id=auth.uid())
 then raise exception 'Acesso negado'; end if;
 if p_status not in ('ACTIVE','SUSPENDED') then raise exception 'Status inválido'; end if;
 update public.og_companies set status=p_status where id=p_company;
 if not found then raise exception 'Empresa não localizada'; end if;
end $;
revoke all on function public.og_admin_moderate_company(uuid,text) from public;
grant execute on function public.og_admin_moderate_company(uuid,text) to authenticated;

-- Administração: NÃO inserir admin automaticamente. Definir manualmente após
-- validar um usuário Auth; exemplo conceitual:
-- insert into public.og_admins (user_id) values ('UID_DE_USUARIO_VERIFICADO');

-- Antes de produção: testar políticas de UPDATE de candidaturas, uploads,
-- limites de e-mail, remoção de CVs após 90 dias e governança LGPD.
 then
    raise exception 'CNPJ deve conter 14 números'; end if;
  insert into public.og_companies(owner_id,company_name,email,phone,cnpj,city,state)
  values(v_uid,trim(p_name),v_email,trim(p_phone),nullif(p_cnpj,''),trim(p_city),upper(trim(p_state)))
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.og_register_company(text,text,text,text,text) from public;
grant execute on function public.og_register_company(text,text,text,text,text) to authenticated;

create or replace function public.og_max_jobs(p_code text)
returns integer language sql immutable as $$
 select case p_code when 'TRIAL' then 3 when 'START' then 1
    when 'PRO' then 5 when 'MAX' then 20 else 0 end
$$;
create or replace function public.og_check_job_mutation()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.og_companies%rowtype; n integer;
begin
 if tg_op='UPDATE' and new.company_id<>old.company_id then
   raise exception 'Não é permitido trocar a empresa proprietária'; end if;
 select * into c from public.og_companies where id=new.company_id for update;
 if not found or c.owner_id<>auth.uid() then raise exception 'Empresa não autorizada'; end if;
 if new.status='ACTIVE' then
  if not(c.status='ACTIVE' and c.plan_ends_at>now()
    and c.plan_status in ('TRIAL','ACTIVE')) then
      raise exception 'Teste ou plano expirado'; end if;
  if tg_op='INSERT' or old.status<>'ACTIVE' then
   select count(*) into n from public.og_jobs
     where company_id=new.company_id and status='ACTIVE';
   if n>=public.og_max_jobs(c.plan_code) then raise exception 'Limite de vagas atingido'; end if;
  end if;
 end if;
 new.updated_at=now();
 return new;
end $$;
drop trigger if exists og_validate_job on public.og_jobs;
create trigger og_validate_job before insert or update on public.og_jobs
for each row execute function public.og_check_job_mutation();
create policy og_jobs_owner_insert on public.og_jobs for insert to authenticated
with check (exists(select 1 from public.og_companies c where c.id=company_id and c.owner_id=auth.uid()));
create policy og_jobs_owner_update on public.og_jobs for update to authenticated
using (exists(select 1 from public.og_companies c where c.id=company_id and c.owner_id=auth.uid()))
with check (exists(select 1 from public.og_companies c where c.id=company_id and c.owner_id=auth.uid()));

create or replace function public.og_public_jobs()
returns table (id uuid,title text,category text,city text,state text,modality text,
 contract text,salary text,description text,requirements text,benefits text,
 deadline date,company_name text,contact_email text,featured boolean,created_at timestamptz)
language sql stable security definer set search_path=public,pg_temp as $$
select j.id,j.title,j.category,j.city,j.state,j.modality,j.contract,j.salary,
 j.description,j.requirements,j.benefits,j.deadline,c.company_name,c.email,
 (c.plan_code='MAX'),j.created_at
from public.og_jobs j join public.og_companies c on c.id=j.company_id
where j.status='ACTIVE' and (j.deadline is null or j.deadline>=current_date)
 and c.status='ACTIVE' and c.plan_ends_at>now() and c.plan_status in ('TRIAL','ACTIVE')
order by (c.plan_code='MAX') desc,j.created_at desc limit 500;
$$;
revoke all on function public.og_public_jobs() from public;
grant execute on function public.og_public_jobs() to anon,authenticated;

create or replace function public.og_request_plan(p_code text,p_period text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_company uuid; v_id uuid;
begin
 if p_code not in ('START','PRO','MAX') or p_period not in ('monthly','annual')
 then raise exception 'Plano inválido'; end if;
 select id into v_company from public.og_companies where owner_id=auth.uid();
 if v_company is null then raise exception 'Cadastre a empresa primeiro'; end if;
 insert into public.og_payments(company_id,plan_code,period) values(v_company,p_code,p_period)
 returning id into v_id;
 return v_id;
end $$;
revoke all on function public.og_request_plan(text,text) from public;
grant execute on function public.og_request_plan(text,text) to authenticated;

create or replace function public.og_mark_payment_sent(p_id uuid,p_reference text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 update public.og_payments p set status='SENT',
   payment_reference=left(trim(p_reference),100)
 where p.id=p_id and p.status='PENDING'
   and exists(select 1 from public.og_companies c
      where c.id=p.company_id and c.owner_id=auth.uid());
 if not found then raise exception 'Pagamento não encontrado'; end if;
end $$;
revoke all on function public.og_mark_payment_sent(uuid,text) from public;
grant execute on function public.og_mark_payment_sent(uuid,text) to authenticated;

create or replace function public.og_admin_review_payment(p_id uuid,p_approve boolean)
returns timestamptz language plpgsql security definer set search_path=public,pg_temp as $$
declare p public.og_payments%rowtype; c public.og_companies%rowtype; v_end timestamptz;
begin
 if auth.uid() is null or not exists(select 1 from public.og_admins where user_id=auth.uid())
 then raise exception 'Acesso negado'; end if;
 select * into p from public.og_payments where id=p_id for update;
 if not found or p.status not in ('PENDING','SENT') then raise exception 'Solicitação já analisada'; end if;
 select * into c from public.og_companies where id=p.company_id for update;
 if p_approve then
   if c.status<>'ACTIVE' then raise exception 'Empresa suspensa'; end if;
   v_end=greatest(now(),c.plan_ends_at)
     + case when p.period='annual' then interval '365 days' else interval '30 days' end;
   update public.og_companies set plan_code=p.plan_code,plan_status='ACTIVE',plan_ends_at=v_end
    where id=c.id;
   update public.og_jobs set status='PAUSED'
     where company_id=c.id and status='ACTIVE' and id in
     (select id from public.og_jobs where company_id=c.id and status='ACTIVE'
         order by created_at desc offset public.og_max_jobs(p.plan_code));
 end if;
 update public.og_payments set status=case when p_approve then 'APPROVED' else 'REJECTED' end,
   reviewed_at=now(),reviewed_by=auth.uid(),activated_until=v_end where id=p.id;
 return v_end;
end $$;
revoke all on function public.og_admin_review_payment(uuid,boolean) from public;
grant execute on function public.og_admin_review_payment(uuid,boolean) to authenticated;

-- PRIVATE CV storage. Admin must review MIME filters and test RLS before live launch.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('og-resumes','og-resumes',false,3145728,ARRAY[
'application/pdf','application/msword',
'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
])
on conflict (id) do nothing;

create policy og_resumes_insert on storage.objects for insert to authenticated
with check (bucket_id='og-resumes'
 and (storage.foldername(name))[1]=auth.uid()::text);
create policy og_resumes_read on storage.objects for select to authenticated
using (bucket_id='og-resumes' and (
 (storage.foldername(name))[1]=auth.uid()::text
 or exists(select 1 from public.og_applications a
   join public.og_jobs j on j.id=a.job_id
   join public.og_companies c on c.id=j.company_id
   where a.resume_path=name and c.owner_id=auth.uid())
 or exists(select 1 from public.og_admins ad where ad.user_id=auth.uid())
));

-- Administração: NÃO inserir admin automaticamente. Definir manualmente após
-- validar um usuário Auth; exemplo conceitual:
-- insert into public.og_admins (user_id) values ('UID_DE_USUARIO_VERIFICADO');

-- Antes de produção: testar políticas de UPDATE de candidaturas, uploads,
-- limites de e-mail, remoção de CVs após 90 dias e governança LGPD.
