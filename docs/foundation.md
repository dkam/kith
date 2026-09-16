# Kith — the founding brief

This is the brief Kith was built from, kept verbatim as the record of what was
originally asked for.

**It is history, not law.** `CLAUDE.md` is the living version of these rules:
where the two disagree, `CLAUDE.md` wins, and its *"Deviations from the original
brief, and why"* section explains each place they have come apart (Lexxy and
Action Text in place of Markdown columns, Rails 8.1 / Ruby 4.0, the
`notifications.kind` column, `feed_items.posted_at`, `actors.discoverable`, the
console setup code in place of a first-member rake task being the only way in).

---

You are building Kith: a private, invite-only network for a few dozen friends. Think "a private blog with photos, plus a reader for your friends' private blogs". It will later federate with other Kith instances (and read RSS / Mastodon), so the schema must not assume everything is local — but do NOT build federation now.

## Stack (fixed, don't substitute)
- Latest stable Rails 8.x, Ruby 3.4, SQLite for all databases (primary, queue, cache, cable — separate files).
- solid_queue, solid_cache, solid_cable. Propshaft. Importmap. No Node build step.
- Tailwind (tailwindcss-rails), Hotwire: Turbo + Stimulus used extensively. Turbo Frames/Streams for feed, comments, follow state. Minimal custom JS.
- `bin/rails generate authentication` for auth. NOT Devise. Sessions + passkeys later; email/password now.
- Active Storage with the `rails_storage_proxy` route resolution and image_processing (vips). Disk service in dev, S3-compatible in prod via env.
- Minitest, fixtures, system tests with headless Chrome. No RSpec, no FactoryBot.
- Gems beyond the defaults: image_processing only, unless you ask first.

## Product rules (these are design decisions, not suggestions)
- Invite-only. No public signup. An invite is single-use, expires, and records who issued it. Every member has an inviter (except the first, created via a rake task).
- No reposting/boosting of any kind. No likes yet. No algorithmic feed — strictly chronological.
- Follows are DIRECTED: A follows B is one edge with states `requested` → `accepted` (or `rejected`). Accepting never creates the reverse edge. A "connection" is derived: mutual accepted follows. Accept UI offers a one-tap "follow back".
- Post audience is fixed at write time and never changes: `followers` (default) or `public`. (Circles come later; leave room.) Public posts are the only thing that will ever leave the instance to non-Kith servers.
- Comments are flat (no threading), visible to the post's audience. A commenter's name is shown, but their profile link is only rendered if the viewer is connected to them OR they have `discoverable: true`.
- Notifications must pass the identical visibility check as the feed (they are the classic side channel).
- Deleting a post deletes its media. Nothing is soft-deleted.
- Member `discoverable` setting: `everyone` / `connections_only` / `invisible`. Invisible members' comments are shown only to their connections.

## Schema shape (federation-ready)
- `actors` table: `id, type (Local|Remote|Feed), handle, domain (null for local), display_name, inbox_url, public_key, private_key (local only, encrypted), discoverable`. A `members` table holds credentials/email and belongs_to `actor`. Local members always have an actor; remote actors have no member.
- `posts` belong to `actor`, have `title` (optional), `body` (Markdown, rendered server-side and sanitised), `audience` enum, `published_at`, `uri` (nullable now, will hold the ActivityPub id), `remote: boolean`.
- `follows`: `follower_actor_id, followed_actor_id, state, accepted_at`. Unique on the pair.
- `comments`: `post_id, actor_id, body`.
- `invites`: `code, inviter_member_id, claimed_by_member_id, expires_at`.
- `feed_items`: `member_id, post_id, read_at` — materialised per reader on post creation (fan-out on write; it's forty people). This is the reader's unread state.
- `notifications`: `member_id, actor_id, subject (polymorphic), read_at`.
Key IDs as integers now; don't reach for UUIDs.

## Media
- Never expose an Active Storage blob URL directly in HTML. All images render through `MediaController#show` which takes an opaque attachment id, checks the current member is in the post's audience at request time, and serves the file with `Cache-Control: private, no-store`. Return 404 not 403 when unauthorised. Public posts' media may be cached.
- Generate and serve variants (thumb, feed width, full) via the same controller. Strip EXIF on upload (including GPS).

## Authorisation
- A single `Visibility` query object / policy answers "can actor X see post P" and "can actor X see actor Y's profile link". Every feed, comment, notification, media and permalink query goes through it. Cover it thoroughly with tests: this is the privacy model.

## Phase 1 — build exactly this, then stop
1. App skeleton with the stack above, `bin/setup`, `Procfile.dev`, CI workflow running tests + brakeman + rubocop-rails-omakase.
2. Authentication, invites (issue, claim, expire), first-member rake task, profile settings (display name, avatar, discoverable).
3. Posts: create/edit/delete with title, Markdown body, multiple photos (drag-drop upload via Stimulus + direct upload), audience selector. Permalink page.
4. Follows: request, accept, reject, unfollow, follow back. Turbo Stream updates on the buttons.
5. Reader: chronological feed of accepted-follows' posts plus own posts, unread markers, "mark read" as you scroll (Stimulus IntersectionObserver), paginated with Turbo Frames.
6. Flat comments with the gated profile link rule.
7. Notifications: new follower, follow accepted, new comment on your post.
8. Media controller as specified.

## How to work
- Before writing code, produce a short plan (files, models, routes) and a `CLAUDE.md` capturing the rules above so future sessions inherit them. Then proceed without checking in unless a rule above is ambiguous or you want to add a gem.
- Small commits with clear messages, one concern each.
- Tests for every model rule and for `Visibility`; system tests for the invite → post → follow → comment happy path.
- Keep views plain Tailwind: quiet, text-first, generous whitespace, reader-like. No component library.
- Use `bin/rails` generators where sensible; delete what they scaffold that we don't need.
