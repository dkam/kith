# frozen_string_literal: true

# Kith's release version — SemVer, bumped by hand at meaningful milestones.
# Single source of truth: required early from config/application.rb, read by
# bin/build and CI to tag the image, tagged as vX.Y.Z, and shown on the settings
# page. Lives in its own file so build scripts can read it
# (`ruby -e "require './config/version'; puts Kith::VERSION"`) without booting
# Rails.
#
# Bumping this on main *is* the release. See CHANGELOG.md.
module Kith
  VERSION = "0.2.0"
end
