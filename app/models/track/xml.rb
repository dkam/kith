# What GPX and TCX share. Parsed strictly, so a damaged file is refused
# rather than half-read, and with the network off and entities left alone.
# Errors never quote the file: what is in it is a coordinate.
module Track::Xml
  module_function

  def parse(data)
    # Strava's own exports include a TCX with whitespace before <?xml, which a
    # strict parser rejects.
    Nokogiri::XML(data.b.lstrip) { |config| config.strict.nonet }.tap(&:remove_namespaces!)
  rescue Nokogiri::XML::SyntaxError
    raise Track::Malformed, "not well-formed XML"
  end

  def number(text, optional: false)
    return nil if optional && text.blank?

    Float(text.to_s.strip, exception: false) || raise(Track::Malformed, "a position is not a number")
  end

  def time(text)
    return nil if text.blank?

    Time.iso8601(text.strip).to_r
  rescue ArgumentError
    raise Track::Malformed, "a time is not a time"
  end
end
