# Phase 2 — things to attach

Notes from a design conversation on 2026-09-17, written down so the seams stay
open while phase 1 is finished.

**This is not a licence to build any of it.** `CLAUDE.md`'s *"Phase 1 scope —
build exactly this, then stop"* still holds. What follows is the shape these
features want to take, and — more usefully — the two or three places where
getting them wrong would be expensive to undo later. Where this document and
`CLAUDE.md` disagree, `CLAUDE.md` wins; when any of this is actually built, the
rules that survive contact move there and this file becomes history, like
`foundation.md`.

---

## The distinction that does the work: written vs. emitted

Everything on the wish list — scrobbles, checkins, bike rides, Immich photos,
a TBDB reading list, links worth keeping — splits on one line.

A **post** is an act. Somebody sat down, chose words, chose an audience and
pressed publish. **Exhaust** is emitted: nobody decided to scrobble *Blue
Monday*, last.fm noticed. A ride is exhaust you might later write about. A
saved link is exhaust with an opinion attached.

The line matters because `posts` is load-bearing for things exhaust does not
want: `publish!` as a once-only act, an audience promise fixed at publication,
comments, and fan-out into forty readers' `feed_items`. Scrobbles arrive fifty
times a day. Fanning that out is two thousand feed rows a day and the end of
"strictly reverse-chronological" as a promise worth keeping — the feed stops
being forty friends and becomes a music ticker with friends in it.

So exhaust does not go in `posts`. It also does not get four bespoke tables.

## Prominence belongs to the kind, not to recency

Four destinations, and only one of them is scarce:

- **The feed** — worth interrupting forty people for. Posts by people in this
  room. Guard it.
- **The reader** — feeds you subscribe to. A river you visit. `CLAUDE.md`'s
  first sentence already promises one: *"a reader for your friends' private
  blogs"*. See *"RSS is a transport"* below.
- **A stream** — `/@dkam/listening`, `/@dkam/reading`. Ambient, visited, never
  pushed. Volume costs nothing here because nobody is interrupted.
- **Attached to a post** — the ride the writeup is about, the link being
  discussed.

Within a person, the same ordering: what they wrote leads, their exhaust
trails. A post from three weeks ago outranks a scrobble from three minutes ago,
on a profile page and everywhere else.

That is how "exhaust is secondary" gets built without an algorithm anywhere
near it. Kinds are ranked once, globally, in code you can read; **within** a
kind it stays strictly chronological. No scoring, no engagement, no per-viewer
opinion — which is the whole point, and the reason this does not violate the
no-algorithmic-feed rule.

One consequence worth stating: exhaust does not interleave well with *itself*
either. Fifty scrobbles a day and one book a fortnight in a single river means
the book is never seen. A profile shows a section per kind, each capped at a
handful, each linking to its own full stream.

---

## The shape

Three new things. `posts` does not change.

### `entries` — the emitted record

STI, the way `actors` already does it.

```
actor_id      # whose. Actors, not members — a remote actor's exhaust arrives
              # the same way a remote actor's posts will, and hangs in the
              # same place.
type          # Scrobble | Checkin | Workout | Photograph | Reading | Bookmark
occurred_at   # when it happened in the world. Not created_at: a Saturday ride
              # synced on Tuesday belongs on Saturday.
published_at  # nullable, and the same trick posts play. NULL is "imported,
              # not shared".
audience      # the same enum as posts, extracted to a concern so there is one
              # definition of "public" in the app rather than two.
source_id
external_id   # unique with source_id. Re-syncing is idempotent.
uri           # the canonical link out: the track, the activity, the article.
data          # JSON. The kind-specific facts.
```

`published_at` generalising to *"imported but not shared"* is the part that
earns its keep: importers can be greedy and stupid, pulling everything, and
nothing is visible to anybody until somebody says so — by the rule that already
exists rather than a second one bolted alongside it.

### `sources` — my account on a service

Credentials, encrypted, on `members` rather than `actors`, for the same reason
`role` and `time_zone` live there: only local people hold credentials. Carries
`kind`, config, `last_synced_at`, a cursor, and a default for how entries
arrive — scrobbles arrive published, rides and Immich photos arrive as drafts.
Nobody hand-publishes fifty songs a day, and nobody auto-publishes a GPS track.

### `post_entries` — the join

A post attaches entries; an entry may appear in more than one post.

