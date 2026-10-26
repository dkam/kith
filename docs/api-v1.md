# The native API, v1

A plan, written 2026-10-26 for Janek to build from, at the request of the
kith-ios session (Scarlett); kith-android (Belinda) follows the same plan.
**Nothing here is built.** When it is, the rules that survive move into
`CLAUDE.md` and this file becomes history, as `docs/phase-two.md` will.

---

## What it is, and what it is not

The phone apps are **Hotwire Native shells**. kith-web already serves what a
shell needs: NodeInfo carrying `minimumNativeVersion` and `pathConfiguration`,
the path configurations at `/configurations/ios_v1` and `android_v1`, and the
`hotwire_native` request variant. The feed, posts, comments, profiles,
notifications, the composer and media are the web, in a WebView, under the
WebView's own session cookie.

So this API is **only what native code needs**, which is two things:

1. **A device token**, minted through the web's own sign-in, for native code
   that runs without a WebView — mostly background ride uploads.
2. **The workout upload.**

The phone does not trim. Decided with dkam, 2026-10-26: *the only time to
strip location is when sharing*, so the app uploads the whole ride, its owner
sees it whole, and the server trims it once when it is first shared
(`docs/phase-two.md` → *Fitness*).

There are no endpoints for posts, the feed, comments, profiles, notifications
or media, and there should not be: a second way to read a post is a second
place for `Visibility` to be forgotten. Anything a phone wants to *show* is a
web page.

---

## Rules for the whole API

- **Versioned in the path**, `/api/v1/…`. Like the path configurations, v1 may
  gain fields and endpoints but may never change what one already means; a
  shipped build keeps asking for the shape it was written against. When a
  meaning has to change, that is v2.
- **NodeInfo says which versions exist**: `metadata.nativeApi: ["v1"]`. An app
  pointed at an older Kith reads that before offering sign-in, rather than
  finding out from a 404 halfway through.
- **One error shape**, everywhere:

  ```json
  { "error": { "code": "invalid_track",
               "message": "Segment 3 has times that go backwards.",
               "pointer": "/track/properties/times/2" } }
  ```

  `code` is from a fixed list (below) and is what the app branches on;
  `message` is a sentence for a developer; `pointer` is a JSON Pointer into the
  request when one part of it is to blame. **A message never contains a
  coordinate**, a name or a token — it is echoed into the app's logs.
- **Actor ids, never member ids**, in every payload. The actor is the identity
  the rest of Kith (and one day federation) speaks in; the member is the
  credential holder behind it.
- **The API is write-only for location.** It never returns a track, a
  photograph's place, a checkin or a life-log entry, not even to their owner.
  A phone that wants to show one opens the web page, where `Visibility`
  decides which copy, if any, the viewer gets. A stolen device token can add
  data and never read anyone's whereabouts.
- **Bearer tokens only**: `Authorization: Bearer <token>`. Never in the query
  string — unlike `/mcp`, every caller here can send a header, and a query
  string ends up in proxy logs. The API controllers descend from
  `ActionController::API`, as `McpController` does: no cookies, no CSRF, no
  session resumed even if a cookie is present.
- **401, not 404, for a missing, unknown, revoked or expired token**, with
  `WWW-Authenticate: Bearer`. This is not a break from *"404, never 403"*: that
  rule protects the existence of *records*, and the existence of `/api/v1` is
  in the source code. The app has to tell "sign in again" from "that ride is
  gone", and a 404 for both would make it guess. Records keep the old rule — a
  workout that is not yours is a 404, the same as one that never existed.

| status | `code` | meaning for the app |
|---|---|---|
| 400 | `invalid_request` | malformed JSON or a missing parameter. A bug; don't retry |
| 400 | `invalid_code` | the sign-in code is unknown, used, expired or the verifier is wrong. Start sign-in again |
| 401 | `invalid_token` | sign in again |
| 404 | `not_found` | no such thing, or not yours |
| 409 | `published` | that workout is already published; nothing more to do |
| 409 | `edited` | its owner edited that draft on the web; nothing more to do |
| 413 | `too_large` | the body is over the cap. Permanent |
| 422 | `invalid_workout`, `invalid_track` | the payload breaks a rule. Permanent: fix or keep locally, never retry |
| 429 | `rate_limited` | back off; `Retry-After` says how long |

