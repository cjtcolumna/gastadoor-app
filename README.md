# GastaDoor

A personal budget and spending tracker for iOS, built with **Flutter** and **Supabase**.

## Stack

| Concern | Choice |
| --- | --- |
| UI | Flutter (Material 3), iOS first, Android also builds |
| State | [Riverpod](https://riverpod.dev) (`flutter_riverpod`) |
| Navigation | `go_router` |
| Backend | Supabase (Postgres + Auth) via `supabase_flutter` |
| Models | `freezed` + `json_serializable` |
| Charts | `fl_chart` |
| Formatting | `intl` |

Money is always stored as **integer cents** (`int` in Dart, `bigint` in Postgres). Convert to pesos only for display (`lib/core/utils/money.dart`).

## Folder structure

```
lib/
  main.dart              # starts Supabase, then the app
  app.dart               # MaterialApp.router + theme
  core/
    config/env.dart      # values from --dart-define
    router/              # go_router routes
    supabase/            # Supabase init + client/auth providers
    theme/
    utils/money.dart     # cents <-> display helpers
  features/
    <feature>/
      domain/            # models (freezed)
      data/              # repositories that talk to Supabase
      presentation/      # screens and widgets
supabase/
  migrations/            # SQL schema with Row Level Security
test/
```

Each feature (accounts, categories, transactions, budgets, home) owns its own `domain`, `data` and `presentation` folders. Add new features the same way.

## Setup (Mac + VS Code)

### 1. Install tools

1. **Xcode** from the Mac App Store. Open it once, accept the license, then run:
   ```sh
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```
2. **CocoaPods**: `brew install cocoapods` (install [Homebrew](https://brew.sh) first if needed).
3. **Flutter SDK** (stable channel): follow <https://docs.flutter.dev/get-started/install/macos>. This project was created with Flutter 3.47 / Dart 3.13.
4. **VS Code** with the **Flutter** extension (VS Code will suggest it when you open the folder).
5. Check everything with `flutter doctor`. The Xcode and CocoaPods lines should be green.

### 2. Create a Supabase project

1. Create a project at <https://supabase.com/dashboard>.
2. Open **SQL Editor**, paste the contents of `supabase/migrations/20261021000000_initial_schema.sql`, and run it.
   (Or, with the [Supabase CLI](https://supabase.com/docs/guides/cli): `supabase link --project-ref <ref>` then `supabase db push`.)
3. In **Project Settings → API Keys**, copy the **Project URL** and the **publishable key** (`sb_publishable_...`).
   Never put the secret / `service_role` key in the app.

### 3. Add your keys locally

```sh
cp env.example.json env.json
```

Fill in `env.json`. It is listed in `.gitignore`, so it never gets committed.

### 4. Get packages and run

```sh
flutter pub get
open -a Simulator          # start an iOS simulator
flutter run --dart-define-from-file=env.json
```

In VS Code, just press **F5**. The included `.vscode/launch.json` already passes `--dart-define-from-file=env.json`.

Without `env.json` the app still starts and shows a "Supabase is not configured" card.

### Running on your iPhone

Open `ios/Runner.xcworkspace` in Xcode, select the **Runner** target → **Signing & Capabilities**, choose your Apple ID team, and change the bundle identifier if needed (currently `com.cjtcolumna.gastadoor`). Then plug in your phone and pick it as the device in VS Code or run `flutter run -d <device>`.

## Everyday commands

```sh
# Regenerate freezed / json_serializable code after changing a model
dart run build_runner build --delete-conflicting-outputs

flutter analyze
flutter test
```

Generated files (`*.freezed.dart`, `*.g.dart`) are committed so the app runs straight after `flutter pub get`.

## Database

`supabase/migrations/20261021000000_initial_schema.sql` creates:

- `accounts` (cash, bank, credit card, e-wallet), default currency PHP
- `categories` (expense or income, optional parent category)
- `transactions` (positive `amount_cents` plus `kind` = expense/income, `occurred_on` date)
- `budgets` (weekly/monthly/yearly limit, overall or per category)

Row Level Security is on for every table: a signed-in user can only read and write rows where `user_id` is their own id. `user_id` defaults to `auth.uid()`, so the app does not need to send it. Composite foreign keys also stop a user from linking a transaction to another user's account or category.

## Next steps

- Sign-in screen (Supabase Auth: email magic link or Sign in with Apple)
- Add / edit transactions
- Budgets screen with `fl_chart` progress charts
- Optional offline cache with Drift