This little table is what buys the most, because it means **comments,
notifications, `feed_items` and `Visibility#post?` are untouched.** A ride is an
entry: private, factual, imported. Wanting to say something about it means
writing a post and attaching it. Comments land on the post, where they already
work. No polymorphic `comments.post_id`, no polymorphic `feed_items`, no second
fan-out path, no second thing that can disagree with the first.

---

## Two ways in, and the asymmetry *is* the privacy model

**My own data comes through `sources`** — authenticated, rich, and as complete
as the service will give up. Strava's GPS, Immich's originals, ListenBrainz's
full history.

**Everyone else's comes through a feed they publish.** Following `andy@last.fm`
is following an RSS feed; `FeedActor` already covers it and no last.fm adapter
needs to exist. Andy's blog is another feed, another actor. What can be known
about Andy in this Kith is exactly what Andy's services publish to anyone
asking.

That asymmetry is not an implementation detail to be tidied up later. It is
what makes the consent rule structural instead of a policy somebody has to
remember:

> **Kith never shows you exhaust you could not have fetched yourself from the
> source.**

A policy can be forgotten. A missing code path cannot. If a credentialed
connector for *other people's* accounts is ever added, this protection is gone
and nothing will fail to warn about it — so don't.

### The follow edge is the subscription

An accepted `Follow` to an actor whose domain is a feed **is** the instruction
to poll. There is no separate subscriptions table. Unfollow and polling stops.
Interest and subscription are one fact; stored twice, they drift.

Follows to a feed actor accept on creation — there is nobody on the other end
to ask. That rule is needed for RSS regardless, so it is one rule, not two.

---

## What may enter, about people who never joined

Kith has one object deciding what *leaves* (`Visibility`, and `ErrorReport` for
the other reader). This is the mirror image and it has no object yet: what
**enters**, about someone who never agreed to be in a private network.

Poll Andy's last.fm and store it, and a member who has never met Andy is one
page from his listening history, inside a network he did not join, under a name
he did not put there. Andy set no audience, and nobody may set one for him.

- A remote actor's entries are visible to the members who follow that actor,
  and to nobody else. They carry no audience of their own, because their
  subject never granted one.
- They never fan out. Fan-out is for posts — for things somebody chose to
  publish.
- **When it goes private upstream, the cache goes too.** A feed that starts
  returning 404 should cause a delete, not a shrug. Otherwise Kith has quietly
  converted a revocable disclosure into a permanent one — the same shape as the
  `Referer` problem in `CLAUDE.md`'s error-reporting notes: the copy outlives
  the original, and nobody is looking at the copy.

---

## One person, several accounts

Andy is `andy@last.fm`, a numeric id on Strava, a handle on TBDB, and one day
`andy@his-own-kith`. Each is its own `actors` row — each has its own handle, its
own feed, its own follow edge — and a second table says they are the same
person.

```
actor_links(actor_id, linked_actor_id, state, confirmed_at)
  unique on the pair
```

That is `follows` with the nouns changed, deliberately, because it has the same
lifecycle and the same reason for it.

**Link; do not merge.** Folding one actor into another and repointing the
foreign keys is destructive, and the belief it rests on can be wrong — it was
a different Andy. "Andy" is then the **transitive closure of accepted links**,
derived and never stored, exactly the way `Actor#connected_to?` derives a
connection from two follows rather than keeping a connections table. Four
accounts, one person, no canonical row to be wrong about, and retracting a link
is an update rather than an excavation.

### Who may say that two accounts are one person

This is the whole problem, and it is not a schema question.

Anyone who can assert *"`andy@last.fm` is Andy"* can also assert *"`andy@last.fm`
is Carol"* — and now Carol's profile carries a stranger's listening history,
under her name, in front of forty people who trust that name because this is an
invite-only network and a name here is assumed to be true. That is an
impersonation primitive, and it is worse inside a private network than outside
one.

So a link is a claim the other side confirms, `requested → accepted`, for the
same reason a follow is. Three tiers:

- **Self-claimed** — connecting your own account through `sources`.
  Credential-backed and proved; no confirmation needed.
- **Claimed and confirmed** — you think that account is Andy, and Andy accepts.
  Global from that moment; renders as one person for everyone.
- **Claimed, unconfirmed** — your private annotation, and *only* yours. A
  nickname. Nobody else's view may change. An unconfirmed claim that rendered
  globally is the attack.

