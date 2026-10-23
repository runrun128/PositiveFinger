-- PositiveFinger cloud prototype. All writes to wallets go through authenticated RPCs.
create table public.pf_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default 'ことばの冒険者' check (char_length(display_name) between 1 and 24),
 suspended boolean not null default false,
 created_at timestamptz not null default now()
);
create table public.pf_admins (user_id uuid primary key references auth.users(id) on delete cascade);
create table public.pf_wallets (
 user_id uuid primary key references public.pf_profiles(id) on delete cascade,
 balance integer not null default 0 check(balance>=0),
 earned_day date, daily_earned integer not null default 0,
 last_reward_at timestamptz, streak integer not null default 0, checkin_day date
);
create table public.pf_ledger (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.pf_profiles(id) on delete cascade,
 request_id uuid not null, reason text not null, amount integer not null,
 created_at timestamptz not null default now(), unique(user_id,request_id)
);
create index pf_ledger_user_date on public.pf_ledger(user_id,created_at desc);
create table public.pf_inventory (
 user_id uuid references public.pf_profiles(id) on delete cascade,
 item_id text not null, quantity integer not null default 1 check(quantity>0), primary key(user_id,item_id)
);
create table public.pf_announcements (
 id uuid primary key default gen_random_uuid(), title text not null check(char_length(title) between 1 and 80),
 body text not null check(char_length(body) between 1 and 3000), kind text not null default 'お知らせ',
 published boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.pf_events (
 id uuid primary key default gen_random_uuid(), title text not null check(char_length(title) between 1 and 80),
 description text not null default '', goal integer not null check(goal>0), progress integer not null default 0,
 reward integer not null default 25 check(reward between 0 and 1000),
 starts_at timestamptz not null, ends_at timestamptz not null, published boolean not null default false,
 check(ends_at>starts_at)
);
create table public.pf_event_members (
 event_id uuid references public.pf_events(id) on delete cascade, user_id uuid references public.pf_profiles(id) on delete cascade,
 contribution integer not null default 0, claimed boolean not null default false, primary key(event_id,user_id)
);
create table public.pf_mission_claims (
 user_id uuid references public.pf_profiles(id) on delete cascade, day date not null, mission text not null,
 primary key(user_id,day,mission)
);

create function public.pf_is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.pf_admins where user_id=auth.uid());
$$;
create function public.pf_require_user() returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); begin
 if u is null then raise exception 'ログインしてください'; end if;
 insert into public.pf_profiles(id) values(u) on conflict do nothing;
 if exists(select 1 from public.pf_profiles where id=u and suspended) then raise exception 'このアカウントは停止中です'; end if;
 insert into public.pf_wallets(user_id) values(u) on conflict do nothing;
 return u;
end $$;

alter table public.pf_profiles enable row level security;
alter table public.pf_admins enable row level security;
alter table public.pf_wallets enable row level security;
alter table public.pf_ledger enable row level security;
alter table public.pf_inventory enable row level security;
alter table public.pf_announcements enable row level security;
alter table public.pf_events enable row level security;
alter table public.pf_event_members enable row level security;
alter table public.pf_mission_claims enable row level security;
create policy profiles_read on public.pf_profiles for select to authenticated using(id=auth.uid() or public.pf_is_admin());
create policy profiles_admin on public.pf_profiles for update to authenticated using(public.pf_is_admin()) with check(public.pf_is_admin());
create policy wallets_read on public.pf_wallets for select to authenticated using(user_id=auth.uid() or public.pf_is_admin());
create policy ledger_read on public.pf_ledger for select to authenticated using(user_id=auth.uid() or public.pf_is_admin());
create policy inventory_read on public.pf_inventory for select to authenticated using(user_id=auth.uid() or public.pf_is_admin());
create policy announcements_read on public.pf_announcements for select to authenticated using(published or public.pf_is_admin());
create policy announcements_admin on public.pf_announcements for all to authenticated using(public.pf_is_admin()) with check(public.pf_is_admin());
create policy events_read on public.pf_events for select to authenticated using(published or public.pf_is_admin());
create policy events_admin on public.pf_events for insert to authenticated with check(public.pf_is_admin());
-- Progress is never writable from the admin browser; edit campaign content only.
create policy events_admin_update on public.pf_events for update to authenticated using(public.pf_is_admin()) with check(public.pf_is_admin());
create policy members_read on public.pf_event_members for select to authenticated using(user_id=auth.uid() or public.pf_is_admin());
create policy missions_read on public.pf_mission_claims for select to authenticated using(user_id=auth.uid());
revoke all on public.pf_admins,public.pf_profiles,public.pf_wallets,public.pf_ledger,public.pf_inventory,public.pf_announcements,public.pf_events,public.pf_event_members,public.pf_mission_claims from anon,authenticated;
grant select on public.pf_profiles,public.pf_wallets,public.pf_ledger,public.pf_inventory,public.pf_announcements,public.pf_events,public.pf_event_members,public.pf_mission_claims to authenticated;
grant update(display_name,suspended) on public.pf_profiles to authenticated;
grant insert,update,delete on public.pf_announcements to authenticated;
grant insert on public.pf_events to authenticated;
grant update(title,description,goal,reward,starts_at,ends_at,published) on public.pf_events to authenticated;

