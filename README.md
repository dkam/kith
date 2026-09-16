# Kith

A private, invite-only network for a few dozen friends. A private blog with
photos, plus a reader for your friends' private blogs.

There is no public sign up, no reposting, no likes, and no ranked feed. Posts
are chronological, their audience is fixed when you write them, and every image
is served through a controller that re-checks who is asking.

It is built to federate with other Kith instances later, which is why anything
that can author or be followed is an `Actor` rather than a user. None of that
federation exists yet.

## Running it

Needs Ruby 4.0.6, and libvips for image processing:

```sh
brew install vips          # or: apt-get install libvips
bin/setup --skip-server
```

There is no sign up, so make the first member by hand. They are the only one
without an inviter; everyone else arrives through an invite from inside the app.

```sh
bin/rails "kith:first_member[you@example.com,yourhandle,Your Name]"
bin/dev
```

`bin/dev` runs the server, the Tailwind watcher, and the job worker. The worker
matters: posts reach people's feeds through a background job, so a bare
`bin/rails server` will look like nothing is happening.

## Checks

```sh
bin/rails test          # models, controllers, jobs
bin/rails test:system   # headless Chrome
bin/rubocop
bin/brakeman
```

`CLAUDE.md` has the design rules, the privacy model, and the things that will
bite you.
