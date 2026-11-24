-- Exchange KYC selfie and server-side Google Vision metadata.
-- Private storage remains private; only paths are returned to admins.

alter table public.ex_identity_verifications
  add column if not exists selfie_image_path text;

create table if not exists public.ex_identity_verification_face (
  verification_id uuid primary key references public.ex_identity_verifications(id) on delete cascade,
  status text not null default 'queued' check (status in ('queued','processing','review','matched','not_matched','error')),
  face_detected boolean,
  match_score numeric(6,5),
  error_code text,
  model text,
  processed_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.ex_identity_verification_face enable row level security;

drop policy if exists identity_documents_insert_own on storage.objects;
create policy identity_documents_insert_own on storage.objects
for insert to authenticated
with check (
  bucket_id = 'identity-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and array_length(storage.foldername(name), 1) = 2
  and storage.filename(name) = any(array['front.jpg','front.png','front.webp','back.jpg','back.png','back.webp','selfie.jpg','selfie.png','selfie.webp'])
  and public.ex_kyc_can_upload((storage.foldername(name))[2])
);

drop policy if exists identity_documents_update_own_draft on storage.objects;
create policy identity_documents_update_own_draft on storage.objects
for update to authenticated
using (
  bucket_id = 'identity-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and public.ex_kyc_can_upload((storage.foldername(name))[2])
)
with check (
  bucket_id = 'identity-documents'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and array_length(storage.foldername(name), 1) = 2
  and storage.filename(name) = any(array['front.jpg','front.png','front.webp','back.jpg','back.png','back.webp','selfie.jpg','selfie.png','selfie.webp'])
  and public.ex_kyc_can_upload((storage.foldername(name))[2])
);

create or replace function public.ex_kyc_submit(
  p_verification_id uuid,
  p_document_type text,
  p_full_legal_name text,
  p_date_of_birth date,
  p_document_number text,
  p_front_path text,
  p_back_path text default null,
  p_document_issue_date date default null,
  p_document_expiry_date date default null,
  p_selfie_path text default null
) returns jsonb language plpgsql security definer set search_path to '' as $function$
declare
  v_uid uuid := auth.uid(); v_banned boolean; s record; v_name text; v_number text;
  v_prefix text; v_req_id uuid; v_prior int; v_recent int; v_event text;
begin
  if v_uid is null then raise exception using errcode='42501',message='AUTH_REQUIRED'; end if;
  select is_banned into v_banned from public.ex_profiles where id=v_uid;
  if not found then raise exception using errcode='P0001',message='PROFILE_NOT_FOUND'; end if;
  if v_banned then raise exception using errcode='42501',message='ACCOUNT_BANNED'; end if;
  perform pg_advisory_xact_lock(hashtextextended('ex_kyc:'||v_uid::text,0));
  select * into s from public.ex_kyc_state(v_uid);
  if not s.can_submit then raise exception using errcode='P0001',message=case when s.status='pending' then 'KYC_ALREADY_PENDING' else 'KYC_ALREADY_APPROVED' end; end if;
  if p_verification_id is null or exists(select 1 from public.ex_identity_verifications where id=p_verification_id) then raise exception using errcode='P0001',message='KYC_INVALID_ID'; end if;
  select count(*) into v_recent from public.ex_identity_verifications where user_id=v_uid and submitted_at>now()-interval '24 hours';
  if v_recent>=5 then raise exception using errcode='P0001',message='KYC_RATE_LIMIT'; end if;
  if p_document_type not in ('national_id','driving_license') then raise exception using errcode='P0001',message='KYC_DOCUMENT_TYPE_INVALID'; end if;
  v_name:=nullif(regexp_replace(btrim(coalesce(p_full_legal_name,'')),'[[:space:]]+',' ','g'),'');
  if v_name is null or char_length(v_name)<5 or char_length(v_name)>120 or array_length(regexp_split_to_array(v_name,' '),1)<>3 or v_name ~ '[0-9٠-٩۰-۹<>{}/@#$%^*=+_|~]' or position(chr(92) in v_name)>0 or position('[' in v_name)>0 or position(']' in v_name)>0 then raise exception using errcode='P0001',message='KYC_NAME_INVALID'; end if;
  if p_date_of_birth is null or p_date_of_birth<date '1900-01-01' or p_date_of_birth>(now() at time zone 'Asia/Baghdad')::date then raise exception using errcode='P0001',message='KYC_DOB_INVALID'; end if;
  v_number:=upper(regexp_replace(coalesce(p_document_number,''),'[[:space:]]','','g'));
  v_number:=translate(v_number,'٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789');
  if v_number !~ '^[A-Z0-9-]{4,30}$' then raise exception using errcode='P0001',message='KYC_NUMBER_INVALID'; end if;
  v_prefix:=v_uid::text||'/'||p_verification_id::text||'/';
  if p_front_path not in(v_prefix||'front.jpg',v_prefix||'front.png',v_prefix||'front.webp') then raise exception using errcode='P0001',message='KYC_FRONT_PATH_INVALID'; end if;
  if p_back_path is null or p_back_path not in(v_prefix||'back.jpg',v_prefix||'back.png',v_prefix||'back.webp') then raise exception using errcode='P0001',message='KYC_BACK_PATH_INVALID'; end if;
  if p_selfie_path is null or p_selfie_path not in(v_prefix||'selfie.jpg',v_prefix||'selfie.png',v_prefix||'selfie.webp') then raise exception using errcode='P0001',message='KYC_SELFIE_PATH_INVALID'; end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='identity-documents' and o.name=p_front_path and (o.owner_id=v_uid::text or o.owner=v_uid) and coalesce((o.metadata->>'size')::bigint,0)>0) then raise exception using errcode='P0001',message='KYC_FRONT_IMAGE_MISSING'; end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='identity-documents' and o.name=p_back_path and (o.owner_id=v_uid::text or o.owner=v_uid) and coalesce((o.metadata->>'size')::bigint,0)>0) then raise exception using errcode='P0001',message='KYC_BACK_IMAGE_MISSING'; end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='identity-documents' and o.name=p_selfie_path and (o.owner_id=v_uid::text or o.owner=v_uid) and coalesce((o.metadata->>'size')::bigint,0)>0) then raise exception using errcode='P0001',message='KYC_SELFIE_IMAGE_MISSING'; end if;
  select id into v_req_id from public.ex_kyc_requests where user_id=v_uid and status in('open','submitted') for update;
  select count(*) into v_prior from public.ex_identity_verifications where user_id=v_uid;
  insert into public.ex_identity_verifications(id,user_id,request_id,document_type,full_legal_name,date_of_birth,document_number,front_image_path,back_image_path,selfie_image_path,document_issue_date,document_expiry_date,status,submitted_at)
  values(p_verification_id,v_uid,v_req_id,p_document_type,v_name,p_date_of_birth,v_number,p_front_path,p_back_path,p_selfie_path,p_document_issue_date,p_document_expiry_date,'pending',now());
  insert into public.ex_identity_verification_face(verification_id,status) values(p_verification_id,'queued');
  if v_req_id is not null then update public.ex_kyc_requests set status='submitted' where id=v_req_id; end if;
  v_event:=case when v_prior>0 then 'resubmitted' else 'submitted' end;
  insert into public.ex_kyc_events(user_id,verification_id,request_id,event,actor_id,actor_role) values(v_uid,p_verification_id,v_req_id,v_event,v_uid,'user');
  return jsonb_build_object('id',p_verification_id,'status','pending','event',v_event);
