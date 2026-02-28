# MindSort

> Voice-first AI note organizer that automatically categorizes your thoughts.  
> "Speak naturally. Your thoughts sort themselves."

## First Part: Architecture & Auth

This initial setup includes:

- **Core/** – Theme, Types (`SyncStatus`, `Category`, `Entry`), `AppStore` (`@Observable`)
- **Services/** – AuthService (Supabase), SupabaseConfig (plist + env)
- **Views/** – AuthView (Sign In / Sign Up), RootView (auth flow routing)

### Setup

1. **Supabase (environment variables)**  
   In Xcode: **Product → Edit Scheme → Run → Arguments** tab → **Environment Variables**, add:
   - `SUPABASE_URL` = `https://xxxx.supabase.co`
   - `SUPABASE_ANON_KEY` = your anon key from Project Settings → API

2. **Signing**  
   Select a development team in Xcode: target → Signing & Capabilities.

3. **Build & run**  
   Open the project in Xcode and run (Cmd+R).

### Tech Stack

| Layer     | Technology                         |
|-----------|------------------------------------|
| UI        | SwiftUI (iOS 17+)                  |
| State     | `@Observable` macro                |
| Local DB  | SwiftData (schema to be extended)  |
| Auth      | Supabase                           |
| AI (later)| OpenAI GPT-4o-mini, embeddings     |

### Project Structure

```
Mindsortapp/
├── Core/
│   ├── Theme/Theme.swift
│   ├── Types/Models.swift
│   └── State/AppStore.swift
├── Services/
│   ├── API/AuthService.swift
│   └── Config/SupabaseConfig.swift
├── Views/
│   ├── Auth/AuthView.swift
│   └── RootView.swift
└── MindsortappApp.swift
```
