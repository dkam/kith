# Kith

A private, invite-only network for a few dozen friends. Think "a private blog
with photos, plus a reader for your friends' private blogs".

It will **later** federate with other Kith instances (and read RSS / Mastodon),
so the schema must not assume everything is local — but **do not build
federation now**. Leave the seams; don't build the bridge.

The brief this was built from is kept verbatim in `docs/foundation.md`. This
file is the living version of it: where the two disagree, this one wins, and
*"Deviations from the original brief, and why"* below says what moved.

---

## Stack (fixed — do not substitute)

- Rails 8.1.x, Ruby 4.0.6, SQLite for **all** databases (primary, queue, cache,
  cable — separate files).
- `solid_queue`, `solid_cache`, `solid_cable`. Propshaft. Importmap.
  **No Node build step.**
- Tailwind via `tailwindcss-rails`. Hotwire (Turbo + Stimulus) used heavily:
  Turbo Frames/Streams for feed, comments and follow state. Minimal custom JS.
- Action Text for post bodies, with **Lexxy** as the editor — not Trix. Bodies
  are HTML, written in the editor and stored as written. There is no Markdown
  in the database; Lexxy's Markdown *shortcuts* are an input convenience.
- Auth from `bin/rails generate authentication`. **Not Devise.** Email/password
  now; passkeys later.
- Active Storage with `rails_storage_proxy` route resolution and
  `image_processing` (vips). Disk service in dev, S3-compatible in prod via env.
- Minitest, fixtures, system tests with headless Chrome. **No RSpec, no
  FactoryBot.**

### Gems

Beyond the Rails defaults, only:

- `image_processing` — Active Storage variants, EXIF stripping.
- `lexxy` — the Action Text editor (approved 2026-09-16, replacing
  `commonmarker` and Markdown storage).
- `json` pinned to `~> 2.7` — Ruby 4.0 ships json 3.x as a default gem, and its
  `JSON.parse` arity change breaks `ActiveSupport::JSON.decode`, which every
  signed cookie goes through. Remove the pin when Rails supports json 3.
- `sentry-rails` — optional error reporting (approved 2026-09-16). Inert unless
  `SENTRY_DSN` is set; what may leave is `ErrorReport`'s decision. See
  *"Error reporting"* below.

**Ask before adding any other gem.**

---

## Product rules

These are design decisions, not suggestions.

- **Invite-only. No public signup.** An invite is single-use, expires, and
  records who issued it. Every member has an inviter except the first.
- **The first member claims the instance from the console.** While no member
  exists, every boot prints a setup code and `/setup` accepts it; the moment
  one member exists the code stops being printed and `/setup` returns 404.
  Being able to read the server's console is the only credential that exists
  before anybody has joined. The code is derived from `secret_key_base`, not
  stored, so every process agrees on it and it is never written down. See
  `Setup`. `rake kith:first_member` still works for a headless install, and
  `rake kith:setup_code` reprints the code.
- **Two limits on how Kith grows, and they are not the same question.**
  `members.invite_allowance` is the soft one: how many people any one member
  may bring in, so growth stays spread out. `instances.invites_open` and
  `instances.member_cap` are the hard ones, and either **overrides every
  allowance, an admin's and the owner's included** — otherwise "no more
  members" would only mean "no more members except the people who decide".
  A closed or full instance also **stops invites that are already out there**:
  if it did not, a cap would not be a cap. Set from the console — `kith:invites`
  reports, `kith:door`, `kith:member_cap` and `kith:allowance` change.
  An invite that expired unclaimed costs nothing against an allowance: it
  brought nobody in and now never will.
- **No reposting or boosting of any kind. No likes.** No algorithmic feed —
  strictly reverse-chronological.
- **Follows are directed.** `A follows B` is one edge with states
  `requested → accepted` (or `rejected`). Accepting **never** creates the
  reverse edge. A *connection* is derived: mutual accepted follows. The accept
  UI offers a one-tap "follow back", which creates a second, separate edge.
- **Post audience is fixed at write time and never changes**: `followers`
  (default) or `public`. Circles come later — leave room in the enum.
  Public posts are the only thing that will ever leave the instance to non-Kith
  servers.
- **Comments are flat.** No threading. Visible to the post's audience. A
  commenter's name is always shown; their profile link is rendered only if the
  viewer is connected to them **or** they are `discoverable: everyone`.
- **Notifications pass the identical visibility check as the feed.** They are
  the classic side channel for leaks — route them through `Visibility` like
  everything else.
