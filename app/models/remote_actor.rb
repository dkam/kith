# An actor on another Kith or ActivityPub server. Not created in phase 1.
class RemoteActor < Actor
  validates :domain, presence: true
  validates :inbox_url, presence: true
end
