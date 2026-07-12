# PocketLog: Expense Tracker

Simple offline expense tracker. No signup. 2-tap entry. Your data stays on your phone.

**Developer:** Musa Studio

## Project files

- `lib/main.dart` — the complete app code
- `pubspec.yaml` — project configuration
- `codemagic.yaml` — cloud build recipe (Codemagic reads this automatically)

## How the build works

This project is built in the cloud with Codemagic. The `codemagic.yaml` file
first generates the Android platform files (`flutter create .`), then builds a
release APK. No local Android Studio setup is needed.

## Version

1.0.0 — first build (entry, categories, monthly summary, offline storage)