create function public.pf_action(p_action text,p_request uuid,p_item text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=public.pf_require_user(); w public.pf_wallets; day_jst date:=(now() at time zone 'Asia/Tokyo')::date;
 delta integer:=0; cost integer; prize text; mission text; target integer; event public.pf_events; member public.pf_event_members; result jsonb;
begin
 select * into w from public.pf_wallets where user_id=u for update;
 if exists(select 1 from public.pf_ledger where user_id=u and request_id=p_request) then
   return jsonb_build_object('balance',w.balance,'duplicate',true,'item',(select reason from public.pf_ledger where user_id=u and request_id=p_request));
 end if;
 if w.earned_day is distinct from day_jst then w.daily_earned:=0; end if;
 if p_action='expression' then
   if w.daily_earned>=100 or (w.last_reward_at is not null and now()-w.last_reward_at<interval '30 seconds') then
     return jsonb_build_object('balance',w.balance,'awarded',false,'capped',w.daily_earned>=100);
   end if;
   delta:=5; w.daily_earned:=w.daily_earned+5; w.last_reward_at:=now();
   -- Update campaigns in a stable order to avoid deadlocks across different wallets.
   for event in select e.* from public.pf_events e join public.pf_event_members m on m.event_id=e.id and m.user_id=u
      where e.published and now() between e.starts_at and e.ends_at order by e.id for update of e loop
     update public.pf_events set progress=progress+1 where id=event.id;
     update public.pf_event_members set contribution=contribution+1 where event_id=event.id and user_id=u;
   end loop;
 elsif p_action='checkin' then
   if w.checkin_day=day_jst then return jsonb_build_object('balance',w.balance,'awarded',false); end if;
   w.streak:=case when w.checkin_day=day_jst-1 then w.streak+1 else 1 end;
   w.checkin_day:=day_jst; delta:=10;
 elsif p_action='mission' then
   if p_item='first_word' then target:=5; delta:=10;
   elsif p_item='five_words' then target:=25; delta:=20;
   else raise exception 'ミッションが見つかりません'; end if;
   if w.daily_earned<target then raise exception 'まだ達成していません'; end if;
   insert into public.pf_mission_claims values(u,day_jst,p_item) on conflict do nothing;
   if not found then return jsonb_build_object('balance',w.balance,'awarded',false); end if;
 elsif p_action='gacha' then
   cost:=25; prize:=(array['momo','soda','lemon','mint','lilac','peach'])[floor(random()*6)::int+1];
   if w.balance<cost then raise exception 'ポイントが足りません'; end if;
   delta:=-cost;
   insert into public.pf_inventory values(u,prize,1) on conflict(user_id,item_id) do update set quantity=public.pf_inventory.quantity+1;
 elsif p_action='exchange' then
   cost:=case p_item when 'sky' then 100 when 'wordfriend' then 50 else null end;
   if cost is null then raise exception '交換アイテムが見つかりません'; end if;
   if w.balance<cost then raise exception 'ポイントが足りません'; end if;
   if exists(select 1 from public.pf_inventory where user_id=u and item_id=p_item) then raise exception '交換済みです'; end if;
   insert into public.pf_inventory values(u,p_item,1); delta:=-cost; prize:=p_item;
 elsif p_action='join_event' then
   select * into event from public.pf_events where id=p_item::uuid and published and now() between starts_at and ends_at for share;
   if not found then raise exception 'イベントは開催されていません'; end if;
   insert into public.pf_event_members(event_id,user_id) values(event.id,u) on conflict do nothing;
 elsif p_action='claim_event' then
   select * into event from public.pf_events where id=p_item::uuid and published for share;
   if not found or event.progress<event.goal then raise exception '目標達成前です'; end if;
   select * into member from public.pf_event_members where event_id=event.id and user_id=u for update;
   if not found or member.claimed or member.contribution<1 then raise exception '報酬を受け取れません'; end if;
   update public.pf_event_members set claimed=true where event_id=event.id and user_id=u; delta:=event.reward;
 else raise exception '無効な操作です'; end if;
 update public.pf_wallets set balance=w.balance+delta,earned_day=day_jst,daily_earned=w.daily_earned,
   last_reward_at=w.last_reward_at,streak=w.streak,checkin_day=w.checkin_day where user_id=u;
 insert into public.pf_ledger(user_id,request_id,reason,amount) values(u,p_request,coalesce(prize,p_action),delta);
 return jsonb_build_object('balance',w.balance+delta,'awarded',delta>0,'item',prize);
end $$;

create function public.pf_bootstrap() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=public.pf_require_user(); begin
 return jsonb_build_object('profile',(select to_jsonb(p) from public.pf_profiles p where id=u),
 'wallet',(select to_jsonb(w) from public.pf_wallets w where user_id=u),
 'inventory',coalesce((select jsonb_agg(i) from public.pf_inventory i where user_id=u),'[]'::jsonb),
 'announcements',coalesce((select jsonb_agg(a order by a.updated_at desc) from public.pf_announcements a where a.published),'[]'::jsonb),
 'events',coalesce((select jsonb_agg(e order by e.starts_at) from public.pf_events e where e.published),'[]'::jsonb),
 'memberships',coalesce((select jsonb_agg(m) from public.pf_event_members m where m.user_id=u),'[]'::jsonb),
 'missions',coalesce((select jsonb_agg(c.mission) from public.pf_mission_claims c where c.user_id=u and c.day=(now() at time zone 'Asia/Tokyo')::date),'[]'::jsonb));
end $$;
revoke all on function public.pf_require_user(),public.pf_is_admin(),public.pf_bootstrap(),public.pf_action(text,uuid,text) from public,anon;
grant execute on function public.pf_is_admin(),public.pf_bootstrap(),public.pf_action(text,uuid,text) to authenticated;
-- Enable server-pushed updates. No text entered on the keyboard is stored in these tables.
alter publication supabase_realtime add table public.pf_announcements,public.pf_events,public.pf_wallets;
