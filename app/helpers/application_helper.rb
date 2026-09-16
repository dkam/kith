module ApplicationHelper
  # A revision is a full 40-character sha in a container and a short one in
  # development, and neither is worth reading in full inside a sentence. Twelve
  # characters is enough to name a commit; the whole thing stays on hover.
  # Anything that isn't a sha — "unknown" — is passed through untouched.
  def short_revision(revision)
    revision.to_s.match?(/\A[0-9a-f]{13,40}\z/i) ? revision[0, 12] : revision
  end
end
