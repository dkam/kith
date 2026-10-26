# The two formulas a trim is made of. They are pinned, not merely chosen:
# Swift and Kotlin implement the same trim on the member's phones, and the
# shared fixtures in test/fixtures/files/trim/ hold all three to the same
# answers. Change one here and it is a new trim version, not a fix.
#
#   mean Earth radius  R = 6 371 008.8 m
#
#   distance, by haversine:
#     a = sin²(Δφ/2) + cos φ₁ cos φ₂ sin²(Δλ/2)
#     d = 2 R asin(√a)
#
#   the point d metres from (φ₁, λ₁) on bearing θ, with δ = d / R:
#     φ₂ = asin(sin φ₁ cos δ + cos φ₁ sin δ cos θ)
#     λ₂ = λ₁ + atan2(sin θ sin δ cos φ₁, cos δ − sin φ₁ sin φ₂)
#
# λ₂ is not wrapped into [-180, 180]: haversine only ever sees it through
# sin²(Δλ/2), which does not care.
module Track::Geo
  EARTH_RADIUS_M = 6_371_008.8

  module_function

  def distance_m(lat1, lon1, lat2, lon2)
    φ1 = radians(lat1)
    φ2 = radians(lat2)
    a = Math.sin((φ2 - φ1) / 2)**2 + Math.cos(φ1) * Math.cos(φ2) * Math.sin(radians(lon2 - lon1) / 2)**2

    2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a.clamp(0.0, 1.0)))
  end

  # [lat, lon] of the point `distance_m` from (lat, lon) on `bearing_deg`.
  def destination(lat, lon, bearing_deg, distance_m)
    φ1 = radians(lat)
    θ = radians(bearing_deg)
    δ = distance_m / EARTH_RADIUS_M

    φ2 = Math.asin(Math.sin(φ1) * Math.cos(δ) + Math.cos(φ1) * Math.sin(δ) * Math.cos(θ))
    λ2 = radians(lon) + Math.atan2(Math.sin(θ) * Math.sin(δ) * Math.cos(φ1), Math.cos(δ) - Math.sin(φ1) * Math.sin(φ2))

    [ degrees(φ2), degrees(λ2) ]
  end

  def radians(degrees) = degrees * Math::PI / 180
  def degrees(radians) = radians * 180 / Math::PI
end
