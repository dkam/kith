# Pin npm packages by running ./bin/importmap

pin "application"

# Loaded only from layouts/_pwa, which the phone apps never render. Not
# preloaded, because the map is emitted on every page and the apps would
# otherwise fetch a module they are never going to run.
pin "pwa", preload: false
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Direct upload: photos go straight to storage, so the form post stays small
# and the editor can draw a preview while a phone-sized JPEG uploads.
pin "@rails/activestorage", to: "activestorage.esm.js"

# The editor. Ships with the gem, so there is no build step and nothing to
# vendor.
pin "lexxy", to: "lexxy.min.js"