A 422 is permanent, but **the app should keep the ride rather than discard
it** — mark it refused, let the member export it. A server bug that 422s every
ride for a week should not cost anybody their rides.

---

## Signing in: a device token through the web's sign-in page

Decided with dkam (via kith-ios, 2026-10-26): **the app never handles a
password, and Kith does not become an OAuth or OIDC provider.** No ID tokens,
no JWTs, no discovery document, no client registration or secrets, no scopes,
no refresh tokens. There is one client — the Kith app — and it is fixed and
public. What remains is three small pieces: a consent page, a single-use code
bound to a PKCE challenge, and an exchange of that code for a device token.

Whatever the web sign-in gains later — passkeys, OIDC through Clinch — the app
gains on the same day, because it signs in through the web page.

### The flow

1. The member signs in **in the WebView** at `/session/new`, as on the web.
2. The shell loads the consent page in the same WebView:

   ```
   GET /devices/authorize?code_challenge=…&code_challenge_method=S256
                         &state=…&redirect_uri=kith://auth&name=Dan%27s+iPhone
   ```

   It is an ordinary page behind the ordinary session. Signed out, it bounces
   to `/session/new` and comes back, as every page does.
3. It asks *"Allow Kith for iPhone to use your account?"*, with the device name
   editable (prefilled from `name`, at most 80 characters).
4. **Allow** posts the form; the server stores a code and answers
   `303 See Other` to `kith://auth?code=…&state=…`. **Cancel** answers
   `kith://auth?error=access_denied&state=…`. The shell intercepts the
   navigation to `kith://` itself.
5. The app exchanges the code:

   ```
   POST /api/v1/device_tokens
   { "code": "…", "code_verifier": "…" }
   ```

   ```json
   201
   { "token": "…",
     "device": { "id": 7, "name": "Dan's iPhone" },
     "actor": { "id": 1, "handle": "dkam", "display_name": "Dan" } }
   ```

   The token is shown **once**, here, and never again.

### The rules that make it safe

- **It only ever authenticates a member who already exists.** There is no path
  from this flow to a new member; joining is still an invite link on the web.
  An identity provider must never be able to create a member, and neither must
  a phone.
- **`redirect_uri` must be exactly `kith://auth`.** Anything else is a 400 on the
  consent page, not a redirect: there is one client, so there is one place a
  code may go, and an open redirect is how codes get stolen.
- **S256 only.** `plain` is refused. `code_challenge` is 43–128 characters of
  base64url; `state` is required and at most 255 characters, echoed back
  untouched.
- **A code is single-use and lives 60 seconds.** It is stored as a digest, with
  the member, the challenge and the device name. **Any exchange attempt burns
  it**, right or wrong — a wrong verifier must not get a second guess.
- **The consent form has `data-turbo="false"`.** Turbo submits forms with
  `fetch`, and `fetch` cannot follow a redirect to `kith://`: the submission
  would fail as a network error, and the shell would never see the navigation
  it is waiting to intercept. A native form post makes the WebView navigate,
  which is what the shell's navigation delegate catches.
- **The consent POST keeps its CSRF token.** It is a web form like any other;
  without it, any page could auto-submit consent on a signed-in member's behalf.

### Device tokens

```
device_tokens
  member_id      not null
  name           not null, ≤ 80
  token_digest   not null, unique — SHA-256 of the token
  last_used_at
  created_at, updated_at
```

- **Stored as a digest**, unlike `mcp_tokens`. An MCP token is shown again on
  the settings page whenever its member asks; nobody ever needs to see a device
  token again after the exchange, so there is no reason the database should be
  able to produce one.
- **Separate from `mcp_tokens`** — a different grant, to a different kind of
  client — and **separate from phase two's `credentials`**, which are ways to
  sign in to the *web*. A device token signs in to nothing: it opens `/api/v1`
  and no other door. Same base58 generation as `McpToken`.
- **Listed in settings** — a *Devices* section with name, added, last used and a
  *Revoke* button. Revoking deletes the row.
- **Sign-out from the app** is `DELETE /api/v1/device_tokens/current`: 204, and
  the token is gone on the server as well as on the phone.
- **Expiry: 180 days without use** (dkam, 2026-10-26). Using the app keeps a
  token alive. Checked at authentication; an expired token is deleted and
  answered 401.

