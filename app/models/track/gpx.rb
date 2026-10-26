# GPX: each <trkseg> is a segment. Waypoints and routes are not where the
# member went, so they are not read.
module Track::Gpx
  module_function

  def read(data)
    document = Track::Xml.parse(data)

    Track.new(document.xpath("//trk/trkseg").map { |segment|
      segment.xpath("trkpt").map do |point|
        Track::Point.new(
          lat: Track::Xml.number(point["lat"]),
          lon: Track::Xml.number(point["lon"]),
          ele: Track::Xml.number(point.at_xpath("ele")&.text, optional: true),
          time: Track::Xml.time(point.at_xpath("time")&.text)
        )
      end
    })
  end
end
