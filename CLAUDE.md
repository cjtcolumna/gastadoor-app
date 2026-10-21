# GastaDoor: notes for Claude

GastaDoor is a personal budget and spending tracker. It is an iOS-first Flutter app with a Supabase backend (Postgres + Auth).

**Dev setup:** Jade works on a **Windows PC with VS Code** and has an **iPhone, but no Mac**. Day to day, test in Chrome on the PC, and on the iPhone through Safari (Flutter web served over the local Wi-Fi). Native iOS builds go through a cloud Mac build service (for example Codemagic) and TestFlight. Avoid features that only work natively on iOS until that pipeline is set up, or say clearly when something can't be tested on web.

The owner, Jade, is a beginner who is **learning Flutter while vibe coding**. Teaching is part of every task. Read the "Teach me" section below before you change anything.

## Stack

- **Flutter** (Material 3) and **Dart** 3.13
- **Riverpod** (`flutter_riverpod`) for state
- **go_router** for navigation
- **supabase_flutter** for the database and sign-in
- **freezed** + **json_serializable** for data models (generated code)
- **fl_chart** for charts, **intl** for money and date formatting

## Folder structure

```
lib/
  main.dart              # starts Supabase, then runs the app
  app.dart               # MaterialApp.router + theme
  core/
    config/env.dart      # values passed in with --dart-define
    router/              # go_router routes
    supabase/            # Supabase setup + Riverpod providers for client/auth
    theme/               # colors and text styles
    utils/money.dart     # cents <-> display helpers
  features/
    <feature>/           # accounts, budgets, categories, home, transactions
      domain/            # models (freezed classes)
      data/              # repositories that talk to Supabase
      presentation/      # screens and widgets
supabase/migrations/     # SQL schema, with Row Level Security
test/                    # unit and widget tests
```

New features follow the same `domain / data / presentation` layout inside `lib/features/<feature>/`.

## Commands

```sh
flutter pub get                                   # install packages
flutter run -d chrome --dart-define-from-file=env.json   # run the app in Chrome on the PC
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define-from-file=env.json
                                                  # then open http://<PC-IP>:8080 in iPhone Safari (same Wi-Fi)
flutter test                                      # run all tests
flutter analyze                                   # lint / static checks
dart format lib test                              # format code
dart run build_runner build --delete-conflicting-outputs   # regenerate *.freezed.dart / *.g.dart
```

- After changing any freezed model, run `build_runner` and commit the generated files too.
- Before saying a task is done, run `flutter analyze` and `flutter test` and report the result honestly. If something fails, say what failed.
- There is no Mac, so native iOS builds can't run locally (Xcode is Mac-only). Use web for local testing. If Flutter isn't installed, or the app can't be run, say so instead of guessing.

## Conventions

- **Money is always an integer number of cents** (`int` in Dart, `bigint` in Postgres). Never use `double` for money. Convert only for display, with `Money.format` / `Money.parseToCents` in `lib/core/utils/money.dart`. Default currency is PHP.
- Models are immutable freezed classes. Change data by creating a copy (`copyWith`), not by mutating.
- Screens read data through Riverpod providers. Supabase calls live in repositories under `data/`, not inside widgets.
- Every new table needs Row Level Security so users only see their own rows. Add schema changes as a new file in `supabase/migrations/`; never edit an old migration.
- Keep widgets small. If a `build` method gets long, pull pieces out into their own widgets.
- Add or update a test when you add logic (especially anything about money).

## Secrets: never commit them

- Supabase keys live in `env.json`, which is in `.gitignore`. `env.example.json` is the safe template.
- Do not read, print, or commit `env.json`, `.env` files, or any key. Do not paste keys into code.
- Only the **publishable** Supabase key belongs in the app. The secret / `service_role` key never goes in this repo.

## Git

- Work on a branch, not directly on `main`. Use short, clear commit messages that say what changed.
- Ask before pushing, and never force-push.

## Teach me (do this after every change)

Jade wants to learn how the app works, not just get working code. After each change, end your reply with a short section in this shape:

**What changed**
List each file you touched and, in one plain sentence each, what you did to it.

**Why**
The reason for the change, in terms of what the app does for the user.

**How it works**
Walk through the new code in plain words, as if explaining to a friend who is new to programming. Point to the important lines by file and line number. Say what happens step by step when the app runs that code.

**Concept to know**
Name the one or two Flutter / Dart ideas this change used (for example: `StatelessWidget` vs `StatefulWidget`, `Future` and `async`/`await`, Riverpod providers, null safety, `const`, freezed `copyWith`, go_router routes, Row Level Security). Explain each in two or three sentences and link the official docs page when you know it (docs.flutter.dev, dart.dev, riverpod.dev, supabase.com/docs).

**Try it yourself**
One small, optional thing Jade could change or run to see the concept in action (for example: "change the color in `app_theme.dart` and hot reload with `r`").

Style rules for teaching:

- Use simple words. When you must use a technical term, explain it the first time.
- Keep it short: a few sentences per heading, not an essay.
- Be honest about what you did not test or are unsure of.
- If Jade asks "why" or "what does this mean", answer that first, before doing more work.
- For bigger tasks, briefly explain the plan in plain words before you start editing.