`GET /api/v1/me` answers `{ device, actor }` — the exchange's response without
the token. The app calls it on launch to prove the token still works.

---

## The track: whole on the way in, trimmed on the way out

The app uploads the ride exactly as recorded. Nothing about the trim reaches
the phone: no radius, no offset, no zones, no version. Ruby is the only
implementation, and the fixtures in `test/fixtures/files/trim/` test it alone.

The upload's job is to get the ride to its owner. Everything that protects it
happens later, on the server, when it is shared: the trim is cut once and
frozen as a second track, readers get that copy, and the friends a member has
named see the ride whole (`docs/phase-two.md` → *Fitness*). Privacy zones are
held on the server and managed on a web page, so they need no endpoint either.

---

## The workout upload

```
PUT /api/v1/workouts/:client_id
Content-Type: application/json
```

```json
{ "occurred_at": "2026-10-26T06:42:10+11:00",
  "data": { "name": "Morning ride",
            "activity_type": "ride",
            "source_activity_type": "HKWorkoutActivityTypeCycling" },
  "track": { "type": "Feature",
             "geometry": { "type": "MultiLineString",
                           "coordinates": [[[144.9631, -37.8136, 31.2], …], …] },
             "properties": { "times": [[0, 1, 2, …], …] } } }
```

- **`client_id` is a UUID the app makes** when the ride is saved. It becomes
  `external_id` under the member's `sources` row of kind `app` (created on first
  upload; one per member, not per device). It is what makes a retry harmless.
- **PUT, because it is idempotent**, and because a background `URLSession`
  upload task sends a file body with whatever method it is given. The body is
  one JSON document; a six-hour ride at one point a second is under a megabyte.
- **Responses**:
  - `201` — created, as a draft.
  - `200` — that `client_id` was a draft and has been replaced, or was already
    identical.
  - `409 published` — that workout has been published; it is never touched
    again. The app marks it synced.
  - `409 edited` — its owner has edited the draft on the web, and **the web
    edit wins**: an edited draft is treated like a published one, and the
    upload does not touch it. The app marks it synced. The common case of a
    200, a retry after a lost response, sends identical bytes and is unaffected.
    Nothing can edit a draft yet, so this answer arrives with the owner's
    workout page, which records when it last edited one.
  - `422` — see *Validation*.
- **The response never echoes the track.** It carries what was stored:
  `{ "workout": { "client_id", "occurred_at", "published", "data",
  "track": { "segments": 3, "points": 4120 } } }`.
- **`DELETE /api/v1/workouts/:client_id`** removes a draft the app uploaded by
  mistake: 204, or `409 published`, or 404.

### What the server keeps

- `occurred_at`, `name`, `activity_type` and `source_activity_type` from the
  payload. `activity_type` is Kith's vocabulary — `run`, `ride`, `walk`,
  `hike`, `swim`, `ski`, `snowboard`, `other` — and `source_activity_type` is
  the HealthKit or Health Connect type, verbatim.
- **`distance_m`, `moving_time_s` and `elevation_gain_m` as the app sends
  them**: they are the owner's own figures, as Strava's are for an import. If
  the app sends none and there is a track, the server computes them from it.
  A shared copy computes its own from its trimmed track when it is cut, and
  never shows these.
- No `elapsed_time_s`, and `uri` stays NULL.

### Validation

Strict, and a failure is a 422 naming the first problem. Unknown keys are
**ignored, not refused** — a newer app talking to an older Kith must not have
every ride rejected, and permanently, for a field the server does not know yet.

- `occurred_at`: ISO 8601 with an offset; not before 2000-01-01, not more than
  five minutes in the future.
- `activity_type`: one of the vocabulary. `name`: at most 200 characters,
  defaulting to the type's own word if absent. `source_activity_type`: at most
  100.
- `track`, if present:
  - a `Feature` whose geometry is a `MultiLineString`;
  - at least 1 segment, every segment at least 2 positions; at most 1 000
    segments and 200 000 positions in all. A ride with no positions is said
    one way, by leaving `track` out, so an empty `MultiLineString` is a 422;
  - every position `[lon, lat]` or `[lon, lat, ele]`, **the same length
    throughout**; longitude in [−180, 180], latitude in [−90, 90], every number
    finite; rounded to 6 places on the way in;
  - `properties.times`, if present, the same shape as the coordinates, whole
    seconds, each segment starting at **0** and never going backwards;