- **Nothing is soft-deleted.** Deleting a post deletes its media.
- **Member discoverability** is three-state: `everyone` / `connections_only` /
  `invisible`. An invisible member's comments are shown only to their
  connections.

---

## Schema shape (federation-ready)

Integer primary keys. Don't reach for UUIDs.

- **`actors`** — `type` (STI: `LocalActor` / `RemoteActor` / `FeedActor`),
  `handle`, `domain` (NULL for local), `display_name`, `inbox_url`,
  `public_key`, `private_key` (local only, encrypted), `discoverable`.
  Everything that can author or be followed is an actor, local or not.
- **`members`** — credentials and email; `belongs_to :actor`. Local members
  always have an actor; remote actors never have a member. `role` is the
  ranked enum `member` / `moderator` / `admin` / `owner` — see `Authority` —
  and `invite_allowance` is how many people they may bring in.
- **`posts`** — `belongs_to :actor`; `title` (optional), `audience` enum,
  `published_at`, `uri` (nullable now; will hold the ActivityPub id), `remote`
  boolean. The body is **not** a column: `has_rich_text :body` puts it in
  `action_text_rich_texts`, and the post's photographs hang off that rich text
  as Active Storage embeds, in the places the author put them.
- **`follows`** — `follower_actor_id`, `followed_actor_id`, `state`,
  `accepted_at`. Unique on the pair.
- **`comments`** — `post_id`, `actor_id`, `body`.
- **`invites`** — `code`, `inviter_member_id`, `claimed_by_member_id`,
  `expires_at`.
