# TCX: Garmin's training format. Laps follow one another without a gap, so
# the whole activity is one segment; a trackpoint with no <Position> (an
# indoor ride, a GPS dropout) is skipped.
module Track::Tcx
  module_function

  def read(data)
    document = Track::Xml.parse(data)

    points = document.xpath("//Trackpoint").filter_map do |point|
      position = point.at_xpath("Position") or next

      Track::Point.new(
        lat: Track::Xml.number(position.at_xpath("LatitudeDegrees")&.text),
        lon: Track::Xml.number(position.at_xpath("LongitudeDegrees")&.text),
        ele: Track::Xml.number(point.at_xpath("AltitudeMeters")&.text, optional: true),
        time: Track::Xml.time(point.at_xpath("Time")&.text)
      )
    end

    Track.new([ points ])
  end
end
