# How a member's rides are trimmed: the radius around each end, and the offset
# that moves every trim circle off the point it protects. Built by
# `member.trim`; a value here so that Track never has to know whose ride it is,
# and so tests can pass any offset they like.
#
# The offset is the answer to Hassan, Hussain and Bates (USENIX Security 2018).
# A circle centred on home leaves cut points that all sit on that circle, and
# fitting a circle to a handful of rides finds the front door. So the circle
# protecting a point p is centred at c, `offset_m` metres from p on
# `bearing_deg`, with radius ρ = R + offset_m. Everything within R of p is
# still inside it — the triangle inequality — but the centre a fit finds is c,
# not p.
#
# The offset is a distance, not a fraction of the radius, so circles of every
# radius around one point share a centre. Were it a fraction, changing the
# radius would slide the centre along the line from home, and two sets of cut
# points would then point straight at it. For the same reason it is fixed per
# member and never re-drawn.
#
# VERSION names the formulas in Track::Geo and the steps in Track#trim. Swift
# and Kotlin implement the same version from test/fixtures/files/trim/, and
# every workout records the version that cut it, so a version found to be
# wrong can be retired and its tracks found.
class Track::Trim < Data.define(:radius_m, :bearing_deg, :offset_m)
  VERSION = 1

  Circle = Data.define(:lat, :lon, :radius_m) do
    # Strictly inside: a point exactly on the boundary survives, in every
    # implementation.
    def cover?(point) = Track::Geo.distance_m(lat, lon, point.lat, point.lon) < radius_m
  end

  # The circle protecting (lat, lon) to `radius`, which is the trim's own radius
  # for the two ends of a ride and a zone's radius for a zone.
  def circle_around(lat, lon, radius = radius_m)
    centre_lat, centre_lon = Track::Geo.destination(lat, lon, bearing_deg, offset_m)

    Circle.new(lat: centre_lat, lon: centre_lon, radius_m: radius + offset_m)
  end
end
