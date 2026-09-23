# Changelog

Kith's releases, newest first. Versions are SemVer, hand-set in
`config/version.rb` and tagged `vX.Y.Z`. **Bumping the constant on `main` is
the release** — the image, the git tag and this file's heading are all
consequences of it.

This file is news: what changed, when, and what it was worth. The reasoning
behind each change stays in its commit message, and the rules the code lives by
stay in `CLAUDE.md`.

## Unreleased

## 0.2.0 — 2026-09-23

Everything a private network needs before it can actually be deployed: a post
you haven't finished, a clock that is yours, somewhere for crashes to go, and a
production environment that knows its own name.

### Added

- **Drafts.** A post is a draft until you publish it, and publishing is its own
  act — a button on the composer and on the post's own page, never an edit.
  There is no draft column: a draft is a post with no `published_at`, so
  nothing can be a draft and published at once, or published with no date on
  it. A draft is visible to its author and to nobody else **whatever its
  audience says** — `Visibility` asks about the draft before it looks at the
  audience — and it never fans out, so it never reaches a feed. Your own drafts
  are listed on your profile, above your posts and nowhere anyone else can see
  them. The audience is still yours to change while it is a draft: the promise
  is made to the reader when the post reaches them, not when it is begun.
- **A time zone, for the few times that are not relative.** Kith says "3 hours
  ago" nearly everywhere, which needs no help; this is for the dates it shows
  instead. Set it on the settings page and the whole request is wrapped in it,
  so no view has to remember to convert and no second path can forget. An
  unset zone reads in the instance's clock, and a zone Kith does not recognise
  cannot take a page down.
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

### Fixed

- **Kith needs to know its own address, and now says so.** Production shipped
  with Rails' generated defaults, and each of them failed quietly: a password
  reset linked to `example.com` — arriving, looking right, leading nowhere —
  sent from `from@example.com`, which a relay refuses for a domain that is not
  ours; `assume_ssl` and `force_ssl` off, so cookies behind the TLS proxy were
  set without `secure` and a form POST could 422 on the CSRF origin check; and
  no `config.hosts`, so no DNS-rebinding protection at all. `KITH_HOST` is now
  required and the container refuses to start without it, because a guess is
  worse than a refusal when it decides both what every link says and which
  `Host` headers are answered. Outgoing mail is configured from `SMTP_*`, and
  `compose.yml` and `.env.example` are in the repository rather than on one
  machine.

## 0.1.0

Phase 1: invites, posts, follows, the reader, comments, notifications and
`MediaController`. Everything before this release is in `git log`, apart from
the two things that made the release itself possible:

- **Kith knows which release and revision it is.** `Kith::VERSION` in
  `config/version.rb` is the release; `Rails.application.config.x.revision` is
  the commit the running container was built from, written into a `VERSION`
  file by the Dockerfile from `--build-arg GIT_SHA` and falling back to `git`
  in development only. Both are shown at the foot of the settings page, so
  "is the thing I deployed the thing that's running?" has an answer that does
  not involve trusting an image tag.
- **`bin/build`** builds and pushes the production image, tagged `:vX.Y.Z`,
  `:<sha>` and — for a real release from `main` — `:latest`, then creates the
  matching git tag in the same run. A pre-release (any version with a hyphen)
  publishes its own tag, does not move `:latest`, and earns no git tag.

