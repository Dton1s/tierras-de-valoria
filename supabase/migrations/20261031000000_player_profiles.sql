-- Run this migration in the Supabase SQL Editor before signing in from the game.
create table if not exists public.player_profiles (
    user_id uuid primary key references auth.users (id) on delete cascade,
    nickname text not null check (nickname ~ '^[A-Za-z0-9]{4,12}$'),
    hero_id text not null default '',
    hero_name text not null default '',
    onboarding_complete boolean not null default false,
    hero_level integer not null default 1 check (hero_level >= 1),
    coins bigint not null default 500 check (coins >= 0),
    tickets integer not null default 10 check (tickets >= 0),
    diamonds bigint not null default 100 check (diamonds >= 0),
    premium_tickets integer not null default 1 check (premium_tickets >= 0),
    xp bigint not null default 0 check (xp >= 0),
    summons integer not null default 0 check (summons >= 0),
    owned_heroes jsonb not null default '[]'::jsonb,
    last_seen bigint not null default extract(epoch from now())::bigint,
    last_coin_claim bigint not null default extract(epoch from now())::bigint,
    last_xp_claim bigint not null default extract(epoch from now())::bigint,
    updated_at timestamptz not null default now()
);

create unique index if not exists player_profiles_nickname_unique_idx
    on public.player_profiles (lower(nickname));

alter table public.player_profiles enable row level security;
grant select, insert, update on public.player_profiles to authenticated;

drop policy if exists "Players can read their own profile" on public.player_profiles;
create policy "Players can read their own profile"
    on public.player_profiles for select to authenticated
    using ((select auth.uid()) = user_id);

drop policy if exists "Players can create their own profile" on public.player_profiles;
create policy "Players can create their own profile"
    on public.player_profiles for insert to authenticated
    with check ((select auth.uid()) = user_id);

drop policy if exists "Players can update their own profile" on public.player_profiles;
create policy "Players can update their own profile"
    on public.player_profiles for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);

create or replace function public.set_player_profiles_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists player_profiles_updated_at on public.player_profiles;
create trigger player_profiles_updated_at
    before update on public.player_profiles
    for each row execute function public.set_player_profiles_updated_at();
