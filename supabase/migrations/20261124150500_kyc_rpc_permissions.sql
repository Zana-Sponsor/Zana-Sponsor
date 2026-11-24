revoke execute on function public.ex_kyc_submit(uuid,text,text,date,text,text,text,date,date) from anon;
revoke execute on function public.ex_kyc_submit(uuid,text,text,date,text,text,text,date,date,text) from anon;
revoke execute on function public.ex_kyc_my_status() from anon;
revoke execute on function public.ex_admin_kyc_list(text,text,integer) from anon;
revoke execute on function public.ex_admin_kyc_review(uuid,text,text,boolean) from anon;
revoke execute on function public.ex_admin_kyc_ocr_result(uuid) from anon;
revoke execute on function public.ex_admin_kyc_ocr_retry(uuid) from anon;

grant execute on function public.ex_kyc_submit(uuid,text,text,date,text,text,text,date,date) to authenticated;
grant execute on function public.ex_kyc_submit(uuid,text,text,date,text,text,text,date,date,text) to authenticated;
grant execute on function public.ex_kyc_my_status() to authenticated;
grant execute on function public.ex_admin_kyc_list(text,text,integer) to authenticated;
grant execute on function public.ex_admin_kyc_review(uuid,text,text,boolean) to authenticated;
grant execute on function public.ex_admin_kyc_ocr_result(uuid) to authenticated;
grant execute on function public.ex_admin_kyc_ocr_retry(uuid) to authenticated;
