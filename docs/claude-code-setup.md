# Using Claude Code with GastaDoor (VS Code on a Mac)

This repo comes with a ready-made Claude Code setup. This page explains what each file does and the few steps you do once on your Mac.

## What's in the setup

| File | What it does |
| --- | --- |
| `CLAUDE.md` | Claude reads this at the start of every session. It describes the app, the folders, the commands, the rules (money in cents, never commit keys), and the **Teach me** section that makes Claude explain every change. |
| `.claude/settings.json` | Permission rules: which commands Claude may run without asking, which ones it must ask about first, and which ones are blocked. It also turns on the tutor output style. |
| `.claude/output-styles/gastadoor-tutor.md` | The "GastaDoor Tutor" style. It tells Claude to talk like a patient teacher: plan first, explain after, answer your questions before doing more work. |
| `.mcp.json` | Connects Claude to the official **Dart and Flutter MCP server** (`dart mcp-server`, built into the Dart SDK). With it, Claude can run the analyzer, look up pub.dev packages, and work with your running app (hot reload, read runtime errors, inspect the widget tree). |
| `.gitignore` | Now also ignores `.claude/settings.local.json`, where your personal "don't ask again" approvals are saved. |

## What Claude may do

**Without asking:** read files, everyday git (`status`, `diff`, `log`, `add`, `commit`, `branch`, `switch`, `pull`, `fetch`, `stash`), Flutter and Dart commands (`pub get`, `run`, `test`, `analyze`, `format`, `build_runner`, `doctor`), opening the iOS Simulator, simple shell commands like `ls` and `mkdir`, web search, and reading the Flutter, Dart, Riverpod, Supabase and GitHub docs.

**Asks you first:** `git push`, `git reset`, `git rebase`, `git merge`, deleting or moving files (`rm`, `mv`), `curl`/`wget`, `brew`, the `supabase` CLI, and editing `env.json`. File edits also ask by default (see "Permission modes" below).

**Blocked:** force-pushing, `rm -rf`, `sudo`, and reading `env.json`, `.env` files or your `~/.ssh` keys.

These rules are a safety net for the commands Claude normally writes, not a hard security wall, so still glance at what Claude is doing.

## One-time steps in VS Code

1. Pull this branch (or `main` once the PR is merged) and open the `gastadoor-app` folder in VS Code.
2. Open the Claude Code panel. The first time, Claude Code asks whether you **trust this folder**. Say yes, otherwise the "allow" rules don't apply and you'll get more prompts.
3. Claude Code will ask whether to enable the **dart** MCP server from `.mcp.json`. Approve it. (It needs `dart` on your PATH, which the Flutter SDK already gives you. Check with `dart --version` in the terminal.)
4. Check the output style: type `/` in the Claude prompt box, choose **Output styles**, and make sure **GastaDoor Tutor** is selected. You can switch to the built-in **Learning** style there any time you want Claude to leave small pieces of code for you to write yourself (it marks them with `TODO(human)`).

## Browser access (Claude in Chrome)

Claude can drive your real Chrome browser: open pages, click, fill forms, read console errors, and take screenshots. For this app it's handy for reading docs, checking the Supabase dashboard, or testing a web build later.

Browser access can't be turned on from a file in the repo (Claude Code blocks that on purpose, so a downloaded project can't take over your browser). You turn it on yourself:

1. You need a paid Claude plan (Pro, Max, Team or Enterprise) and Google Chrome (Edge, Brave and Arc also work).
2. Install the **Claude** extension from the Chrome Web Store: <https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn>
3. Sign in to the extension with the **same claude.ai account** you use in VS Code.
4. In the Claude Code panel in VS Code, type `@browser` in your message to connect for that chat. To connect automatically every time, type `/chrome` and turn on **Enabled by default**.
5. The first time Claude visits a site it asks your permission. You can manage which sites are allowed in the Chrome extension's settings.

If it says "Browser extension is not connected", restart Chrome, check you're signed in to the same account, then type `/chrome` and pick **Reconnect extension**. Full guide: <https://code.claude.com/docs/en/chrome>

## Permission modes (how much Claude asks)

You can switch modes from the mode selector at the bottom of the Claude panel:

- **Ask before edits** (default): Claude asks before each file change. Best while you're learning, because you see every edit.
- **Edit automatically**: Claude edits files without asking. Faster once you're comfortable. The "ask" and "blocked" rules above still apply.
- **Plan mode**: Claude only reads and plans, and shows you the plan before touching anything. Great for "how would you build X?" questions.

When Claude asks to run a command and you pick "Yes, and don't ask again", that approval is saved in `.claude/settings.local.json` just for you.

## Good ways to learn with Claude

- Ask "explain this file to me" on any file in `lib/`.
- Ask "why did you do it this way?" after a change. The tutor style answers first, before doing more work.
- Ask Claude to run `flutter test` and explain what each test checks.
- Try the **Learning** style for a feature you want to write partly yourself.

## Note about cloud sessions

These settings are made for Claude Code on your Mac. Cloud sessions (like the threads in your claude.ai project) run on a different machine: they don't use your browser, and project threads skip the permission rules in `.claude/settings.json`.
