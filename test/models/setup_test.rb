require "test_helper"

class SetupTest < ActiveSupport::TestCase
  test "setup is closed while anybody has joined" do
    assert Member.exists?
    assert_not Setup.open?
  end

  test "setup is open on an empty instance" do
    empty_the_instance

    assert Setup.open?
  end

  test "the code is twelve characters in three groups, from an unambiguous alphabet" do
    assert_match(/\A[#{Setup::ALPHABET}]{4}-[#{Setup::ALPHABET}]{4}-[#{Setup::ALPHABET}]{4}\z/, Setup.code)
    assert_no_match(/[01OI]/, Setup.code)
  end

  test "the code is the same on every call, so every process agrees on it" do
    assert_equal Setup.code, Setup.code
  end

  test "the code is accepted however it was typed" do
    assert Setup.correct?(Setup.code)
    assert Setup.correct?(Setup.code.downcase)
    assert Setup.correct?(Setup.code.delete("-"))
    assert Setup.correct?(" #{Setup.code.tr("-", " ")} ")
  end

  test "anything else is refused" do
    assert_not Setup.correct?(nil)
    assert_not Setup.correct?("")
    assert_not Setup.correct?("----")
    assert_not Setup.correct?("#{Setup.code}X")
    assert_not Setup.correct?(Setup.code.sub(/\A./) { |c| c == "Z" ? "Y" : "Z" })
  end

  test "the banner carries the code, and is only announced on an empty instance" do
    empty_the_instance
    assert_includes Setup.banner, Setup.code

    announced = StringIO.new
    Setup.announce(announced)
    assert_includes announced.string, Setup.code
  end

  test "nothing is announced once somebody has joined" do
    announced = StringIO.new
    Setup.announce(announced)

    assert_empty announced.string
  end

  private
    def empty_the_instance
      Member.destroy_all
    end
end
