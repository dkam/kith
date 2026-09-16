# A draft is a post with no publication time. There is no status column beside
# it on purpose: one fact cannot disagree with itself, and it leaves the seam
# for scheduling — no date, a future date, a past date — without building it.
class LetAPostBeADraft < ActiveRecord::Migration[8.1]
  def change
    change_column_null :posts, :published_at, true
  end
end
