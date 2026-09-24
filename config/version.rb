# frozen_string_literal: true

# Kith's release version — SemVer, bumped by hand at meaningful milestones.
# Single source of truth: required early from config/application.rb, read by
# both release pipelines — bin/build, which publishes to git.booko.info, and
# .github/workflows/build.yml, which publishes to ghcr.io — tagged as vX.Y.Z,
# and shown on the settings page. Lives in its own file so a build script can
# read it (`ruby -e "require './config/version'; puts Kith::VERSION"`) without
# booting Rails.
#
# Bumping this on main *is* the release. See CHANGELOG.md, and "Releases" in
# CLAUDE.md. A pre-release (anything with a hyphen, e.g. "0.2.0-dev") publishes
# its own image tag but does not move :latest and does not tag the commit.
module Kith
  VERSION = "0.2.0"

  # The oldest phone app this instance will talk to, published in its NodeInfo
  # so a shell can say "this Kith needs a newer Kith" rather than failing in
  # some interesting way three screens later. A third number again: it answers
  # "what does the server require of a client", which is neither what release
  # this is nor what commit it is.
  MINIMUM_NATIVE_VERSION = "1.0.0"
end
