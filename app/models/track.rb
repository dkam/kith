# A GPS track: a list of segments, each a list of points. A value object, and
# deliberately ignorant of where it came from — the Strava importer reads one
# out of a file, the phone API will read one out of an upload, and both store
# the same GeoJSON. Nothing in here may know about Strava, or about members.
#
# A track is a list of segments rather than one line because a trim makes a
# gap: dropping the points around a house and joining the line across would
# draw a straight line through it. So distance and climb are summed within a
# segment and never across one.
#
# Positions are rounded to 6 decimal places (about 0.1 m) the moment they are
# read, so the points a trim tests are exactly the points that get stored.
# Rounding afterwards could nudge a point that had just cleared a circle back
# inside it.
class Track
  # `time` is seconds, absolute when a track has just been read from a file and
  # relative to its segment once it has been trimmed or read back from storage.
  Point = Data.define(:lon, :lat, :ele, :time)

  class Malformed < StandardError; end

  # Slower than this between two points is standing still, or GPS drift.
  MOVING_SPEED = 0.5 # m/s
  # A rise is counted once it is this far above the last low, so that altitude
  # jitter on the flat adds up to nothing.
  CLIMB_HYSTERESIS = 3.0 # m

  attr_reader :segments

  def self.from_geojson(json)
    GeoJson.read(json)
  end

  # Elevation and times are all or nothing: if any point lacks one, every point
  # loses it, so a stored track never has a position with elevation beside one
  # without.
  def initialize(segments)
    segments = segments.map(&:to_a).reject(&:empty?)
    points = segments.flatten
    elevated = points.all?(&:ele)
    timed = points.all?(&:time)

    @segments = segments.map { |segment|
      segment.map { |point|
        Point.new(lon: point.lon.to_f.round(6), lat: point.lat.to_f.round(6),
          ele: (point.ele.to_f.round(1) if elevated), time: (point.time if timed))
      }.freeze
    }.freeze
  end

  def empty? = segments.empty?
  def points = segments.flatten

  def elevation? = !empty? && !points.first.ele.nil?
  def timed? = !empty? && !points.first.time.nil?

  def ==(other) = other.is_a?(Track) && segments == other.segments

  def distance_m
    segments.sum { |segment| pairs(segment).sum { |a, b| metres(a, b) } }.round(1)
  end

  def moving_time_s
    return unless timed?

    segments.sum { |segment|
      pairs(segment).sum { |a, b|
        interval = b.time - a.time
        interval.positive? && metres(a, b) / interval >= MOVING_SPEED ? interval : 0
      }
    }.round
  end

  def elevation_gain_m
    return unless elevation?

    segments.sum { |segment| climb(segment.map(&:ele)) }.round(1)
  end

  def to_geojson
    GeoJson.write(self)
  end

  private
    def pairs(segment) = segment.each_cons(2)

    def metres(a, b) = Geo.distance_m(a.lat, a.lon, b.lat, b.lon)

    # Hysteresis: nothing counts until the track is CLIMB_HYSTERESIS above its
    # lowest point so far; from then on every new high counts, until it drops
    # that far below the high and starts looking for a new low.
    def climb(elevations)
      gain = 0.0
      low = elevations.first
      high = nil

      elevations.each do |ele|
        if high.nil?
          if ele < low
            low = ele
          elsif ele >= low + CLIMB_HYSTERESIS
            gain += ele - low
            high = ele
          end
        elsif ele > high
          gain += ele - high
          high = ele
        elsif ele <= high - CLIMB_HYSTERESIS
          low = ele
          high = nil
        end
      end

      gain
    end
end