When a link is confirmed, the linked actor's own audience rules take over —
including, if they have set themselves `invisible`, over a pile of data that
was gathered before they had expressed any preference about being seen. The
moment of confirming is the right time to ask them what should happen to it.

### A blog proves itself, and `sources` is not the only way

The self-claimed tier does not need a credentialed connector. Andy puts
`rel="me"` on his blog pointing at his Kith profile, and links the blog from
that profile; Kith fetches once and checks both directions. Two-way `rel="me"`
is what Mastodon's verified links and IndieAuth already do, it is about twenty
lines, and it means the strongest tier is available to anything with an HTML
page — which is most of what anybody wants linked.

### One face, two switches

This is the trap, and it is social rather than technical. Andy on this Kith and
`andy@his-blog.com` are two actors with two follow edges. Render them as one
person by all means — one avatar, *"also writes at his-blog.com"* — but **do
not give the merged face one follow button.**

One of those edges is a public feed. The other is a private account Andy
personally approved. Collapse them and somebody who only wanted less blog noise
has silently walked out of his circle, and the first either of them knows is an
awkward conversation. The follow edge *is* the subscription; two subscriptions
cannot hide behind one toggle.

Two smaller consequences of a merged face:

- **A merged profile is a union across two audiences** — his Kith posts are
  followers-only, his blog is public. One page, two answers to "may I see
  this". `Visibility` handles it per record, but `VisibilityTest`'s
  predicate-versus-scope cross-check has to run over the *union*, or the merged
  profile and a permalink disagree. That is the drift the tests already guard,
  with a new way in.
- **`discoverable: invisible` and a public blog contradict each other**, and
  only Andy can say what he meant. Unresolved, and the moment of confirming is
  when to ask — the same question this document already raises about data
  gathered before anybody consented to it.

### The federation seam is free

`actor_links` is `alsoKnownAs` and `Move` in ActivityPub terms — the actual
mechanism for account migration. It would have been needed the first time
somebody moved servers. It is not speculative machinery.

---

## The kinds — an inventory, not a roadmap

Written 2026-09-23, to size `entries` against something wider than the two or
three kinds anybody feels like building first. **Nothing here is a commitment
to build it, and this list is not maintained** — it is a sweep of what
plausibly arrives, so the schema is wide enough when the first kind is real.
Most of these will never exist.

Three shapes, and the shape decides the renderer and whether `uri` means
anything at all.

### Measurements — a number at a time

The series is the thing; no single row is interesting, and there is nothing to
link out to. Renders as a chart. `uri` is always NULL.

These want **one `Measurement` class with a `metric` key in `data`**, not a
class each: weight and VO2 max differ by a string and a unit, and nothing else.

| metric | source | note |
|---|---|---|
| weight | scale, Health, typed | **never publishable** — see `Snapshot` below |
| vo2max | watch | derived upstream; arrives as its own dated record |
| mood | typed | LiveJournal's current-mood. Belongs here, not with occurrences |
| resting_hr | watch | |
| sleep | watch | duration, not an instant |
| blood_pressure | cuff, typed | **two numbers in one reading.** `data` holds a reading, not a scalar |
| steps | watch, phone | **a daily total, not a moment.** `occurred_at` is a day |

The last two are the ones that stress the shape. Neither is a reason to grow a
column — `data` is JSON — but a `Measurement` renderer that assumes one scalar
at one instant will be wrong for both.

**A run's distance and duration are not measurements.** They are facts of an
occurrence and live in its `data`. A `Measurement` row is a number taken on its
own. Exploding a ride into six measurement rows is the mistake this distinction
exists to prevent.

### Occurrences — a discrete thing that happened

Interesting individually, with a canonical `uri` back to the source. Renders as
a list of cards.

