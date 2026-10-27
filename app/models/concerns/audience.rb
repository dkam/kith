# Who a thing is for. One definition of "public" in the app rather than one per
# table: a post and an entry that both say `public` must mean the same thing,
# because Visibility and leaves_the_instance? read them the same way.
#
# Integer-backed and sparse, so circles — and, for entries, `private` — fit
# between the values that exist without renumbering anything already stored.
module Audience
  extend ActiveSupport::Concern

  included do
    enum :audience, { followers: 0, public: 10 }, prefix: true, validate: true
  end
end
