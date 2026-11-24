create table if not exists public.ex_service_fee_config (
  id boolean primary key default true check (id = true),
  fee_type text not null default 'fee_percent' check (fee_type in ('fee_percent','fee_fixed')),
  fee_value numeric(14,4) not null default 0 check (fee_value >= 0),
  is_active boolean not null default false,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

insert into public.ex_service_fee_config(id,fee_type,fee_value,is_active)
values(true,'fee_percent',0,false)
on conflict (id) do nothing;

alter table public.ex_service_fee_config enable row level security;

create or replace function public.ex_service_fee_get()
returns jsonb language plpgsql stable security definer set search_path to '' as $function$
declare v_uid uuid := auth.uid(); r public.ex_service_fee_config;
begin
  if v_uid is null then raise exception using errcode='42501',message='AUTH_REQUIRED'; end if;
  select * into r from public.ex_service_fee_config where id=true;
  return jsonb_build_object('fee_type',r.fee_type,'fee_value',r.fee_value,'is_active',r.is_active,'updated_at',r.updated_at);
end; $function$;

create or replace function public.ex_admin_service_fee_update(
  p_fee_type text,
  p_fee_value numeric,
  p_is_active boolean
) returns jsonb language plpgsql security definer set search_path to '' as $function$
declare v_uid uuid := auth.uid(); r public.ex_service_fee_config;
begin
  perform public.ex_kyc_assert_admin();
  if p_fee_type not in ('fee_percent','fee_fixed') then raise exception using errcode='P0001',message='SERVICE_FEE_TYPE_INVALID'; end if;
  if p_fee_value is null or p_fee_value < 0 then raise exception using errcode='P0001',message='SERVICE_FEE_VALUE_INVALID'; end if;
  if p_fee_type='fee_percent' and p_fee_value>100 then raise exception using errcode='P0001',message='SERVICE_FEE_PERCENT_TOO_HIGH'; end if;
  if p_fee_type='fee_fixed' and p_fee_value>1000000000 then raise exception using errcode='P0001',message='SERVICE_FEE_FIXED_TOO_HIGH'; end if;
  insert into public.ex_service_fee_config(id,fee_type,fee_value,is_active,updated_by,updated_at)
  values(true,p_fee_type,p_fee_value,p_is_active,v_uid,now())
  on conflict(id) do update set fee_type=excluded.fee_type,fee_value=excluded.fee_value,is_active=excluded.is_active,updated_by=excluded.updated_by,updated_at=now()
  returning * into r;
  return jsonb_build_object('fee_type',r.fee_type,'fee_value',r.fee_value,'is_active',r.is_active,'updated_at',r.updated_at);
end; $function$;

revoke all on public.ex_service_fee_config from anon, authenticated;
revoke execute on function public.ex_service_fee_get() from anon;
revoke execute on function public.ex_admin_service_fee_update(text,numeric,boolean) from anon;
grant execute on function public.ex_service_fee_get() to authenticated;
grant execute on function public.ex_admin_service_fee_update(text,numeric,boolean) to authenticated;
