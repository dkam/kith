require "application_system_test_case"

class SettingsTest < ApplicationSystemTestCase
  # A 1x1 PNG, the smallest thing that is honestly an image.
  PIXEL = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

  setup { sign_in_as members(:alice) }

  test "pasting a photo onto the settings page" do
    visit settings_path
    assert_no_selector "img[src^='blob:']"

    paste_image

    assert_selector "img[src^='blob:']", wait: 5
    click_on "Save"

    assert_text "Saved."
    assert actors(:alice).reload.avatar.attached?
  end

  test "saying where you are" do
    visit settings_path
    select "Melbourne", from: "Where you are"
    click_on "Save"

    assert_text "Saved."
    assert_equal "Melbourne", members(:alice).reload.time_zone
  end

  test "pasting words rather than a photo leaves the photo alone" do
    visit settings_path

    paste_text "not a photograph"

    assert_no_selector "img[src^='blob:']"
    assert_not actors(:alice).reload.avatar.attached?
  end

  private
    def paste_image
      page.execute_script(<<~JS, PIXEL)
        const binary = atob(arguments[0])
        const bytes = new Uint8Array(binary.length)
        for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)

        const transfer = new DataTransfer()
        transfer.items.add(new File([bytes], "pasted.png", { type: "image/png" }))

        document.body.dispatchEvent(new ClipboardEvent("paste", {
          clipboardData: transfer, bubbles: true, cancelable: true
        }))
      JS
    end

    def paste_text(text)
      page.execute_script(<<~JS, text)
        const transfer = new DataTransfer()
        transfer.setData("text/plain", arguments[0])

        document.body.dispatchEvent(new ClipboardEvent("paste", {
          clipboardData: transfer, bubbles: true, cancelable: true
        }))
      JS
    end
end
