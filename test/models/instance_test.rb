require "test_helper"

class InstanceTest < ActiveSupport::TestCase
  test "there is one instance and current finds it" do
    assert_equal instances(:kith), Instance.current
  end

  test "current creates the row if somehow there is none" do
    Instance.delete_all

    assert Instance.current.persisted?
    assert Instance.current.invites_open?
  end

  test "an open instance with no cap accepts members" do
    assert Instance.current.accepting_members?
    assert_nil Instance.current.closed_because
  end

  test "closing the door closes it" do
    Instance.current.update!(invites_open: false)

    refute Instance.current.accepting_members?
    assert_equal "Invites are closed.", Instance.current.closed_because
  end

  test "a cap closes the door once Kith is full" do
    Instance.current.update!(member_cap: Member.count)

    refute Instance.current.accepting_members?
    assert_equal "Kith is full — #{Member.count} members.", Instance.current.closed_because
  end

  test "a cap of one is one member, not one members" do
    Member.where.not(id: Member.first).destroy_all
    Instance.current.update!(member_cap: 1)

    assert_equal "Kith is full — 1 member.", Instance.current.closed_because
  end

  test "a cap above the member count leaves the door open" do
    Instance.current.update!(member_cap: Member.count + 1)

    assert Instance.current.accepting_members?
  end

  test "no cap means no cap" do
    Instance.current.update!(member_cap: nil)

    assert Instance.current.accepting_members?
  end

  test "a cap of zero or less is refused as a typo" do
    refute Instance.current.update(member_cap: 0)
    refute Instance.current.update(member_cap: -1)
  end
end
