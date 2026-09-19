# frozen_string_literal: true

# Kith's release version — SemVer, bumped by hand at meaningful milestones.
# Single source of truth: required early from config/application.rb, and read by
# .github/workflows/build.yml, where changing it *is* cutting a release. Lives in
# its own file so a build script can read it
# (`ruby -e "require './config/version'; puts Kith::VERSION"`) without booting
# Rails.
#
# A pre-release (anything with a hyphen, e.g. "0.2.0-dev") publishes its own
# image tag but does not move :latest and does not tag the commit.
module Kith
  VERSION = "0.1.0-dev"
end
