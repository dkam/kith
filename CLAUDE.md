# Kith

A private, invite-only network for a few dozen friends. Think "a private blog
with photos, plus a reader for your friends' private blogs".

It will **later** federate with other Kith instances (and read RSS / Mastodon),
so the schema must not assume everything is local — but **do not build
federation now**. Leave the seams; don't build the bridge.

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
- `mcp` — the official Ruby MCP SDK, behind each member's read-only agent
  endpoint (approved 2026-09-18).
- `json` pinned to `~> 2.7` — Ruby 4.0 ships json 3.x as a default gem, and its
  `JSON.parse` arity change breaks `ActiveSupport::JSON.decode`, which every
  signed cookie goes through. Remove the pin when Rails supports json 3.

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
  viewer is connected to them **or** they are discoverable by `members` or
  `internet`.
- **Notifications pass the identical visibility check as the feed.** They are
  the classic side channel for leaks — route them through `Visibility` like
  everything else.
- **Nothing is soft-deleted.** Deleting a post deletes its media.
- **Member discoverability is one ladder of four rungs**, widest first:
  `internet` / `members` / `connections_only` / `invisible`, defaulting to
  `connections_only`. An invisible member's comments are shown only to their
  connections. There is deliberately **no second "profile visibility"
  setting**: who can find me and who can read my profile page are the same
  question asked at different distances, and two columns would mean two rules
  to keep in step with a truth table full of holes between them.
- **`internet` is the only rung the open web can see.** A signed-out visitor
  gets a profile page for an `internet` actor and a 404 for every other one —
  the same 404 a handle nobody has ever used returns. That page is a separate
  template (`profiles/anonymous`), not conditionals inside the members' one:
  avatar, name, handle, public posts, and nothing of the follow graph.
- **Readable and findable are different grants.** A public post's permalink is
  anonymously readable whatever its author's rung; it is *indexed* only when
  the author is on `internet`. The layout is `noindex, nofollow` everywhere
  else — see `ApplicationController#allow_indexing_by`, which both public
  surfaces ask, and which requires a signed-out viewer as well as the rung.
- **Opting onto the web is a one-way door**, so it is never the default. Once
  crawled, unpublishing is theatre.

---

## Schema shape (federation-ready)

Integer primary keys. Don't reach for UUIDs.

- **`actors`** — `type` (STI: `LocalActor` / `RemoteActor` / `FeedActor`),
  `handle`, `domain` (NULL for local), `display_name`, `inbox_url`,
  `public_key`, `private_key` (local only, encrypted), `discoverable`.
  Everything that can author or be followed is an actor, local or not.
- **`members`** — credentials and email; `belongs_to :actor`. Local members
  always have an actor; remote actors never have a member.
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
- **`mcp_tokens`** — `member_id`, `token`, `name`, `access` enum, `last_used_at`.
  The credential behind one of a member's MCP endpoints. A member holds as many
  as they like, named, because a reader on the phone and something that writes
  on the desktop are not the same grant. `access` is `read_only` or
  `read_write`, integer-backed and sparse so narrower grants fit between them,
  and it is **fixed at issue** — a token handed out as read-only never quietly
  becomes able to write. To change it, revoke and reissue.

### Deviations from the original brief, and why

- `actors.discoverable` holds the enum. The brief listed the column on `actors`
  but described its values under "Member"; actors is the right home because
  remote actors need discoverability too, and a member's identity *is* its
  actor.
- `everyone` was renamed `members`, and `internet` added above it. The value
  had always meant "every member of this instance and nobody beyond it", which
  reads correctly only while there is nothing beyond the instance. With a rung
  above it, "everyone" is a word that means "not everyone" — and it is the rung
  people misread in the direction that hurts. The integer is still 0; the
  rename was code only.
- `notifications.kind` was added. `new_follower` and `follow_accepted` both
  point at a `Follow` subject and are otherwise indistinguishable.
- `posts.body`/`body_html` are gone. The brief assumed Markdown in, HTML out;
  the editor now produces HTML directly, so Action Text holds it and the two
  columns have nothing left to say. Photographs moved with it: they were a
  `has_many_attached :photos` tray under the post, and are now embedded in the
  body, which is why `Post#photos` reads `body.embeds_attachments`.
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
- can actor X see actor Y's profile link, or open their profile page?
- can actor X see comment C?