| kind | source | note |
|---|---|---|
| Scrobble | last.fm, ListenBrainz | the volume case: ~50/day. Must never reach a feed |
| Workout | Strava | GPS payload, radius-trimmed on import. Arrives as a draft |
| Checkin | Swarm-ish, typed | followers-only even where posts are public; consider a delay |
| Reading | TBDB | three entries per book, not one mutable row |
| Watching | Letterboxd | same shape as Reading, one event or three |
| Listening (podcast) | pocketcasts &c. | scrobble-shaped, lower volume |
| Playing | Steam | |
| Pushing | git forge | **exhaust a machine emits on your behalf.** Still yours |
| Photograph | Immich, Flickr, Kith | bytes copied in, never hotlinked. Arrives as a draft |
| Attending | typed, Songkick-ish | a gig, a talk. The first entry with a **future** `occurred_at` — an intention, not a record. `Join`/`Attend` in ActivityStreams |
| Arriving | typed | coarse checkin at city scale. "Who is in Melbourne this week" without pinning a street |
| Drinking | Untappd-ish, typed | the checkin's natural twin |
| Cooking | typed | a meal made; pairs with a photo, which is the post |
| Donating | typed | blood, money. The one purchase-shaped thing nobody minds sharing |
| Acquiring | typed | a record bought, a book found. Sensitive — the thing, never the receipt |

`Pushing` is worth keeping on the list precisely because it is the least
personal: it proves `actor_id` means "whose exhaust", not "who was present".

### Snapshots — a series, frozen

A `Snapshot` is a range of measurements with the points copied into `data` at
the moment somebody published it. It exists because **publishing a graph and
publishing eight hundred rows are different acts**, and the second is a
trapdoor.

A post's audience is fixed at publication. A chart reading live from a growing
series is not fixed — a post from March silently gains April's numbers, which
is the second fact disagreeing with the first, again. Freezing the points is
what makes a published graph obey the rule every post already obeys.

What it buys is that **`Measurement` need never be publishable at all** — not
private-by-default-until-you-flip-it, but absolutely, with no audience control
on it anywhere. Only snapshots of it are publishable. One fewer switch that can
be wrong, and the switch that does exist is attached to a deliberate act.

One mechanism, several features: the glowup graph, *your year in books*, *your
week in music*. A recap is a snapshot somebody was offered as a draft.

### Objects — a thing noted

`occurred_at` is when it was noted, not when it happened. The row is about
something in the world; the actor is the one who noted it.

| kind | source | note |
|---|---|---|
| Bookmark | typed, extension | the unfurl lives in `data`. Says so if a post attaches it |
| Wishlist | booko | a *watch*, and the watch is the durable part — not the alert |

### A checkin wants a `Place`, and a photo cannot quietly become one

Two notes that only surface once checkins are real.

**`StripMetadataJob` has already destroyed the GPS**, unconditionally and
asynchronously, moments after the direct upload lands. So turning a photograph
into a checkin cannot read the coordinate off the stored file — it has to be an
**offer made in the composer, once, before the strip runs**, and discarded if
not taken. The strip stays unconditional. Never infer a checkin, and never hold
a coordinate because it might be wanted later: that is how a photograph of a
child at home becomes a pin on the front door.

Nor is it a *conversion*. A photograph and a checkin are two entries that one
post attaches; conversion implies destroying one of them.

**A `Place` is the first shared noun in the whole design.** Every other entry
is personal — "The Dancing Goat" is the same cafe for everybody. That is a real
fork: freetext and coordinates in `data` (cheap, and there is no page), or a
`places` table (dedupe, a gazetteer to keep, and *"my favourite cafe"* becomes
somewhere you and your friends both land). The page is the thing anybody
actually misses about checkins, so the table probably wins in the end — but
`data` first is not a wrong turning, only a smaller one.

### Not exhaust, and the list is more useful for saying so

- **A price-drop alert.** Nobody did anything and the subject is a book, not a
  person. Storing it makes `entries.actor_id` mean "whose life" for every other
  kind and "who is watching" for this one. The book is a `Wishlist` entry; the
  drop is a notification against it. (`notifications.actor_id` is `null: false`
  and means "who did this" — a webhook has no actor. That wants an answer
  before this is built, and it is a smaller question than overloading entries.)
- **"Now playing".** Derived — `MAX(occurred_at)` over scrobbles. Not a row,
  and not a column on anything.
- **Presence / online status.** Not stored. Not wanted.
- **A continuous location trace.** Not event-shaped, and the most dangerous
  data in the building. A checkin is a decision; a trace is surveillance. Kith
  strips GPS from photographs — it does not then collect it by the minute.
- **Your own blog's RSS.** That is a *post* by another actor of yours, reached
  through `actor_links`, not exhaust. The test is the one at the top of this
  document: somebody chose words and pressed publish.

### What the inventory says about the schema

Nothing in `The shape` above has to change — which is the point of having
written it down. Specifically:

- `data` as JSON absorbs a blood-pressure pair, a GPS track's summary and an
  unfurl without a column each.
