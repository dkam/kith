# Changelog

Kith's release version is `Kith::VERSION`, in `config/version.rb`, and changing
it is what cuts a release. Nothing has been released yet, so entries here are by
the day the work landed, newest first, and each says why as well as what. Once
there are releases to hang them on, these group under version headings instead.

The MCP server carries its own number, `McpServer::VERSION`, because it is a
published interface with clients on the other end of it. It moves when its tools
do, independently of the release version.

## 2026-09-18

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

### Password resets happen in the console

`Member.reset_password!` takes an email address or a handle, makes a password
up if you do not give it one, returns it for the console to print, and signs
the member out everywhere. There is no mail flow, and for a few dozen friends
there does not need to be one — the operator is reachable.

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

## 2026-09-16

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
