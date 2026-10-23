begin;
insert into auth.users(id,aud,role) values('11111111-1111-4111-8111-111111111111','authenticated','authenticated'),('22222222-2222-4222-8222-222222222222','authenticated','authenticated');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.pf_bootstrap();
select public.pf_action('checkin','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
select public.pf_action('checkin','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
select public.pf_action('checkin','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
select public.pf_action('expression','cccccccc-cccc-4ccc-8ccc-cccccccccccc');
select public.pf_action('expression','dddddddd-dddd-4ddd-8ddd-dddddddddddd');
do $$ begin
 if (select balance from public.pf_wallets where user_id='11111111-1111-4111-8111-111111111111')<>15 then raise exception 'wallet duplicate/cooldown test failed'; end if;
 if (select count(*) from public.pf_ledger where user_id='11111111-1111-4111-8111-111111111111')<>2 then raise exception 'ledger duplicate test failed'; end if;
end $$;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.pf_bootstrap();
set local role authenticated;
do $$ begin
 if (select count(*) from public.pf_wallets)<>1 then raise exception 'cross-user RLS failed'; end if;
 begin
  update public.pf_wallets set balance=99999;
  raise exception 'wallet write incorrectly allowed';
 exception when insufficient_privilege then null; end;
 if public.pf_is_admin() then raise exception 'ordinary user got admin'; end if;
end $$;
reset role;
rollback;
select 'PASS: idempotency, cooldown, checkin, wallet write protection, cross-user RLS' as result;
