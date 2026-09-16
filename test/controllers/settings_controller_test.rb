require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as members(:alice) }

  test "showing your settings" do
    get settings_url

    assert_response :success
    assert_select "input[name='actor[display_name]'][value=?]", "Alice Brennan"
  end

  test "changing your display name" do
    patch settings_url, params: { actor: { display_name: "Alice B" } }

    assert_redirected_to settings_url
    assert_equal "Alice B", actors(:alice).reload.display_name
  end

  test "changing your discoverability" do
    patch settings_url, params: { actor: { discoverable: "invisible" } }

    assert actors(:alice).reload.invisible?
  end

  test "an invented discoverability is rejected" do
    patch settings_url, params: { actor: { discoverable: "nobody_at_all" } }

    assert_response :unprocessable_content
    assert actors(:alice).reload.connections_only?
  end

  test "the handle cannot be changed, even by asking nicely" do
    patch settings_url, params: { actor: { handle: "notalice", display_name: "Alice B" } }

    assert_equal "alice", actors(:alice).reload.handle
  end

  test "uploading an avatar" do
    patch settings_url, params: { actor: {
      avatar: fixture_file_upload("portrait.jpg", "image/jpeg")
    } }

    assert actors(:alice).reload.avatar.attached?
  end

  test "an avatar renders through MediaController, never a blob URL" do
    actors(:alice).avatar.attach(io: file_fixture("portrait.jpg").open, filename: "portrait.jpg", content_type: "image/jpeg")

    get settings_url

    assert_select "img[src^='/media/']"
    assert_select "img[src*='/rails/active_storage/']", false
  end

  test "removing your photo" do
    actors(:alice).avatar.attach(io: file_fixture("portrait.jpg").open, filename: "portrait.jpg", content_type: "image/jpeg")

    delete settings_avatar_url

    assert_redirected_to settings_url
    assert_not actors(:alice).reload.avatar.attached?
  end

  test "removing a photo you do not have is harmless" do
    delete settings_avatar_url

    assert_redirected_to settings_url
    assert_not actors(:alice).reload.avatar.attached?
  end

  test "removing a photo only ever removes your own" do
    actors(:alice).avatar.attach(io: file_fixture("portrait.jpg").open, filename: "portrait.jpg", content_type: "image/jpeg")
    sign_out
    sign_in_as members(:bob)

    delete settings_avatar_url

    assert actors(:alice).reload.avatar.attached?
  end

  test "the remove button appears only when there is a photo to remove" do
    get settings_url
    assert_select "form[action=?]", settings_avatar_path, false

    actors(:alice).avatar.attach(io: file_fixture("portrait.jpg").open, filename: "portrait.jpg", content_type: "image/jpeg")

    get settings_url
    assert_select "form[action=?]", settings_avatar_path
  end

  test "removing a photo requires signing in" do
    sign_out
    delete settings_avatar_url

    assert_redirected_to new_session_url
  end

  test "settings always act on your own actor, whatever the params say" do
    sign_out
    sign_in_as members(:bob)

    patch settings_url, params: { actor: { id: actors(:alice).id, display_name: "Bobby" } }

    assert_equal "Bobby", actors(:bob).reload.display_name
    assert_equal "Alice Brennan", actors(:alice).reload.display_name
  end

  test "settings require signing in" do
    sign_out
    get settings_url

    assert_redirected_to new_session_url
  end
end
