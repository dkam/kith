# A ride, a run, a walk: what happened, Strava's own figures for it, and the
# whole GPS track.
#
# The track is a GPS trace of its owner's house, so it is kept for its owner
# alone, as `full_track`: every recorded point, rounded to six places, untrimmed
# (dkam, 2026-10-26: "the only time to strip location is when sharing"). The
# name is there so that no view reaches for `workout.track` and renders the
# owner's copy to a reader. Sharing will cut a trimmed copy once and attach it
# beside this one; nothing else may ever hand `full_track` to anybody else, and
# nothing serves it yet.
#
# There is never a link out (`uri` is NULL): the Strava activity page shows the
# whole track to whoever Strava lets see it.
class Workout < Entry
  # Kith's own vocabulary, shared with the phone API. Each source maps its own
  # names onto these, and anything unknown is `other`.
  ACTIVITY_TYPES = %w[ run ride walk hike swim ski snowboard other ].freeze

  # Exactly these, and nothing else from wherever the workout came from: not
  # heart rate, weight, calories, notes, gear or weather. The figures are the
  # source's, and are the owner's to see.
  DATA_KEYS = %w[ name activity_type source_activity_type distance_m moving_time_s elevation_gain_m ].freeze

  TRACK_FILENAME = "track.geojson"
  TRACK_CONTENT_TYPE = "application/geo+json"

  has_one_attached :full_track

  validates :uri, absence: true
  validates :activity_type, inclusion: { in: ACTIVITY_TYPES }
  validate :data_holds_only_its_keys

  def activity_type = data["activity_type"]

  # The whole ride as a Track, or an empty one when there is none (indoors).
  def read_full_track
    full_track.attached? ? Track.from_geojson(full_track.download) : Track.new([])
  end

  # Attaches `track` as the full track, or detaches it if the track is empty.
  # Returns whether anything changed: the same points are the same bytes, and
  # the same bytes are not uploaded twice.
  def full_track_from(track)
    if track.empty?
      return false unless full_track.attached?

      full_track.purge
      return true
    end

    geojson = track.to_geojson
    return false if full_track.attached? && full_track.blob.checksum == OpenSSL::Digest::MD5.base64digest(geojson)

    full_track.attach(io: StringIO.new(geojson), filename: TRACK_FILENAME, content_type: TRACK_CONTENT_TYPE,
      identify: false)
    true
  end

  private
    def data_holds_only_its_keys
      extra = data.keys - DATA_KEYS
      errors.add(:data, "holds keys a workout does not keep: #{extra.join(", ")}") if extra.any?
    end
end