- `uri` has to be genuinely nullable: every measurement lacks one.
- `occurred_at` is sometimes a day rather than a moment (steps, a book
  finished). Store the timestamp; let the renderer decide what to show.
- `source_id` has to be nullable. Weight, checkins and bookmarks are typed in
  by hand as often as they are synced, which also means `(source_id,
  external_id)` uniqueness must tolerate a NULL source.
- The audience enum needs a **`private`** value — for a bookmark kept to
  yourself and a checkin logged but not shared. `published_at: NULL` is the
  wrong tool for those: it says "unfinished", and the first `Entry.live` scope
  anybody writes would drop them out of their owner's own stream.
  `Measurement` is stronger than a default here — it sits at `private` and has
  no control to leave it.
- `occurred_at` is occasionally in the **future** (`Attending`). Any scope that
  assumes otherwise — a naive `Entry.live` copied from `Post.live` — will hide
  exactly the entries whose whole point is that they have not happened yet.

---

## RSS is a transport, not a kind

The same protocol carries a friend's blog — **posts**, somebody chose words and
pressed publish — and their last.fm or Letterboxd feed, which is **exhaust**.
The XML does not say which, so the `FeedActor` has to: you declare what a feed
is when you subscribe, once, and it does not change.

**Subscribed feeds go to the reader, not the feed.** Not as a rank below
friends' posts — as a different surface. Ranking by transport is the wrong
argument anyway (Andy on his blog is still Andy); the real line is *written for
this room* versus *published to the world*, and a separate surface says that
without having to defend a tier.

What it buys is worth more than the tidiness: **the only way an item reaches
forty people is that a human wrote a sentence about it.** That is the
no-boosting rule enforced by an absent code path rather than by a policy
somebody has to remember — the same move as the consent rule above.

### Promotion is a link post, and it must cost a sentence

The machinery already exists: a link makes a `Bookmark`, and saying something
about it makes a post that attaches it. From the reader it is one gesture —
promote, composer opens, bookmark attached.

The line it must not cross is the quote-repost. The test is simple: **does it
require your words?** A link post publishable empty is a boost with extra
steps, and `Post#must_say_something` is already the guard:

```ruby
def must_say_something
  return if title.present? || body.present?
```

Attaching an entry must **never** satisfy that. The day it grows
`|| entries.any?`, Kith has reposting, and the changelog will say "allow
link-only posts".

Two smaller ones:

- **Cards for outside, plain links for inside.** An unfurl card for an external
  URL is a citation. The same card rendering a friend's Kith post inside yours
  is a quote-post. Link to their permalink in prose.
- **Do not double-store.** If the URL is already in Kith as a remote post from a
  feed you follow, the bookmark points at that post rather than unfurling it
  again. `posts.uri` is the key, and it is already a nullable column meant for
  exactly this. The mirror of the rule that a bookmark written about should say
  so.

---

## The hub, and what the old web did well

Not exhaust and not events — profile furniture, which is the other half of
"a hub for you on the internet". Cheap, and mostly already paid for:

- **A now page.** nownownow.com, and `.plan` before it. **The one thing in Kith
  that is deliberately mutable** — no history, no versions, just what you are
  doing at the moment. Worth saying out loud because everything else here is
  append-only.
- **Elsewhere.** Your other accounts, from `actor_links`. Nearly free, and the
  most literal answer to "a hub".
- **Blogroll.** Who you follow, published. The cheapest federation seam there
  is.
- **Interests.** The LiveJournal list, which *was* the discovery mechanism
  before search existed — and Kith has no search. Forty people and a shared
  word is enough.
- **Current rotation.** A few records you chose to point at. A human pick over
  the exhaust, and the antidote to a scrobble stream nobody reads.
- **Tags**, on bookmarks first. The seam for search when it comes.
- **Guestbook.** Comments on a profile rather than a post. A moderation
  nightmare at scale; at forty people, just nice.
- **On this day** — private resurfacing only, never a push. A notification
  about a dead friend is why this feature has the name it has.

**Rejected on sight:** streaks (coercive by design), mayorships, karma, flair,
leaderboards, displayed follower counts, Top 8, read receipts. Same rule as
*no likes*, arriving each time in a different hat.

---

## Per-kind notes

