# Wavely — Mobile Streaming & Offline Music Engine

A production-grade, Spotify-style music streaming and secure offline-download application built with Flutter, Riverpod, Supabase, Drift (SQLite), and just_audio.

---

## Architecture Overview

```
           ┌──────────────────────────────────────────────┐
           │                  Wavely App                  │
           │       (GoRouter Persistent ShellRoute)       │
           └──────────────────────┬───────────────────────┘
                                  │
         ┌────────────────────────┴────────────────────────┐
         ▼                                                 ▼
┌──────────────────┐                              ┌──────────────────┐
│   Presentation   │                              │   Controllers    │
│  Home / Search   │                              │   Riverpod       │
│  Library/Player  │◀─────────────────────────────│  StateNotifier   │
└──────────────────┘                              └────────┬─────────┘
                                                           │
                    ┌──────────────────────────────────────┴──────────────────────────────────────┐
                    ▼                                                                             ▼
         ┌─────────────────────┐                                                       ┌─────────────────────┐
         │     Local Store     │                                                       │   Remote Backend    │
         │    Drift (SQLite)   │                                                       │      Supabase       │
         │   Secure Storage    │                                                       │ (Auth, Postgres,    │
         │ (AES-CTR Nonces)    │                                                       │   Private Audio)    │
         └─────────────────────┘                                                       └─────────────────────┘
```

---

## Features Implemented

1. **Clean MVC + Riverpod Architecture**:
   - Explicit separation between Models, Controllers, Local DAOs, Remote Repositories, and Views.
2. **Persistent Mini Player & Shell Route**:
   - Uninterrupted audio playback across tab transitions (Home, Search, Library, Settings).
3. **Now Playing Sheet**:
   - Palette extraction from album art using `palette_generator`, seek slider, queue reordering, and shuffle/loop controls.
4. **Encrypted Offline Storage**:
   - Downloaded songs are encrypted with AES-256-CTR + HMAC-SHA256 and stored as opaque `<uuid>.dat` files with a `.nomedia` marker.
   - Keys are generated per-install and stored securely in Android Keystore / iOS Keychain.
5. **On-the-fly Decryption**:
   - Custom `EncryptedAudioSource` decrypts chunks directly in memory without ever writing decrypted files to disk.
6. **Supabase Database & Private Storage**:
   - Complete SQL migration with Row Level Security (RLS) policies for songs, playlists, and playlist-song junction tables.
   - Private `audio` storage bucket with short-lived (1 hour) signed URLs.
7. **Offline Mode & Sync**:
   - Automatic connectivity detection via `connectivity_plus`, showing offline indicators while serving downloaded content seamlessly.

---

## Supabase Setup Instructions

1. Navigate to your Supabase project dashboard.
2. Open the **SQL Editor** tab.
3. Paste and run the contents of [`supabase/migrations/20261015000000_initial_schema.sql`](supabase/migrations/20261015000000_initial_schema.sql).
4. Verify that:
   - Tables `songs`, `playlists`, and `playlist_songs` are created with RLS enabled.
   - The private storage bucket `audio` is created.

---

## Build & Release Optimization Commands

### Run with Environment Variables
```bash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### Production Release Build (Split per ABI & Obfuscated)
```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### Production App Bundle (Play Store)
```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### Run Tests & Analysis
```bash
flutter analyze
flutter test
```