- **`feed_items`** — `member_id`, `post_id`, `read_at`. Materialised per reader
  when a post is published (fan-out on write; it's forty people). This is the
  reader's unread state.
- **`notifications`** — `member_id`, `actor_id`, `subject` (polymorphic),
  `kind`, `read_at`.
- **`instances`** — one row, always (`Instance.current`): `invites_open`,
  `member_cap`. This Kith's own settings. The instance's name, description and
  its own actor will live here when federation needs them.

### Deviations from the original brief, and why

- `actors.discoverable` holds the three-state enum. The brief listed the column
  on `actors` but described its values under "Member"; actors is the right home
  because remote actors need discoverability too, and a member's identity *is*
  its actor.
- `notifications.kind` was added. `new_follower` and `follow_accepted` both
  point at a `Follow` subject and are otherwise indistinguishable.
- `posts.body`/`body_html` are gone. The brief assumed Markdown in, HTML out;
  the editor now produces HTML directly, so Action Text holds it and the two
  columns have nothing left to say. Photographs moved with it: they were a
  `has_many_attached :photos` tray under the post, and are now embedded in the
  body, which is why `Post#photos` reads `body.embeds_attachments`.
- `members.role` was added, and is not in the brief at all. It is the smallest
  thing that answers "who may take a post down" without a roles table, a
  permissions table and a gem: one ranked integer, four values, and a policy
  object beside `Visibility` rather than a branch inside it.
- `instances` and `members.invite_allowance` were added. The brief said invites
  expire and are single-use but never said how many, which is fine until the
  day you want to stop. Two knobs rather than one because "slow down" and
  "we're full" are different sentences.
- `feed_items.posted_at` was added, copied from the post. The feed is ordered by
  when something was *written*, not by when it was fanned out — otherwise
  back-filling an accepted follow drops old posts at the top of the reader's
  page.

---

## Media

- **Never expose an Active Storage blob URL in HTML.** Every image renders
  through `MediaController#show`, which takes an opaque attachment id (an
  Active Storage *signed id*), checks at request time that the current member is
  in the post's audience, and serves the file.
- Serve `Cache-Control: private, no-store` for non-public posts. Public posts'
  media may be cached.
- **Return 404, never 403, when unauthorised.** A 403 confirms the resource
  exists.
- Variants (`thumb`, `feed`, `full`) are generated and served through the same
  controller.
- Attachments get their **own** opaque signed id, from `AttachableMedia`.
  `ActiveStorage::Attachment#signed_id` is delegated to the blob, which
  identifies the *file* rather than the attachment hanging it off a particular
  post — and visibility is a property of the attachment.
- **Lexxy will hand out blob URLs unless you stop it, in two places.** It sends
  the URL it previewed each photo from back with the post, in the
  `<action-text-attachment url="...">` attribute; `Post#forget_attachment_urls`
  drops it before the body is stored, `MediaHelper#editable_body_html` puts a
  media URL back when the author reopens the editor, and `url` is left out of
  the Action Text sanitiser's allowlist so a stray one could never reach a
  reader anyway. It also previews a *freshly uploaded* photo, before any post
  owns it, from `data-blob-url-template` — which the composer points at
  `MediaController#pending`, a route that requires a session and stops
  answering the moment a post claims the photo.
- **`StripMetadataJob` rewrites the blob in place** rather than swapping in a
  new one. The body names each photograph by the blob's signed global id, so
  the blob has to keep its identity or the post renders with a hole in it.
- **Strip EXIF on upload, including GPS**, in two layers: every variant is
  re-encoded by vips with metadata stripped, and `StripMetadataJob` rewrites the
  original behind it (direct upload means the original is in storage before the
  form is submitted). Upright the image *before* stripping, or the rotation flag
  goes with everything else.
- `MediaHelper` is the only thing in the app that turns an attachment into a
  `src`. Keep it that way.

---

## Authorisation

A single policy object, `Visibility`, answers:

- can actor X see post P?
- can actor X see actor Y's profile link?
- can actor X see comment C?

It answers in two shapes — a predicate for one record (`post?`, `comment?`) and
a scope for many (`visible_posts`, `visible_comments`). The tests assert the two
can never diverge, by cross-checking every actor against every post and comment
in the fixture graph. That pair drifting apart is how a feed and a permalink
come to hold different opinions about the same post.

**Every** feed, comment, notification, media and permalink query goes through
it. There is no second path. Cover it thoroughly with tests — this is the
privacy model, and a bug here is the whole product failing.

### Roles are a separate question, and `Authority` answers it

`Visibility` answers *"is this viewer in the audience?"* — a relation between
two people. `Authority` answers *"may this person act on the instance?"* — a
capability that comes from their role. They are two objects on purpose, because
of one rule:

**A role never widens `Visibility`.** An admin reads exactly the feed an
ordinary member reads. The dependency runs one way only: `Authority` asks
`Visibility`, and `Visibility` has never heard of a role. The moment
`Visibility#post?` grows an `|| admin?`, the privacy model is gone and nobody
notices for a year. `VisibilityTest` keeps two fixtures — `mo` and `ada` — who
hold rank and follow nobody, purely to assert they see no more than a stranger.

Which is also why **moderation is gated on seeing**: `Authority#delete_post?`
checks `visibility.post?` before it checks the rank, so a moderator may take
down a post that is already in front of them and nothing else. Moderation is
not a way *in*.

Four ranked roles on `members.role`, each carrying what the one below it
carries, with gaps in the integers for a rank we have not needed yet:

- **`member`** (0, default) — their own posts, comments, invites and settings.
- **`moderator`** (5) — + delete anyone's post or comment *that they can see*.
  Not edit: taking someone's words down is a power, rewriting them under their
  own name is not.
- **`admin`** (10) — + hand out roles below their own.
- **`owner`** (20) — + hand out admin. Whoever claimed the instance
  (`Member.create_first`). Kith can hold two owners; it cannot hold none, so
  the last owner cannot step down.

Ask `moderates?` / `administers?`, never `admin?` — a check written against one
exact role is a check that forgets everyone above it. Roles live on `members`,
not `actors`, because only local people have credentials: a remote actor holds
no rank here, ever.

There is no admin UI. Roles are set from the console, like the setup code:
`kith:roles` lists them, `kith:role[email,moderator]` changes one. The rake
task goes around `Authority` deliberately — reading the server's console is
already the highest credential this instance has, and `Authority` guards what
members do to *each other* through the app.

Two habits that fall out of it:

- **404, never 403**, for anything the viewer may not see — a post, a profile, a
  photo. A 403 confirms the thing exists. The tests assert that "hidden" and
  "does not exist" return the *same* status.
- **Counts are disclosures too.** A reply count, an unread badge: derive them
  from the visible set, not from the table.

---

## Error reporting

Optional, and off unless `SENTRY_DSN` is set: no DSN, no client, no network.
The DSN points at a **Splat** instance — ours is `splat.apps.aapamilne.com` —
which speaks the Sentry protocol. Create a project there, press *Copy External
DSN*, and hand it to the container as `SENTRY_DSN`.

**A crash report is an export.** Kith is a private network, so this is the same
question `Visibility` answers, asked about a different reader, and it gets the
same treatment: one object decides, and there is no second path. That object is
`ErrorReport`, and every event goes through it via `before_send` and
`before_send_transaction`.

Four of Kith's URLs carry something that must not travel, and Sentry attaches
the URL to everything:

| | |
|---|---|
| `/join/:code` | a live invite — a credential, still spendable |
| `/passwords/:token/edit` | a password reset — a credential, still usable |
| `/media/:signed_id/:variant` | the permission to read one photograph |
| `/@:handle` | a person's name |

**The same strings arrive a second way, and this is the half that is easy to
miss:** `Referer` is in neither of sentry-ruby's PII denylists, so following a
link off `/join/<code>` carries that code out in the header of whatever breaks
next. `ErrorReport` scrubs both doors with the same rules. This is the media
rule wearing a different coat — an opaque id is only opaque until it is written
down somewhere else.

What is *kept* is deliberate too: the variant (`thumb`/`feed`/`full`) is not a
secret and says which size broke, and `/passwords/new` is the form rather than
a token, so blanking it would throw away which page failed for nothing.

`config.send_default_pii = false` does the rest — with it off, sentry-ruby 7
sends no request body, no cookies, no caller IP, no SQL bind values and no
query string. Breadcrumbs are limited to `:http_logger`; Kith's own logs carry
handles and titles. Tracing is off unless `SENTRY_TRACES_SAMPLE_RATE` is set.

**Structured logging is switched off, and this is not optional.** sentry-rails
7 turns it on by default, and its `ActionController` subscriber attaches `path`
to *every* request rather than to failing ones — so a perfectly healthy GET of
`/join/<code>` would post that invite to Splat. Worse, a log event never passes
through `before_send`, so `ErrorReport` could not see it: errors were scrubbed
and the access log was not. `before_send_log` is wired to
`ErrorReport.scrub_log` anyway, because a switch and a hook that disagree is
how a later "let's just turn logs on" becomes a leak nobody looks for.

The one thing about a member that *is* sent is `ErrorReport.identity` — their
id, as an integer, and nothing else. "Is this one person or everybody?" is the
first question anybody asks about an error; a handle answers it no better and
names somebody in the process.

**Tests never report**, whatever the environment says — the initializer checks
`Rails.env.test?` as well as the DSN, because CI is exactly where a stray DSN
turns up. `ErrorReportingTest` boots a real second process to prove it, since a
boot with `SENTRY_DSN` set is a boot nothing else performs: the first version
of the initializer read an autoloaded constant and raised on exactly that boot,
with a green suite either side of it.

---

## How to work

- Small commits, clear messages, one concern each.
- Tests for every model rule, exhaustive tests for `Visibility`, and system
  tests for the invite → post → follow → comment happy path.
- Views are plain Tailwind: quiet, text-first, generous whitespace, reader-like.
  **No component library.** Shared classes (`.field`, `.btn`, `.prose-kith`) are
  defined with `@apply` in `app/assets/tailwind/application.css` so the views
  stay readable.
- The look is the **Kith Design System**, imported 2026-09-16 and installed as
  the `kith-design` skill — read `.claude/skills/kith-design/readme.md` before
  designing anything new. Warm neutrals on paper (`--warm-50`), one accent
  (terracotta, permitted only on the unread dot, the one primary action on a
  screen, links in prose, and the focus ring), Literata for what a member
  wrote and Barlow for every control. Sentence case everywhere except the
  uppercase micro-labels (`.label`, `.micro`). **Do not add a second hue** —
  distinguish with whitespace, a hairline, or weight. Dark follows
  `prefers-color-scheme`, with `data-theme` on `<html>` as an override.
- A name is rendered by `shared/_actor_name`, the only place that decides
  whether a name is a link — and it asks `Visibility`.
- Use `bin/rails` generators where sensible; delete what they scaffold that we
  don't need.
- CI runs tests, system tests, brakeman, and rubocop-rails-omakase. Keep it
  green.

### Commands

```
bin/setup              # install, prepare databases, seed nothing
bin/dev                # Procfile.dev — server + tailwind watch + solid_queue
bin/rails test         # unit + integration
bin/rails test:system  # headless Chrome
bin/rubocop            # rails-omakase
bin/brakeman           # security scan
bin/rails kith:first_member[email,handle,name]
bin/rails kith:setup_code   # reprint the setup code, while nobody has joined
bin/rails kith:roles        # who holds which rank
bin/rails kith:role[email,moderator]   # member | moderator | admin | owner
bin/rails kith:invites      # the door, the cap, everyone's allowance
bin/rails kith:door[closed] # open | closed
bin/rails kith:member_cap[40]          # pass nothing to lift it
bin/rails kith:allowance[email,10]
bin/build              # build + push the image, and tag the release
```

### Releases

Two different things share the word *version*, and both have a name:

- **version** — which release this is. Hand-set SemVer in `config/version.rb`,
  survives a rebuild of identical code, goes in `CHANGELOG.md`, gets said out
  loud.
- **revision** — which commit the running container was built from. The
  Dockerfile writes it into a `VERSION` file from `ARG GIT_SHA`;
  `config/initializers/revision.rb` reads it at boot into
  `config.x.revision`, falling back to `git rev-parse` in **development only**
  — a deployed container has no business shelling out on boot. Both are shown
  at the foot of the settings page.

**Bumping `Kith::VERSION` on `main` is the release.** Everything else follows
from it: `bin/build` reads the constant without booting Rails, pushes
`:vX.Y.Z`, `:<sha>` and `:latest`, and then creates the git tag in the same run
— *after* a successful push, because a tag for an image that does not exist is
a lie. A pre-release (any version containing a hyphen, e.g. `0.2.0-dev`)
publishes its own image tag, does not move `:latest`, and earns no git tag.

Tagging is not a separate step a human is trusted to remember, because they
don't: splat's `config/version.rb` once read 1.14.0 while its newest git tag
was v1.7.8 — eight releases with no commit you could check out.

---

## Phase 1 scope — build exactly this, then stop

1. App skeleton, `bin/setup`, `Procfile.dev`, CI.
2. Authentication, invites (issue, claim, expire), first member from the
   console setup code (and the rake task), profile settings (display name,
   avatar, discoverable).
3. Posts: create/edit/delete, title, rich text body written in Lexxy with
   photographs embedded in the prose (drag, paste or pick; direct upload),
   audience selector, permalink.
4. Follows: request, accept, reject, unfollow, follow back, with Turbo Stream
   button updates.
5. Reader: chronological feed of accepted-follows' posts plus own posts, unread
   markers, mark-read on scroll (Stimulus IntersectionObserver), paginated with
   Turbo Frames.
6. Flat comments with the gated profile-link rule.
7. Notifications: new follower, follow accepted, new comment on your post.
8. `MediaController` as specified.

**Not in phase 1**: federation, ActivityPub, RSS ingest, circles, likes,
passkeys, search, DMs.

---

## Things that will bite you

- **Development runs the same four SQLite files as production**, and the same
  solid_queue / solid_cache / solid_cable stores. Jobs do not run unless
  something is working the queue: use `bin/dev`, not a bare `bin/rails server`,
  or posts will never reach anyone's feed.
- **Links inside a Turbo Frame navigate within the frame.** The feed's
  pagination frame sets `target="_top"` for exactly this reason; without it,
  clicking a post title renders the permalink inside the feed.
- **System tests hand the browser a session cookie** rather than driving the
  sign-in form (`sign_in_as`). `HappyPathTest` signs in through the real form
  once, with a password, from an invite — that is where form sign-in is covered.
  Driving it at the top of every scenario made the suite depend on headless
  Chrome reliably accepting keystrokes into a password field, which it does not:
  dropped keystrokes left `required` fields empty, HTML5 validation then blocked
  submission silently, and it looked like a sign-in that produced no request.
- **Selenium clicks by coordinate.** `ApplicationSystemTestCase#visit` waits for
  the stylesheet to apply before returning, because a late layout shift makes
  clicks miss.
- **Only ever run one test process against `storage/test.sqlite3` at a time.**
  A second one produces `SQLite3::BusyException` that surfaces as unrelated,
  baffling failures five seconds later.
- **A photo appears in the composer before its upload has finished.** Lexxy
  draws it from a local preview the moment it is chosen, and the signed id that
  names it in the post only arrives when the direct upload returns. Submitting
  in between posts the words without the photographs, silently, because the
  editor is showing them. `drop_photos` in the system tests waits for the
  `/media/pending/` URL, which is the first thing that proves the upload is
  done.
- **Lexxy's stylesheet is unlayered, and unlayered CSS beats every cascade
  layer** however specific the layered selector is. Overrides for it therefore
  sit outside `@layer components` in `app/assets/tailwind/application.css`;
  inside, they are silently ignored.
