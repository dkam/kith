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
- Auth from `bin/rails generate authentication`. **Not Devise.** Email/password
  now; passkeys later.
- Active Storage with `rails_storage_proxy` route resolution and
  `image_processing` (vips). Disk service in dev, S3-compatible in prod via env.
- Minitest, fixtures, system tests with headless Chrome. **No RSpec, no
  FactoryBot.**

### Gems

Beyond the Rails defaults, only:

- `image_processing` — Active Storage variants, EXIF stripping.
- `commonmarker` — Markdown rendering (approved 2026-09-16).
- `json` pinned to `~> 2.7` — Ruby 4.0 ships json 3.x as a default gem, and its
  `JSON.parse` arity change breaks `ActiveSupport::JSON.decode`, which every
  signed cookie goes through. Remove the pin when Rails supports json 3.

**Ask before adding any other gem.**

---

## Product rules

These are design decisions, not suggestions.

- **Invite-only. No public signup.** An invite is single-use, expires, and
  records who issued it. Every member has an inviter except the first, who is
  created by `rake kith:first_member`.
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
  always have an actor; remote actors never have a member.
- **`posts`** — `belongs_to :actor`; `title` (optional), `body` (Markdown),
  `body_html` (rendered server-side and sanitised at write time), `audience`
  enum, `published_at`, `uri` (nullable now; will hold the ActivityPub id),
  `remote` boolean.
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

### Deviations from the original brief, and why

- `actors.discoverable` holds the three-state enum. The brief listed the column
  on `actors` but described its values under "Member"; actors is the right home
  because remote actors need discoverability too, and a member's identity *is*
  its actor.
- `notifications.kind` was added. `new_follower` and `follow_accepted` both
  point at a `Follow` subject and are otherwise indistinguishable.
- `posts.body_html` was added. Rendering Markdown server-side at write time, per
  the brief, means storing the result.
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

Two habits that fall out of it:

- **404, never 403**, for anything the viewer may not see — a post, a profile, a
  photo. A 403 confirms the thing exists. The tests assert that "hidden" and
  "does not exist" return the *same* status.
- **Counts are disclosures too.** A reply count, an unread badge: derive them
  from the visible set, not from the table.

---

## How to work

- Small commits, clear messages, one concern each.
- Tests for every model rule, exhaustive tests for `Visibility`, and system
  tests for the invite → post → follow → comment happy path.
- Views are plain Tailwind: quiet, text-first, generous whitespace, reader-like.
  **No component library.** Shared classes (`.field`, `.btn`, `.prose-kith`) are
  defined with `@apply` in `app/assets/tailwind/application.css` so the views
  stay readable.
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
```

---

## Phase 1 scope — build exactly this, then stop

1. App skeleton, `bin/setup`, `Procfile.dev`, CI.
2. Authentication, invites (issue, claim, expire), first-member rake task,
   profile settings (display name, avatar, discoverable).
3. Posts: create/edit/delete, title, Markdown body, multiple photos
   (drag-and-drop via Stimulus + direct upload), audience selector, permalink.
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
