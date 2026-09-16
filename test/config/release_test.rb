# frozen_string_literal: true

require "test_helper"

# Guards the seam between "cutting a release" and "the running app knowing what
# it is". Two different things share the word version here:
#
#   version  — which release this is. Hand-set SemVer in config/version.rb.
#   revision — which commit this container was built from. Automatic, precise.
#
# Both have the same failure mode: they go quiet rather than wrong. A GIT_SHA
# declared in the wrong stage is silently ignored by --build-arg, and every
# deploy from then on reports "unknown" with no error attached to it.
class ReleaseTest < ActiveSupport::TestCase
  test "the version is SemVer, and nothing else" do
    assert_match(/\A\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?\z/, Kith::VERSION,
      "the release workflow keys off this string: X.Y.Z, optionally -prerelease")
  end

  test "config/version.rb can be read without booting Rails" do
    # bin/build and the release workflow both read it this way, to decide the
    # image tag before there is an image to ask.
    out = `ruby -e "require './config/version'; puts Kith::VERSION"`.strip

    assert_equal Kith::VERSION, out
  end

  test "the Dockerfile declares GIT_SHA in the stage that uses it" do
    stage = Rails.root.join("Dockerfile").read.split(/^FROM /)[2]

    # An ARG is only in scope for the stage that declares it. Put it before the
    # FROM and --build-arg is ignored without complaint.
    assert_match(/ARG GIT_SHA=unknown/, stage, "GIT_SHA must be declared inside the build stage")
    assert_match(/RUN echo "\$\{GIT_SHA\}" > VERSION/, stage)
  end

  test "the revision is always answerable" do
    assert Rails.application.config.x.revision.present?
  end
end
