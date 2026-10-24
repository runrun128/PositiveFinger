create or replace function public.pf_admin_search(p_query text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare q text:=btrim(coalesce(p_query,'')); begin
 if auth.uid() is null or not public.pf_is_admin() then raise exception '運営権限が必要です'; end if;
 perform public.pf_require_user();
 if char_length(q)>40 then raise exception '検索は40文字以内で入力してください'; end if;
 return coalesce((select jsonb_agg(x) from (
  select p.id,p.display_name,p.suspended,p.created_at,coalesce(w.balance,0) as balance
  from public.pf_profiles p left join public.pf_wallets w on w.user_id=p.id
  where q='' or strpos(lower(p.display_name),lower(q))>0 or strpos(p.id::text,lower(q))>0
  order by p.created_at desc,p.id limit 50
 )x),'[]'::jsonb);
end $$;
revoke all on function public.pf_admin_search(text) from public,anon;
grant execute on function public.pf_admin_search(text) to authenticated;
