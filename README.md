# Hanassik

Hanassik is an Android-first Flutter MVP for saving repeatable work sequences
as templates, starting checklist runs from those templates, and checking each
step off as work progresses.

## Features

- Create reusable task templates with ordered steps.
- Start a checklist run from any saved template with a run-specific title and
  optional note.
- Check and uncheck steps in an active run.
- See progress, remaining work, and the next actionable step at a glance.
- Track progress and completion status.
- Attach photos or other small files to each checklist run.
- Recover gracefully from corrupted local checklist data.
- Persist templates and runs locally with `shared_preferences`.

## Workflow

1. Create a template for a repeatable work sequence.
2. Start a run from that template.
3. Give the run its own title and optional memo text for the specific customer,
   site, request, or context.
4. Work through the checklist one step at a time.
5. Attach small photos or files to the run when evidence or reference material
   is useful.
6. Clear completed runs when they are no longer needed.

Templates remain reusable. Runs snapshot the template title and steps at start
time, so later template edits do not rewrite existing work history.

## Platform

Hanassik is an Android-first mobile MVP. The Flutter web files remain available
for lightweight browser checks, but product decisions and validation should
prioritize small-screen Android use.

## Requirements

- `mise`
- Android device or emulator for mobile development
- GitHub CLI authentication when publishing with `gh`

## Data and privacy

Hanassik is a local-first MVP. On Android, templates, checklist runs, and run
titles, notes, attachments, timestamps, and checklist state are stored in the
app's private `shared_preferences` storage. Android cloud backup is disabled in
the app manifest. This is still not encrypted storage. Do not store secrets,
credentials, or sensitive customer information in checklist titles, run notes,
steps, or attachments.

If the web target is used, data is stored in the browser's local storage through
`shared_preferences`, without encryption or account isolation. For web
deployment, serve the app from a dedicated origin and set standard security
headers such as Content Security Policy, `frame-ancestors`, `Referrer-Policy`,
and `Permissions-Policy` at the hosting layer.

## Project structure

- `lib/models.dart`: template, run, and attachment data objects.
- `lib/hanassik_store.dart`: local persistence, validation, recovery, and
  `ChangeNotifier` state.
- `lib/home_screen.dart`: tabs, cards, sheets, checklist interactions, and
  attachment UI.
- `lib/main.dart`: app entrypoint and Material 3 theme.
- `test/store_test.dart`: storage recovery, limits, completion, and attachment
  behavior.
- `test/widget_test.dart`: user-facing flows and Korean UI copy checks.
- `.agents/AGENTS.md`: handoff notes for agentic AI sessions modifying this
  repository.

## Development

Install the pinned Flutter, Android SDK command-line tools, JDK, Gradle, and
GitHub CLI with `mise`:

```sh
mise install
```

Install the Android SDK packages required by the pinned Flutter version and
review Android SDK licenses interactively:

```sh
mise run android:sdk:install
mise run android:licenses
mise run android:doctor
```

Install Flutter package dependencies:

```sh
mise run install
```

Check GitHub CLI authentication:

```sh
mise run gh:auth
```

If the GitHub CLI is not authenticated yet, run `gh auth login`.

Run on a connected Android device or emulator:

```sh
mise run dev
```

Build a debug APK:

```sh
mise run build:android:debug
```

Do not distribute debug APKs. Configure a release keystore and Play/App Bundle
signing separately before any production distribution.

Run checks with:

```sh
mise run check
```

For a lighter local loop, the check task is equivalent to:

```sh
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

For a browser smoke check:

```sh
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000
```

Then open `http://0.0.0.0:3000/` and inspect the visible rendering. Flutter web
may not expose useful app text through the browser accessibility tree.

## License

MIT. See [LICENSE](LICENSE).