**Music** (last.fm / ListenBrainz) — the highest-volume exhaust and the one
that must never reach a feed. Own history through `sources`; other people's
through their feed. "Now playing" on a profile is a `MAX(occurred_at)`.

**Links** — a saved link makes a `Bookmark` entry, always, with the unfurled
title, site, excerpt and image in `data`. Wanting to say something about it
makes a post that attaches it; offer that as an option at the moment of adding,
so the common case is one step. One card renderer serves the stream and the
post. A bookmark that has been written about should say so and link to the
post, or the same thing appears twice with no relation shown.

**Reading** (TBDB) — the one that is not event-shaped. A book goes
want-to-read → reading → finished, and the naive model is one row that mutates.
Make it **three entries, not one mutable row**: each with its own `occurred_at`,
the timestamp being the whole fact. That gives "started in March, finished in
June" and "twelve books this year" for nothing, and it is the same lesson
`published_at` already taught — a status column beside a timestamp is a second
fact waiting to disagree with the first.

**Checkins** — `Arrive` in ActivityStreams, which is a pleasant sign that the
vocabulary was expecting this. A public checkin is not a public post: a post
says where somebody was, a checkin says where they are *now*. Followers-only by
default even where posts are not, and a delay is worth considering. This is
also the kind most likely to want to leave the instance one day, to whatever
public checkin service still exists — which is `leaves_the_instance?` on an
entry, the same rule posts already obey.

**Fitness** — **a ride is a GPS track of your house.** Kith already strips EXIF
including GPS because location is dangerous; a ride is location as the entire
payload, and every ride starts and ends at the front door. Trim by radius on
import, default on, and store only the trimmed track — not a display filter
over a full track that some later endpoint serves whole. Same instinct as
`StripMetadataJob` rewriting the blob in place rather than keeping the original
around.

**Photos** (Immich) — **copy, do not hotlink.** An `<img src>` pointing at
Immich breaks the rule that `MediaHelper` is the only thing in the app that
turns an attachment into a `src`, sends a `Referer` carrying the Kith URL to
another server, and puts the photograph behind a second authentication system
Kith has no opinion about. Pull the bytes in as ordinary Active Storage blobs
and every existing media rule applies unchanged, EXIF stripping included.

---

## Things that will bite you

- **Attaching widens audience, and that is the sharp edge.** A private ride
  attached to a public post is public. That is intended — it was chosen — but
  it means `Visibility` cannot answer "may I see this entry?" in isolation. The
  signature is `entry?(entry, in: post)`, the composer must say out loud what
  attaching does, and `VisibilityTest`'s predicate-versus-scope cross-check has
  to cover entries the way it covers posts. If that pair drifts, a stream page
  and a permalink end up holding different opinions about the same ride.

- **`HANDLE_FORMAT` is too strict for the outside world.** `Actor` enforces
  `/\A[a-z0-9_]{2,32}\z/` on *every* actor, remote included. last.fm allows
  hyphens, Strava identifies people by numeric id, and plenty of services allow
  dots and forty characters — `andy-b@last.fm` fails validation today. The rule
  is right for local handles, which are claimed and ought to be tidy, so it
  wants to move to `LocalActor` with something looser on the remote subclasses.

- **`/@:handle` has no room for a domain.** `Actor#to_param` returns the bare
  handle, and the unique index that keeps handles unambiguous is
  `where domain IS NULL` — local only. A local `andy` and `andy@last.fm` both
  want `/@andy`. Mastodon's `/@andy@last.fm` is the obvious answer, and it is
  cheaper to decide before there are links in the wild pointing at the old form.

- **`Post#must_say_something` is load-bearing and does not say so.** It is the
  only thing standing between a link post and a quote-repost, and it looks like
  an empty-form guard. Anybody adding attachments to posts will be tempted to
  widen it. Don't.

- **Volume on SQLite is fine, as long as nothing fans out.** Fifty scrobbles a
  day across forty members over five years is a few million rows, which SQLite
  reads happily off an index. The same data multiplied into `feed_items` is
  not, and is also not wanted.

## What phase 1 must not close

Nothing, as it happens — the seams are all open, which is why none of this is
urgent.

`notifications.subject` is already polymorphic. `audience` is already
integer-backed and sparse. `Visibility` grows by addition. `posts.uri` is
already there. `comments.post_id` and `feed_items.post_id` stay
**non**-polymorphic, and the attach-to-a-post design above is precisely what
keeps them that way.

Build phase 1 and stop.
