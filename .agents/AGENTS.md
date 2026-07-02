# Hanassik Agent Handoff

This file is the working guide for Codex, Gemini, Antigravity, and other
agentic AI sessions that modify this repository. Keep it accurate when project
structure, commands, or product constraints change.

## Project Snapshot

- Hanassik is a minimalist, Android-first Flutter MVP named `하나씩`.
- The product saves repeatable work templates, starts checklist runs from those
  templates, tracks progress, and allows attachments on each run.
- This is a local-first app. Templates, runs, and run attachments are persisted
  through `shared_preferences`.
- Android is the primary platform. Flutter web is useful for lightweight browser
  checks, but product decisions should prioritize small-screen Android behavior.

## Architecture Boundaries

- Keep the current simple architecture unless the user explicitly asks for a
  larger redesign.
- Do not introduce Clean Architecture, BLoC, Redux, Riverpod, a database, cloud
  sync, authentication, or backend services without explicit approval.
- State is owned by `HanassikStore`, a `ChangeNotifier` in
  `lib/hanassik_store.dart`.
- Data objects live in `lib/models.dart`.
- The app shell, tabs, sheets, cards, and interaction handlers live in
  `lib/home_screen.dart`.
- Theme setup lives in `lib/main.dart`.

## Current Feature Map

- Templates:
  - `WorkTemplate` stores `id`, `title`, and ordered `steps`.
  - Template creation and editing use `AddTemplateSheet`.
  - The step editor uses `ReorderableListView`; keep `ObjectKey` on
    `TextEditingController` rows so text stays with the correct field.
- Runs:
  - `WorkRun` stores a run-specific `title`, optional `note`, and snapshots the
    template title and steps at start time.
  - `checked` is fitted to the current step count during construction.
  - Completing all steps sets `endedAt`; unchecking a completed run clears it.
- Attachments:
  - `WorkAttachment` stores `id`, `name`, base64 data, and optional MIME type.
  - Run attachments are saved inside the run JSON in `shared_preferences`.
  - Current limits are defined in `HanassikStore`:
    - `maxAttachmentsPerRun = 5`
    - `maxAttachmentBytes = 2 * 1024 * 1024`
    - `maxAttachmentNameLength = 120`
  - The UI uses `file_picker` with in-memory bytes. Images are previewed with
    `Image.memory`; other files render as file tiles.

## Storage and Recovery Rules

- Storage keys are private constants in `HanassikStore`:
  - `hanassik.templates`
  - `hanassik.runs`
  - `hanassik.hasSeededDefaults`
- Treat storage as untrusted. Loading must tolerate malformed JSON, wrong
  shapes, duplicate IDs, overlong text, invalid dates, invalid base64, and
  oversized attachment data.
- If recovery changes or drops stored data, preserve the existing
  `recoveredFromStorage` notice behavior.
- Keep limits centralized in `HanassikStore`; do not scatter magic numbers in
  widgets or tests.
- Android backup is disabled in `android/app/src/main/AndroidManifest.xml`.
  Do not re-enable it casually because local data may include customer workflow
  details or attachment content.

## UI and UX Constraints

- Use Material 3 and the existing green seed color `0xFF2F6B4F`.
- Use `Theme.of(context).colorScheme` for new colors so light and dark modes
  both work.
- Keep cards compact and mobile-friendly. This is not a marketing site.
- Prefer standard Material icons for actions:
  - add: `Icons.add`
  - edit: `Icons.edit_outlined`
  - attach: `Icons.attach_file`
  - delete/remove: existing delete or close icons
- Do not add visible instructional copy unless it directly helps the workflow.
- Keep Korean product copy consistent with the existing UI.

## Commands

Use `mise` tasks when possible because the toolchain is pinned in `mise.toml`.

```sh
mise install
mise run install
mise run format
mise run analyze
mise run test
mise run check
```

Android setup and checks:

```sh
mise run android:sdk:install
mise run android:licenses
mise run android:doctor
mise run dev
mise run build:android:debug
```

Web smoke check:

```sh
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000
```

Then open `http://0.0.0.0:3000/`. Flutter web may not expose useful text in the
accessibility tree; verify with a screenshot or visible rendering if needed.

## Verification Expectations

- For any Dart code change, run at least:

```sh
dart format lib test
flutter analyze
flutter test
```

- `mise run check` is the preferred full local gate.
- If UI layout changes, run a web or Android smoke check and inspect the screen.
- If storage behavior changes, add or update `test/store_test.dart`.
- If user-facing flows change, add or update `test/widget_test.dart`.
- Before committing, confirm `git status --short` contains only intended files.

## Testing Notes

- `test/store_test.dart` covers storage recovery, limits, run completion, and
  attachment persistence/removal.
- `test/widget_test.dart` covers template creation/editing, starting runs,
  checklist progress, recovery notices, and deletion confirmation.
- SharedPreferences tests must call `SharedPreferences.setMockInitialValues`.
- Widget tests rely on exact Korean strings. Update tests when copy changes.

## Dependency Policy

- Keep dependencies minimal.
- Current runtime dependencies are:
  - Flutter SDK
  - `shared_preferences`
  - `file_picker`
- New dependencies must be justified by a real product need and should fit the
  Android-first MVP.

## Git and Handoff Discipline

- Do not revert user changes unless the user explicitly asks.
- Keep commits focused and use concise English commit messages.
- When handing off to another AI session, summarize:
  - what changed
  - commands run and results
  - any running dev servers or temporary files
  - remaining risks or follow-up work
- If a dev server was started, stop it before finishing unless the user asked to
  keep it running.

## Known Tradeoffs

- Attachments are base64-encoded into `shared_preferences`. This is acceptable
  for the current MVP limits but is not suitable for large files, long-term
  media storage, or sync.
- Data is not encrypted. Do not position the app as safe for secrets,
  credentials, or highly sensitive customer data.
- Web support is a convenience target, not the primary product target.