exception when unique_violation then raise exception using errcode='P0001',message='KYC_ALREADY_PENDING';
end; $function$;

create or replace function public.ex_kyc_my_status() returns jsonb language plpgsql stable security definer set search_path to '' as $function$
declare v_uid uuid:=auth.uid(); s record; v_ver jsonb; v_verified text; v_prof record;
begin
  if v_uid is null then raise exception using errcode='42501',message='AUTH_REQUIRED'; end if;
  select * into s from public.ex_kyc_state(v_uid); select username,role,full_name into v_prof from public.ex_profiles where id=v_uid; v_verified:=public.ex_kyc_verified_name(v_uid);
  select jsonb_build_object('id',v.id,'status',v.status,'document_type',v.document_type,'full_legal_name',v.full_legal_name,'date_of_birth',v.date_of_birth,'document_number',v.document_number,'document_issue_date',v.document_issue_date,'document_expiry_date',v.document_expiry_date,'rejection_reason',v.rejection_reason,'submitted_at',v.submitted_at,'reviewed_at',v.reviewed_at,'has_back',v.back_image_path is not null,'has_selfie',v.selfie_image_path is not null) into v_ver from public.ex_identity_verifications v where v.id=s.verification_id;
  return jsonb_build_object('status',s.status,'can_submit',s.can_submit,'request',case when s.request_id is null then null else jsonb_build_object('id',s.request_id,'status',s.request_status,'reason',s.request_reason,'created_at',s.request_created_at) end,'verification',v_ver,'username',v_prof.username,'role',v_prof.role,'account_name',v_prof.full_name,'exchange_blocked',public.ex_kyc_exchange_blocked(v_uid),'name_locked',v_verified is not null,'verified_name',v_verified);
