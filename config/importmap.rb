# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Direct upload: photos go straight to storage, so the form post stays small
# and progress is visible while a phone-sized JPEG uploads.
pin "@rails/activestorage", to: "activestorage.esm.js"
