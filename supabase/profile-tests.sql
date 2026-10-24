begin;
insert into auth.users(id,aud,role) values
 ('33333333-3333-4333-8333-333333333333','authenticated','authenticated'),
 ('44444444-4444-4444-8444-444444444444','authenticated','authenticated'),
 ('55555555-5555-4555-8555-555555555555','authenticated','authenticated');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select public.pf_bootstrap();
insert into public.pf_admins values('33333333-3333-4333-8333-333333333333');
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
select public.pf_bootstrap();
select public.pf_update_profile('PF検証同名',true,'paper','none');
select public.pf_action('expression','11111111-aaaa-4aaa-8aaa-111111111111');
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
select public.pf_bootstrap();
select public.pf_update_profile('PF検証同名',true,'paper','none');
select public.pf_action('expression','22222222-aaaa-4aaa-8aaa-222222222222');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select public.pf_admin_grant('44444444-4444-4444-8444-444444444444',100,'テスト','33333333-aaaa-4aaa-8aaa-333333333333');
select public.pf_admin_grant('44444444-4444-4444-8444-444444444444',100,'テスト','33333333-aaaa-4aaa-8aaa-333333333333');
do $$ declare b jsonb; begin
 if (select balance from public.pf_wallets where user_id='44444444-4444-4444-8444-444444444444')<>105 then raise exception 'grant idempotency failed'; end if;
 if (select count(*) from public.pf_ledger where user_id='44444444-4444-4444-8444-444444444444' and reason='admin_test' and admin_actor='33333333-3333-4333-8333-333333333333')<>1 then raise exception 'audit failed'; end if;
 if jsonb_array_length(public.pf_admin_search('PF検証同名'))<>2 then raise exception 'nickname search failed'; end if;
 b:=public.pf_leaderboard();
 if (select count(*) from jsonb_array_elements(b->'entries') e where e->>'display_name'='PF検証同名' and (e->>'points')::int=5)<>2 then raise exception 'ranking includes test credits or loses duplicate nicknames'; end if;
 if exists(select 1 from jsonb_array_elements(b->'entries') e where e ? 'id' or e ? 'balance' or e ? 'user_id') then raise exception 'ranking leaks identity or wallet'; end if;
 if exists(select 1 from jsonb_array_elements(b->'entries') a,jsonb_array_elements(b->'entries') c where a->>'display_name'='PF検証同名' and c->>'display_name'='PF検証同名' and a->>'place'<>c->>'place') then raise exception 'tie ranking failed'; end if;
end $$;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
set local role authenticated;
do $$ begin
 begin
  perform public.pf_admin_grant('44444444-4444-4444-8444-444444444444',100,'不正','44444444-aaaa-4aaa-8aaa-444444444444');
  raise exception 'admin grant incorrectly allowed';
 exception when raise_exception then if sqlerrm<>'運営権限が必要です' then raise; end if; end;
 begin
  perform public.pf_admin_search('PF検証同名');raise exception 'admin search incorrectly allowed';
 exception when raise_exception then if sqlerrm<>'運営権限が必要です' then raise; end if; end;
 begin
  perform public.pf_update_profile('検証',true,'sky','none');raise exception 'locked item equipped';
 exception when raise_exception then if sqlerrm<>'この背景は交換所で入手できます' then raise; end if; end;
 begin
  update public.pf_wallets set balance=99999;raise exception 'wallet write allowed';
 exception when insufficient_privilege then null; end;
 if (select count(*) from public.pf_wallets)<>1 then raise exception 'wallet RLS failed'; end if;
end $$;
select public.pf_update_profile('PF検証同名',false,'paper','none');
do $$ begin
 if (select count(*) from jsonb_array_elements(public.pf_leaderboard()->'entries') e where (e->>'is_me')::boolean)<>0 then raise exception 'opt-out failed'; end if;
end $$;
reset role;
rollback;
select 'PASS: profile, duplicate nicknames, private ranking, ties, opt-out, audited idempotent grants, admin-only access, locked cosmetics, wallet RLS' as result;
