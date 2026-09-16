# An actor that lives on this instance and is backed by a Member.
class LocalActor < Actor
  encrypts :private_key

  validates :domain, absence: true
end
