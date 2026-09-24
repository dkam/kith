# Changelog

Kith's releases, newest first. Versions are SemVer, hand-set in
`config/version.rb` and tagged `vX.Y.Z`. **Bumping the constant on `main` is
the release** — the image, the git tag and this file's heading are all
consequences of it.

This file is news: what changed, when, and what it was worth. The reasoning
behind each change stays in its commit message, and the rules the code lives by
stay in `CLAUDE.md`.

The MCP server carries its own number, `McpServer::VERSION`, because it is a
published interface with clients on the other end of it. It moves when its tools
do, independently of the release version.

## Unreleased

### Kith installs to a home screen

Forty people read this on a phone, and a browser tab is the wrong container for
something you open every day. A manifest and a service worker make Kith
installable on both platforms: its own icon, its own window, no browser chrome.
The manifest is rendered from `app/views/pwa`, so it is built from the same
tokens the stylesheet is.

- The service worker caches **nothing anybody wrote** — no documents, no
  `/media/`, no JSON. Only the digested assets under `/assets/`, which are
  identical for everyone. A phone is shared, lent and lost, and the Cache API is
  a plain readable store that outlives the session cookie and that `Visibility`
  gets no say over. It exists because a browser will not offer to install an app
  with no fetch handler, and because a cold launch should not render in Times.
- Installed, the page paints under the status bar and the home indicator, so the
  masthead and the reading column pay the safe-area insets back. Off a phone
  every inset resolves to `0px` and nothing moves.
- An icon, at last: the letter K in Literata 600, ink on paper. No mark was ever
  drawn for Kith and none has been invented — the design system says the word is
  set in Literata wherever a mark would go, and this is its first letter. No
  terracotta; an app icon is not one of the four places the accent is allowed.

### Sharing a link opens the composer

Kith appears in the phone's share sheet, and sharing to it opens the composer
with the link already in it. It only prefills — nothing is written until the
member presses the button, and the audience is theirs to pick as always. A share
is treated as text rather than markup, for the same reason `write_post` is, and
that conversion moved from `McpTools::WritePost` to `Post.paragraphs` now that
two callers want it.

Photographs can't be shared in yet: taking files needs a POST target and
somewhere to put them before a post exists, which is more than a prefill.

### Literata and Barlow are served from here

Both families were fetched from Google on every page load. An installed app gets
opened with no network and a cold cache, and a masthead that renders in Times
for a second reads as broken; the font stylesheet was also the last third party
left in the page, and who reads Kith, and when, is nobody else's to observe.
Ten woff2 files, latin and latin-ext, 328KB once and cached after. Literata is
variable over 400..600, so three roman weights are one file.

### Discoverability grew a rung, and a profile can reach the web

`discoverable` is now one ladder of four rungs, widest first: `internet`,
`members`, `connections_only`, `invisible`, defaulting to `connections_only`.
What was called `everyone` is now `members`, because that is what it always
meant — everyone *here*, not everyone alive — and with a rung above it,
"everyone" had become a word meaning "not everyone". The integer is still 0, so
the rename was code only. Opting onto the web is a one-way door, which is why
it is not the default: once crawled, unpublishing is theatre.

- `ProfilesController` no longer refuses every visitor without a session. It
  asks `Visibility` like everything else, so a signed-out stranger gets a 200
  for an `internet` profile and, for every other one, the same 404 a handle
  nobody has ever used would give them.
- The web's version of a profile is a second template, not conditionals in the
  members' one: avatar, name, handle and public posts, with no follow button
  and no counts. Followers were promised a private graph, and a template full
  of `unless signed_out?` is how a follower count eventually turns up on the
  open web.
- The layout had sent `noindex, nofollow` on every page since the beginning,
  which was right while every page needed a session. A page is now indexable
  when the visitor has no account *and* the author is on the `internet` rung —
  both, or neither. A public post by a `connections_only` author stays readable
  to anyone holding the link and absent from the index: unlisted is not the
  same as published, and the ladder and the post's audience answer different
  questions.

