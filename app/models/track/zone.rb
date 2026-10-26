# A place a member has said a ride must not show: a centre and a radius in
# metres. Held in memory for one trim and never stored — Kith does not keep a
# list of where its members live.
Track::Zone = Data.define(:lat, :lon, :radius_m)
