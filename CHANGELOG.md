# Changelog

Kith's releases, newest first. Versions are SemVer, hand-set in
`config/version.rb` and tagged `vX.Y.Z`. **Bumping the constant on `main` is
the release** — the image, the git tag and this file's heading are all
consequences of it.

This file is news: what changed, when, and what it was worth. The reasoning
behind each change stays in its commit message, and the rules the code lives by
stay in `CLAUDE.md`.

## Unreleased

### Added

- **Kith knows which release and revision it is.** `Kith::VERSION` in
  `config/version.rb` is the release; `Rails.application.config.x.revision` is
  the commit the running container was built from, written into a `VERSION`
  file by the Dockerfile from `--build-arg GIT_SHA` and falling back to `git`
  in development only. Both are shown at the foot of the settings page, so
  "is the thing I deployed the thing that's running?" has an answer that does
  not involve trusting an image tag.
- **Optional error reporting.** Set `SENTRY_DSN` and crashes go to a
  Sentry-compatible server; leave it unset and there is no client, no network
  and nothing to configure. Because Kith is private, a crash report is an
  export: `ErrorReport` is the one object that decides what may be in one, and
  every event passes through it. It strips invite codes, password-reset tokens,
  signed attachment ids and handles out of the URL *and* out of the `Referer`
  header — which is in neither of sentry-ruby's PII denylists, so a link
  followed off `/join/<code>` would otherwise carry that code out in the header
  of whatever broke next. A member is sent as an integer id and nothing else.
  Tests never report, whatever the environment says.

  Structured logging is switched off: sentry-rails 7 enables it by default and
  its ActionController subscriber sends `path` on *every* request, so a healthy
  GET of `/join/<code>` would have posted that invite — and a log event never
  passes through `before_send`, so the scrubber could not have seen it.
- **`bin/build`** builds and pushes the production image, tagged `:vX.Y.Z`,
  `:<sha>` and — for a real release from `main` — `:latest`, then creates the
  matching git tag in the same run. A pre-release (any version with a hyphen)
  publishes its own tag, does not move `:latest`, and earns no git tag.

## 0.1.0

Phase 1: invites, posts, follows, the reader, comments, notifications and
`MediaController`. Everything before this release is in `git log`.