### Password resets from the console, too

`Member.reset_password!` takes an email address or a handle, makes a password
up if you do not give it one, returns it for the console to print, and signs
the member out everywhere. It needs no relay, so it is the way in for an
instance with no `SMTP_*`; for a few dozen friends the operator is reachable
anyway.

### MCP endpoints, so an assistant can read a member's Kith

The official Ruby MCP SDK (`mcp`) is now a dependency. A member makes endpoints
from their settings page: named, copied, reset and revoked there, with
per-client instructions for Claude Code, opencode and Claude Desktop folded in
beside each one.

Everything behind an endpoint goes through `Visibility`. There is no second
privacy model for agents, a post the caller may not see refuses exactly as one
that was never written does, and the notification side channel passes the same
check as the feed.

**Server 1.1.1** — `post` names a photograph in words rather than answering
with the filename off somebody's camera, which is the thing `Post#excerpt`
already refused to do. A post that is only pictures still says something.

**Server 1.1.0** — Several endpoints per member instead of one, each named so
they can be told apart when one comes to be revoked, and each either read-only
or read-and-write. What a token may do is fixed when it is made: changing it
would change it under whoever is already holding it, so the way to change it is
to revoke and reissue. A read-only endpoint is not offered the writing tools
and then refused them — it is never told they exist. Writing is `write_post`,
`comment` and `mark_read`; a post's body arrives as plain text and the
paragraphs are built and escaped here, because nothing is gained by letting a
JSON-RPC caller choose the markup that gets stored.

**Server 1.0.0** — One read-only endpoint per member, with `whoami`, `feed`,
`post` and `notifications`. The token rides in the query string because that is
the only place every MCP client can carry one, and `token` is already in
`config.filter_parameters`, so the request line and the parameters come out
`[FILTERED]`. What filtering does not cover is the SQL echo in development,
which is why the lookup silences the logger around itself.

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
`MediaController`. What it was, and then the two things that made the
release itself possible:

### Lexxy replaces Markdown, and photographs moved into the prose

Post bodies are HTML written in the editor and stored as written. There is no
Markdown in the database any more; `posts.body` and `posts.body_html` are gone
and Action Text holds the body instead. Photographs went with it: they were a
tray under the post and are now embeds inside the body, in the places the
author put them, which is why `Post#photos` reads `body.embeds_attachments`.

Lexxy hands out Active Storage blob URLs in two places unless it is stopped.
`Post#forget_attachment_urls` drops the one it sends back with the post,
`MediaHelper#editable_body_html` puts a media URL back when the author reopens
the editor, and `url` is left out of the sanitiser's allowlist so a stray one
could never reach a reader anyway.

### The first member claims the instance from the console

While nobody has joined, every boot prints a setup code and `/setup` takes it;
the moment one member exists the code stops being printed and `/setup` returns
404. The code is derived from `secret_key_base` rather than stored, so every
process agrees on it and it is never written down. Being able to read the
server's console is the only credential that exists before anybody is here.

### The Kith design system

Warm neutrals on paper, one accent used in four places, Literata for what a
member wrote and Barlow for every control. No component library and no cards —
separation is whitespace first and a hairline second. Dark is authored
independently rather than derived, and follows `prefers-color-scheme` with
`data-theme` as an override.

### The first build

Phase 1, in the order it was written: the Rails 8.1 skeleton on four SQLite
databases; members and actors with email and password authentication; invites
that are single-use, expiring and attributed; directed follows with
`requested → accepted → rejected` and a connection derived from the pair;
posts with an audience fixed at write time; flat comments; `Visibility`, the
privacy model in one place, answering as both a predicate and a scope so a feed
and a permalink cannot hold different opinions; media served only through a
controller that re-checks who is asking; profile settings; the reader, strictly
chronological, with unread state fanned out on write; notifications that pass
the identical check as the feed; and system tests for the invite → post →
follow → comment path.

### Release machinery

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