end; $function$;

create or replace function public.ex_admin_kyc_list(p_filter text default 'pending', p_query text default null, p_limit integer default 100) returns jsonb language plpgsql stable security definer set search_path to 'public' as $function$
declare v_filter text:=coalesce(nullif(p_filter,''),'pending'); v_q text:=nullif(btrim(coalesce(p_query,'')),''); v_limit int:=least(greatest(coalesce(p_limit,100),1),300); v_out jsonb;
begin
 perform public.ex_kyc_assert_admin(); if v_filter not in('required','pending','approved','rejected','all') then raise exception using errcode='P0001',message='KYC_FILTER_INVALID'; end if;
 select coalesce(jsonb_agg(x.item order by x.sort_at desc),'[]'::jsonb) into v_out from (select v.submitted_at sort_at,jsonb_build_object('kind','verification','id',v.id,'status',v.status,'document_type',v.document_type,'full_legal_name',v.full_legal_name,'account_name',p.full_name,'name_matches',public.ex_normalize_person_name(v.full_legal_name) is not distinct from public.ex_normalize_person_name(p.full_name),'exchange_blocked',public.ex_kyc_exchange_blocked(v.user_id),'date_of_birth',v.date_of_birth,'document_number',v.document_number,'front_image_path',v.front_image_path,'back_image_path',v.back_image_path,'selfie_image_path',v.selfie_image_path,'rejection_reason',v.rejection_reason,'submitted_at',v.submitted_at,'reviewed_at',v.reviewed_at,'reviewer',case when rv.id is null then null else jsonb_build_object('full_name',rv.full_name,'username',rv.username) end,'face',case when f.verification_id is null then null else jsonb_build_object('status',f.status,'face_detected',f.face_detected,'match_score',f.match_score,'error_code',f.error_code,'model',f.model,'processed_at',f.processed_at) end,'user',jsonb_build_object('id',p.id,'full_name',p.full_name,'username',p.username,'email',p.email)) item from public.ex_identity_verifications v join public.ex_profiles p on p.id=v.user_id left join public.ex_profiles rv on rv.id=v.reviewed_by left join public.ex_identity_verification_face f on f.verification_id=v.id where (v_filter='all' or v.status=v_filter) and (v_q is null or p.full_name ilike '%'||v_q||'%' or p.email ilike '%'||v_q||'%' or v.full_legal_name ilike '%'||v_q||'%' or v.document_number ilike '%'||v_q||'%') order by v.submitted_at desc limit v_limit) x;
 return v_out;
end; $function$;

create or replace function public.ex_admin_kyc_ocr_result(p_verification_id uuid) returns jsonb language plpgsql stable security definer set search_path to '' as $function$
declare v_result jsonb;
begin
 perform public.ex_kyc_assert_admin(); select jsonb_build_object('verification_id',v.id,'status',coalesce(o.status,'not_queued'),'is_identity_document',o.is_identity_document,'extracted_full_legal_name',o.extracted_full_legal_name,'extracted_date_of_birth',o.extracted_date_of_birth,'extracted_document_number',o.extracted_document_number,'extracted_document_type',o.extracted_document_type,'error_code',o.error_code,'model',o.model,'processed_at',o.processed_at,'submitted_full_legal_name',v.full_legal_name,'submitted_date_of_birth',v.date_of_birth,'submitted_document_number',v.document_number,'account_name',p.full_name) into v_result from public.ex_identity_verifications v join public.ex_profiles p on p.id=v.user_id left join public.ex_identity_verification_ocr o on o.verification_id=v.id where v.id=p_verification_id;
 return coalesce(v_result,jsonb_build_object('status','not_found'));
end; $function$;

revoke all on public.ex_identity_verification_face from anon;
revoke all on public.ex_identity_verification_face from authenticated;
