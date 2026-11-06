# Rails' own direct upload, behind a session. Active Storage's controller
# inherits from ActionController::Base rather than ApplicationController, so
# it never asked who was there: anybody could make a blob and be handed a URL
# to write into storage, with no cap on its size (kith-web#11).
#
# Only this first step is guarded. The PUT that carries the bytes is
# authorised by the token this hands out, and by nothing else.
class DirectUploadsController < ActiveStorage::DirectUploadsController
  include Authentication
end
