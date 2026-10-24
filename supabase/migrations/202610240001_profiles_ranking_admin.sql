begin;
alter table public.pf_profiles
 add column if not exists nickname_set boolean not null default false,
 add column if not exists leaderboard_opt_in boolean not null default false,
 add column if not exists background text not null default 'paper',
 add column if not exists title text not null default 'none';
alter table public.pf_ledger
 add column if not exists admin_actor uuid references public.pf_profiles(id) on delete set null,
 add column if not exists admin_note text;
create index if not exists pf_ledger_expression_score on public.pf_ledger(user_id) include(amount) where reason='expression';

create or replace function public.pf_update_profile(p_name text,p_ranking boolean,p_background text,p_title text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=public.pf_require_user(); n text:=btrim(p_name); begin
 if n is null or char_length(n) not between 2 and 16 or n~'[[:cntrl:]]' then raise exception 'ニックネームは2〜16文字で入力してください'; end if;
 if p_ranking is null or p_background is null or p_title is null then raise exception '設定を確認してください'; end if;
 if p_background not in ('paper','sky') or p_title not in ('none','wordfriend') then raise exception '設定が見つかりません'; end if;
 if p_background='sky' and not exists(select 1 from public.pf_inventory where user_id=u and item_id='sky') then raise exception 'この背景は交換所で入手できます'; end if;
 if p_title='wordfriend' and not exists(select 1 from public.pf_inventory where user_id=u and item_id='wordfriend') then raise exception 'この称号は交換所で入手できます'; end if;
 update public.pf_profiles set display_name=n,nickname_set=true,leaderboard_opt_in=p_ranking,background=p_background,title=p_title where id=u;
 return (select to_jsonb(p) from public.pf_profiles p where id=u);
end $$;

-- Expose only opted-in nicknames/scores. Never return another member's ID or balance.
create or replace function public.pf_leaderboard() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=public.pf_require_user(); result jsonb; begin
 with scores as (
 select p.id,p.display_name,coalesce(sum(l.amount),0)::bigint as points
 from public.pf_profiles p left join public.pf_ledger l on l.user_id=p.id and l.reason='expression' and l.amount>0
 where p.leaderboard_opt_in and p.nickname_set and not p.suspended group by p.id,p.display_name
 ), ranked as (select *,dense_rank() over(order by points desc) as place from scores)
 select jsonb_build_object('entries',coalesce((select jsonb_agg(jsonb_build_object('place',x.place,'display_name',x.display_name,'points',x.points,'is_me',x.id=u) order by x.points desc,x.display_name,x.id)
 from (select * from ranked order by points desc,display_name,id limit 50) x),'[]'::jsonb),
 'me',(select jsonb_build_object('place',r.place,'display_name',r.display_name,'points',r.points,'is_me',true) from ranked r where r.id=u)) into result;
 return result;
end $$;

create or replace function public.pf_admin_grant(p_user uuid,p_amount integer,p_note text,p_request uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); w public.pf_wallets; prior public.pf_ledger; begin
 if actor is null or not public.pf_is_admin() then raise exception '運営権限が必要です'; end if;
 perform public.pf_require_user();
 if p_amount is null or p_amount not between 1 and 10000 or p_request is null then raise exception '付与は1〜10,000 ptで指定してください'; end if;
 if p_note is null or char_length(btrim(p_note)) not between 1 and 120 then raise exception 'テストの目的を入力してください'; end if;
 if not exists(select 1 from public.pf_profiles where id=p_user and not suspended) then raise exception '対象アカウントを確認してください'; end if;
 select * into w from public.pf_wallets where user_id=p_user for update;
 if not found then raise exception '対象の残高が見つかりません'; end if;
 select * into prior from public.pf_ledger where user_id=p_user and request_id=p_request;
 if found then
  if prior.reason<>'admin_test' or prior.amount<>p_amount or prior.admin_actor<>actor or prior.admin_note<>btrim(p_note) then raise exception '前の操作と内容が違います'; end if;
  return jsonb_build_object('balance',w.balance,'duplicate',true);
 end if;
 if w.balance>1000000-p_amount then raise exception 'テスト残高の上限を超えます'; end if;
 update public.pf_wallets set balance=balance+p_amount where user_id=p_user;
 insert into public.pf_ledger(user_id,request_id,reason,amount,admin_actor,admin_note) values(p_user,p_request,'admin_test',p_amount,actor,btrim(p_note));
 return jsonb_build_object('balance',w.balance+p_amount,'duplicate',false);
end $$;
revoke all on function public.pf_update_profile(text,boolean,text,text),public.pf_leaderboard(),public.pf_admin_grant(uuid,integer,text,uuid) from public,anon;
grant execute on function public.pf_update_profile(text,boolean,text,text),public.pf_leaderboard(),public.pf_admin_grant(uuid,integer,text,uuid) to authenticated;
commit;
