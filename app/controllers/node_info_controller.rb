# What this instance is, for a machine that has only been handed a hostname.
#
# A phone app is typed a domain and has to decide whether there is a Kith
# behind it before it shows anybody a sign-in form. NodeInfo is what every
# other server in the fediverse already answers that with, so Kith answers it
# the same way rather than inventing a private document — and when federation
# lands, this is already the thing a remote server will read first.
#
# It says nothing about any member. Discovery of *people* is `Visibility`'s
# question and is asked elsewhere, at a different distance.
class NodeInfoController < ApplicationController
  allow_unauthenticated_access

  # The pointer document. Deliberately a separate request from the thing it
  # points at: that is the protocol, and it is how a client learns which
  # schema versions a server speaks before committing to one.
  def index
    render_publicly :index
  end

  def show
    render_publicly :show
  end

  private
    # Public for the same reason the path configuration is: identical bytes for
    # everybody, and no session consulted to produce them.
    def render_publicly(template)
      expires_in 1.hour, public: true
      render template, formats: :json
    end
end
