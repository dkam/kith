require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    # Chrome's password manager and autofill compete with Capybara for the
    # sign-in fields, and its first-run dialogs swallow keystrokes meant for
    # the page underneath. We are testing our form, not theirs.
    options.add_argument("--disable-features=AutofillServerCommunication,PasswordLeakDetection")
    options.add_argument("--disable-search-engine-choice-screen")
    options.add_argument("--no-first-run")
    options.add_argument("--no-default-browser-check")
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("autofill.profile_enabled", false)
  end

  # Selenium clicks by coordinate. A page that is interactive before its
  # stylesheet has applied shifts under the pointer the moment it lands, and
  # the click hits nothing — which surfaces much later as a button that
  # inexplicably did not work. Wait for the paint, not just the markup.
  def visit(*)
    super
    wait_for_stylesheet
  end

  # Hands the browser a session cookie rather than driving the form.
  #
  # Signing in through the form is worth testing once — HappyPathTest does it,
  # with a password, from an invite — but doing it at the top of every scenario
  # adds no coverage and makes every test depend on headless Chrome reliably
  # accepting keystrokes into a password field, which it does not.
  def sign_in_as(member)
    session = member.sessions.create!

    visit new_session_path
    page.driver.browser.manage.add_cookie(name: "session_id", value: signed_cookie_for(session), path: "/")
    visit root_path
  end

  def sign_in_through_the_form(member, password:)
    visit new_session_path

    fill_in "Email", with: member.email_address
    fill_in "Password", with: password
    click_on "Sign in"

    assert_no_current_path new_session_path, wait: 5
  end

  def sign_out
    click_on "Sign out"
    assert_current_path new_session_path, wait: 5
  end

  # The composer is a contenteditable, not a textarea, so there is no field for
  # fill_in to find. Click into it and type, the way a person does.
  def compose(text)
    editor = find("lexxy-editor .lexxy-editor__content")
    editor.click
    editor.send_keys(text)
  end

  # The toolbar's image button appends a hidden file input to the editor and
  # clicks it — headless Chrome has no file dialog to open, so Capybara drives
  # that input directly. Lexxy removes the input a second later, hence the find
  # immediately after the click.
  def drop_photos(*paths)
    paths = paths.flatten
    find("lexxy-toolbar button[name='image']").click

    input = find("lexxy-editor input[type='file']", visible: :all, wait: 5)
    page.execute_script("arguments[0].style.cssText = 'opacity:1;display:block;width:1px;height:1px'", input)
    input.set(paths.map(&:to_s))

    # Waiting for an <img> is not enough: Lexxy draws the photo from a local
    # preview the moment it is chosen, and the signed id that names it in the
    # post only arrives when the direct upload finishes. Submitting in between
    # posts the words without the photographs — silently, because the editor
    # is showing them. The pending URL is the first thing that proves the
    # upload is done.
    assert_selector "lexxy-editor img[src^='/media/pending/']", count: paths.size, wait: 15
  end

  private
    # The same signed value ActionDispatch would have set, produced the same
    # way the integration-test helper produces it.
    def signed_cookie_for(session)
      jar = ActionDispatch::TestRequest.create.cookie_jar
      jar.signed[:session_id] = session.id
      jar[:session_id]
    end

    UNSTYLED_BACKGROUND = "rgba(0, 0, 0, 0)"

    def wait_for_stylesheet
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

      while page.evaluate_script("getComputedStyle(document.body).backgroundColor") == UNSTYLED_BACKGROUND
        raise Capybara::ExpectationNotMet, "the stylesheet never applied" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
    end
end