- The body: at most **10 MB** (open question 2), checked against
  `Content-Length` before it is parsed; 413 beyond it.

---

## Things that will bite

- **The track would be in the production log.** Rails logs the parameters of
  every JSON request, and the parameters of an upload are the GeoJSON. Add
  `track` to `config.filter_parameters` before the endpoint exists, with
  `code_verifier`. And `config.filter_redirect` for `kith://auth`, or the log
  line *"Redirected to kith://auth?code=…"* writes the code down.
- **`filter_parameters` matches by substring**, so adding `code` also filters
  `code_challenge` and the invite code in `/join/:code`. That is fine — say so
  in the comment, so nobody "fixes" it.
- **The Turbo redirect** — see `data-turbo="false"` above. The symptom is a
  consent button that seems to do nothing.
- **Path configuration parity.** If the consent page gets a rule (a modal, say),
  it goes in `ios_v1` *and* `android_v1`; a test asserts the two platforms'
  patterns are identical.
- **Rate limits**: the exchange at 10 a minute per IP, as sign-in is; uploads at
  120 a minute per token, because the first sync after install may be a year
  of HealthKit history.
- **Background uploads run with the phone locked**, so the app keeps the token
  in the Keychain as after-first-unlock. That is the app's half; the server's
  half is to make a stolen token worth as little as possible: digest, expiry,
  revoke, and a grant that opens `/api/v1` and nothing else. A stolen token
  can upload a ride or delete a draft; it can never read one.

---

## Seams — leave room, build nothing

- **Push notifications.** Later, `device_tokens` gains `push_platform` and
  `push_token`, and `PUT /api/v1/device_tokens/current/push` sets them. One rule
  to fix now: **a push payload is an export**, to Apple or Google, and gets the
  `ErrorReport` treatment — no names, no text, no titles. It says *"something
  new"* and carries a notification id; the WebView opens it, and `Visibility`
  answers there as it always does.
- **Checkins.** `PUT /api/v1/checkins/:client_id`, the same idempotent shape.
  Waits on the `Place` question in `docs/phase-two.md`. Never inferred: the
  phone may *offer* a checkin from a visit, and the member taps.
- **Duplicates across sources.** One Garmin ride can reach Kith through the
  Strava export and through the app's HealthKit backfill.
  `(source_id, external_id)` cannot see that, and nothing is built for it.
  Neither the importer nor the upload may assume it is the only way in, and
  the owner's drafts may one day mark a *possible duplicate*
  (`docs/phase-two.md`).
- **Life-log summaries.** Motion totals (minutes cycling, walking) are
  `Measurement`s, the shape of `steps`. Place totals — time at home, time at
  work — never leave the phone: a daily series of arrivals at work is a
  timetable for finding someone.
- **A token-to-session exchange**, for when passkeys move sign-in out of the
  WebView into `ASWebAuthenticationSession` / Custom Tabs, which do not share
  the WebView's cookies. Roughly: the device token buys a one-time, 60-second
  URL that the WebView loads to receive its cookie. It is the most dangerous
  piece in this document — a bearer token turning into a web session — so it
  is designed when it is needed and not before.

---

## Build order

Each is its own issue.

1. **#1, the Strava importer** — already underway. It builds `entries`,
   `sources`, `Workout`, `Track` and its readers and GeoJSON format, all of
   which the upload reuses, and the trim as a tested library for the issue
   that builds sharing.
2. **Device sign-in**: `device_codes`, `device_tokens`, the consent page, the
   exchange, `/me`, sign-out, the *Devices* section in settings, the NodeInfo
   `nativeApi` flag, and the log filtering.
3. **The workout upload**, once 1 and 2 are merged.

No new gems for any of it.

---

## Open questions for dkam

Decided 2026-10-26: the phone does not trim, the server does when a ride is
shared; privacy zones are held on the server; device tokens expire after 180
days unused; readers see a ride's exact start time.

1. **401 for a bad token**, rather than the 404 the MCP endpoint gives?
   Recommended: yes, for the reason above.
2. **A 10 MB cap on an upload?** Generous by a factor of ten for a long ride.
