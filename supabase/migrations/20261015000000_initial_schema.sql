-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. Songs Table
create table if not exists public.songs (
    id uuid primary key default uuid_generate_v4(),
    title text not null,
    artist text not null,
    album text not null,
    duration_ms integer not null default 0,
    cover_url text not null,
    storage_path text not null,
    file_hash text not null default '',
    genre text default 'General',
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Playlists Table
create table if not exists public.playlists (
    id uuid primary key default uuid_generate_v4(),
    owner_id uuid references auth.users(id) on delete cascade not null,
    name text not null,
    cover_url text,
    is_liked_songs boolean default false not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Playlist Songs Junction Table
create table if not exists public.playlist_songs (
    playlist_id uuid references public.playlists(id) on delete cascade not null,
    song_id uuid references public.songs(id) on delete cascade not null,
    position integer not null default 0,
    added_at timestamp with time zone default timezone('utc'::text, now()) not null,
    primary key (playlist_id, song_id)
);

-- Indexes for high performance
create index if not exists idx_songs_title on public.songs(title);
create index if not exists idx_songs_artist on public.songs(artist);
create index if not exists idx_songs_album on public.songs(album);
create index if not exists idx_playlists_owner on public.playlists(owner_id);
create index if not exists idx_playlist_songs_playlist on public.playlist_songs(playlist_id);

-- Enable Row Level Security (RLS)
alter table public.songs enable row level security;
alter table public.playlists enable row level security;
alter table public.playlist_songs enable row level security;

-- RLS Policies
-- Songs: All authenticated users can view songs
create policy "Authenticated users can view songs"
    on public.songs for select
    to authenticated
    using (true);

-- Playlists: Users can only view and manage their own playlists
create policy "Users can view their own playlists"
    on public.playlists for select
    to authenticated
    using (auth.uid() = owner_id);

create policy "Users can insert their own playlists"
    on public.playlists for insert
    to authenticated
    with check (auth.uid() = owner_id);

create policy "Users can update their own playlists"
    on public.playlists for update
    to authenticated
    using (auth.uid() = owner_id);

create policy "Users can delete their own playlists"
    on public.playlists for delete
    to authenticated
    using (auth.uid() = owner_id);

-- Playlist Songs: Users can only access songs in playlists they own
create policy "Users can view songs in their own playlists"
    on public.playlist_songs for select
    to authenticated
    using (
        exists (
            select 1 from public.playlists
            where public.playlists.id = public.playlist_songs.playlist_id
            and public.playlists.owner_id = auth.uid()
        )
    );

create policy "Users can insert songs into their own playlists"
    on public.playlist_songs for insert
    to authenticated
    with check (
        exists (
            select 1 from public.playlists
            where public.playlists.id = public.playlist_songs.playlist_id
            and public.playlists.owner_id = auth.uid()
        )
    );

create policy "Users can delete songs from their own playlists"
    on public.playlist_songs for delete
    to authenticated
    using (
        exists (
            select 1 from public.playlists
            where public.playlists.id = public.playlist_songs.playlist_id
            and public.playlists.owner_id = auth.uid()
        )
    );

create policy "Users can update song order in their own playlists"
    on public.playlist_songs for update
    to authenticated
    using (
        exists (
            select 1 from public.playlists
            where public.playlists.id = public.playlist_songs.playlist_id
            and public.playlists.owner_id = auth.uid()
        )
    );

-- Storage bucket 'audio' (Private bucket setup instructions in README)
-- Insert an initial private storage bucket if not existing
insert into storage.buckets (id, name, public)
values ('audio', 'audio', false)
on conflict (id) do nothing;

create policy "Authenticated users can read audio bucket via signed URL"
    on storage.objects for select
    to authenticated
    using (bucket_id = 'audio');
