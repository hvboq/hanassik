# Hanassik

Hanassik is an Android-first Flutter MVP for saving repeatable work sequences
as templates, starting checklist runs from those templates, and checking each
step off as work progresses.

## Features

- Create reusable task templates with ordered steps.
- Start a checklist run from any saved template.
- Check and uncheck steps in an active run.
- See progress, remaining work, and the next actionable step at a glance.
- Track progress and completion status.
- Attach photos or other small files to each checklist run.
- Recover gracefully from corrupted local checklist data.
- Persist templates and runs locally with `shared_preferences`.

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
attachments are stored in the app's private `shared_preferences` storage and
Android cloud backup is disabled in the app manifest. This is still not
encrypted storage. Do not store secrets, credentials, or sensitive customer
information in checklist titles, steps, or attachments.

If the web target is used, data is stored in the browser's local storage through
`shared_preferences`, without encryption or account isolation. For web
deployment, serve the app from a dedicated origin and set standard security
headers such as Content Security Policy, `frame-ancestors`, `Referrer-Policy`,
and `Permissions-Policy` at the hosting layer.

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

## License

MIT. See [LICENSE](LICENSE).