X may be **nil**. A signed-out visitor is not an error case to bounce at the
door; it is a viewer with less, and `Visibility` answers for it like any other.
`post?` says yes to a public post, `profile?` and `profile_link?` say yes only
on the `internet` rung, everything else is no. Media, notifications and the MCP
endpoint inherit that for free, because they were already routed through here.

It answers in two shapes — a predicate for one record (`post?`, `comment?`) and
a scope for many (`visible_posts`, `visible_comments`). The tests assert the two
can never diverge, by cross-checking every actor against every post and comment
in the fixture graph. That pair drifting apart is how a feed and a permalink
come to hold different opinions about the same post.

The same cross-check binds `profile_link?` to `profile?`: **nobody is ever
shown a link to a page they would be 404ed from.** A link that leads to a 404
is itself the disclosure — the link says the thing exists and the page denies
it — and the two methods are edited separately, which is exactly how they
drift.

**Every** feed, comment, notification, media and permalink query goes through
it. There is no second path. Cover it thoroughly with tests — this is the
privacy model, and a bug here is the whole product failing.

Two habits that fall out of it:

- **404, never 403**, for anything the viewer may not see — a post, a profile, a
  photo. A 403 confirms the thing exists. The tests assert that "hidden" and
  "does not exist" return the *same* status.
- **Counts are disclosures too.** A reply count, an unread badge: derive them
  from the visible set, not from the table.
- **`Cache-Control: public` only where there is no session.** The same URL
  renders a different body to a member — a follow button, their followers-only
  posts — and a shared cache knows nothing about anybody's session. Set it on
  the signed-out branch, never on a page rendered under a session.

A seam left for later: when federation lands, the ActivityPub actor document is
content-negotiated at the profile's own URL and must resolve for **every** local
actor, whatever their rung. That is a machine document, not a profile page;
`discoverable` must not gate it, or remote follow requests cannot address an
invisible member. Don't build it now.

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

### Releasing

**Bumping `Kith::VERSION` in `config/version.rb` is the release.** Pushing that
change to main is the only trigger `.github/workflows/build.yml` has: it builds
amd64 and arm64 natively, stitches them into one manifest on
`ghcr.io/dkam/kith`, tags it `:vX.Y.Z` and `:X.Y.Z`, and — for a non-pre-release
— moves `:latest`, tags the commit `vX.Y.Z` and cuts a GitHub Release. A version
with a hyphen (`0.2.0-dev`) publishes its own image tags and nothing else: no
`:latest`, no git tag. There is no manual tagging step, because manual steps
stop happening and the git tags fall behind the image tags.

Two different questions, two different answers, don't conflate them:

- `Kith::VERSION` — *which release is this?* Hand-written, survives a rebuild,
  and names the image tag.
- `config.x.revision` — *which commit is this?* The Dockerfile writes the build's
  `GIT_SHA` to a `VERSION` file and `config/initializers/revision.rb` reads it at
  boot, falling back to `git rev-parse` in development. It is the only thing that
  answers "is what I just built actually running?"

`McpServer::VERSION` is a third thing again — the protocol surface's own
version, which moves when the tools do.

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

# forgotten password — from bin/rails console, or bin/rails runner
Member.reset_password!("alice@example.com")   # => the new password; also signs them out
```

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
9. MCP endpoints, added 2026-09-18 after the original eight. A member makes as
   many as they want from settings, each named and each either read-only or
   read-and-write, with copy, reset and revoke, and per-client instructions for
   Claude Code, opencode and Claude Desktop. The tools are `whoami`, `feed`,
   `post`, `notifications`, and — only on a read-and-write endpoint —
   `write_post`, `comment` and `mark_read`. A read-only endpoint is never told
   the writing tools exist; `McpServer.tools_for` decides once, from the grant.

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
- **The MCP token is in the query string on purpose.** It is the only place a
  credential can ride that every MCP client accepts — the phone apps take a URL
  and nothing else — and `token` is already in `config.filter_parameters`, so
  the request line and the parameters come out `[FILTERED]`. What filtering
  does *not* cover is the SQL echo in development, which is why
  `McpController#authenticate_token` silences the logger around the lookup.
- **An agent hands us text, never markup.** `write_post` takes plain text and
  makes the paragraphs itself, escaping as it goes. Kith stores HTML because
  the editor produces HTML; nothing is gained by letting a JSON-RPC caller
  choose the markup that gets stored.
- **Lexxy's stylesheet is unlayered, and unlayered CSS beats every cascade
  layer** however specific the layered selector is. Overrides for it therefore
  sit outside `@layer components` in `app/assets/tailwind/application.css`;
  inside, they are silently ignored.
