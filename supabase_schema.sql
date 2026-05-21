-- Supabase Database Schema for NOTERAT
-- Copy and run this script in the Supabase SQL Editor.

-- Enable UUID extension if not enabled
create extension if not exists "uuid-ossp";

-- =========================================================================
-- CLEANUP (Uncomment to reset schema completely)
-- =========================================================================
-- drop table if exists public.document_updates cascade;
-- drop table if exists public.notes cascade;
-- drop table if exists public.group_members cascade;
-- drop table if exists public.groups cascade;
-- drop table if exists public.profiles cascade;

-- =========================================================================
-- 1. TABLE DEFINITIONS
-- =========================================================================

-- Profiles Table
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Groups Table
create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code varchar(6) not null unique,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Group Members Table
create table if not exists public.group_members (
  group_id uuid references public.groups(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  nickname text not null,
  joined_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (group_id, user_id)
);

-- Notes Table
create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references public.groups(id) on delete cascade not null,
  title text not null default 'Untitled Note',
  snippet text not null default '',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Document Updates Table (CRDT updates logs)
create table if not exists public.document_updates (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references public.groups(id) on delete cascade,
  note_id uuid references public.notes(id) on delete cascade, -- Linked to notes table
  client_id uuid not null,
  update_blob text not null, -- JSON string containing serialized list of CRDT updates
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Indexing for performance
create index if not exists idx_document_updates_note_id on public.document_updates(note_id);
create index if not exists idx_notes_group_id on public.notes(group_id);

-- =========================================================================
-- Helper Function for RLS (Bypasses RLS to Avoid Infinite Recursion)
-- =========================================================================
create or replace function public.is_group_member(group_id uuid, user_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_members.group_id = $1
    and group_members.user_id = $2
  );
$$;

-- =========================================================================
-- 2. ENABLE ROW LEVEL SECURITY
-- =========================================================================
alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.notes enable row level security;
alter table public.document_updates enable row level security;

-- =========================================================================
-- 3. POLICIES CREATION (Drop old ones first to allow clean overwriting)
-- =========================================================================

-- Drop existing policies to prevent conflicts
drop policy if exists "Allow public read access to profiles" on public.profiles;
drop policy if exists "Allow users to insert their own profile" on public.profiles;
drop policy if exists "Allow users to update their own profile" on public.profiles;

drop policy if exists "Allow authenticated users to create groups" on public.groups;
drop policy if exists "Allow members to read group info" on public.groups;

drop policy if exists "Allow authenticated users to join groups" on public.group_members;
drop policy if exists "Allow members to view group members" on public.group_members;
drop policy if exists "Allow members to leave groups" on public.group_members;

drop policy if exists "Allow members to view notes" on public.notes;
drop policy if exists "Allow members to insert notes" on public.notes;
drop policy if exists "Allow members to update notes" on public.notes;
drop policy if exists "Allow members to delete notes" on public.notes;

drop policy if exists "Allow group members to insert document updates" on public.document_updates;
drop policy if exists "Allow group members to read document updates" on public.document_updates;

-- Create policies for profiles
create policy "Allow public read access to profiles" 
  on public.profiles for select 
  using (true);

create policy "Allow users to insert their own profile" 
  on public.profiles for insert 
  with check (auth.uid() = id);

create policy "Allow users to update their own profile" 
  on public.profiles for update 
  using (auth.uid() = id);

-- Create policies for groups
create policy "Allow authenticated users to create groups" 
  on public.groups for insert 
  with check (auth.role() = 'authenticated');

create policy "Allow members to read group info" 
  on public.groups for select 
  using (auth.role() = 'authenticated');

-- Create policies for group_members
create policy "Allow authenticated users to join groups"
  on public.group_members for insert
  with check (auth.uid() = user_id);

create policy "Allow members to view group members"
  on public.group_members for select
  using (
    public.is_group_member(group_id, auth.uid())
  );

create policy "Allow members to leave groups"
  on public.group_members for delete
  using (auth.uid() = user_id);

-- Create policies for notes
create policy "Allow members to view notes"
  on public.notes for select
  using (
    public.is_group_member(group_id, auth.uid())
  );

create policy "Allow members to insert notes"
  on public.notes for insert
  with check (
    public.is_group_member(group_id, auth.uid())
  );

create policy "Allow members to update notes"
  on public.notes for update
  using (
    public.is_group_member(group_id, auth.uid())
  );

create policy "Allow members to delete notes"
  on public.notes for delete
  using (
    public.is_group_member(group_id, auth.uid())
  );

-- Create policies for document_updates
create policy "Allow group members to insert document updates"
  on public.document_updates for insert
  with check (
    public.is_group_member(group_id, auth.uid())
  );

create policy "Allow group members to read document updates"
  on public.document_updates for select
  using (
    public.is_group_member(group_id, auth.uid())
  );

-- =========================================================================
-- 4. REALTIME CONFIGURATION
-- =========================================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' 
    and schemaname = 'public' 
    and tablename = 'document_updates'
  ) then
    alter publication supabase_realtime add table public.document_updates;
  end if;

  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' 
    and schemaname = 'public' 
    and tablename = 'group_members'
  ) then
    alter publication supabase_realtime add table public.group_members;
  end if;

  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' 
    and schemaname = 'public' 
    and tablename = 'groups'
  ) then
    alter publication supabase_realtime add table public.groups;
  end if;

  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' 
    and schemaname = 'public' 
    and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;

  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' 
    and schemaname = 'public' 
    and tablename = 'notes'
  ) then
    alter publication supabase_realtime add table public.notes;
  end if;
end $$;

-- =========================================================================
-- 5. MIGRATION — Rich Text, Pinning & Comments (run once, safe to re-run)
-- =========================================================================

-- Add pinning to notes
alter table public.notes
  add column if not exists is_pinned boolean not null default false;

-- Comments table
create table if not exists public.note_comments (
  id uuid primary key default gen_random_uuid(),
  note_id uuid references public.notes(id) on delete cascade not null,
  group_id uuid references public.groups(id) on delete cascade not null,
  user_id uuid references public.profiles(id) on delete cascade not null,
  nickname text not null,
  content text not null,
  mentioned_users text[] default '{}',
  created_at timestamp with time zone default timezone('utc', now()) not null
);

create index if not exists idx_note_comments_note_id on public.note_comments(note_id);

alter table public.note_comments enable row level security;

drop policy if exists "Members can read comments" on public.note_comments;
drop policy if exists "Members can insert comments" on public.note_comments;
drop policy if exists "Author can delete own comment" on public.note_comments;

create policy "Members can read comments"
  on public.note_comments for select
  using (public.is_group_member(group_id, auth.uid()));

create policy "Members can insert comments"
  on public.note_comments for insert
  with check (auth.uid() = user_id and public.is_group_member(group_id, auth.uid()));

create policy "Author can delete own comment"
  on public.note_comments for delete
  using (auth.uid() = user_id);

-- Realtime for comments
do $$
begin
  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' 
    and schemaname = 'public' 
    and tablename = 'note_comments'
  ) then
    alter publication supabase_realtime add table public.note_comments;
  end if;
end $$;
