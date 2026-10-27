# FIT, Garmin's binary format, decoded by hand: only as much as a track
# needs, which is the position, altitude and time of each `record` message.
# Everything else is stepped over by its declared size, so messages and
# fields this knows nothing about cost nothing.
#
#   header      12 or 14 bytes: size, protocol, profile, data size (uint32 LE),
#               ".FIT", and a CRC on the 14-byte form (0 means "not computed")
#   record      a header byte, then a definition or a data message
#     normal      bit 7 = 0; bit 6 = definition; bit 5 = the definition carries
#                 developer fields; bits 0–3 = local message type
#     compressed  bit 7 = 1; bits 5–6 = local type; bits 0–4 = the low five bits
#                 of the timestamp, rolling over from the last full one
#   definition  reserved, architecture (0 little-endian, 1 big), global message
#               number, field count, then (number, size, base type) per field,
#               then, if flagged, a count and (number, size, index) per
#               developer field
#
# Record messages (global 20): 253 timestamp, uint32 s since 1989-12-31Z;
# 0/1 lat/long, sint32 semicircles; 2 altitude uint16 and 78 enhanced_altitude
# uint32, both scale 5 offset 500, enhanced winning. Reading stops at the
# header's data size; the file CRC is not checked.
class Track::Fit
  EPOCH = 631_065_600 # 1989-12-31T00:00:00Z, in Unix seconds
  RECORD = 20
  TIMESTAMP = 253

  INVALID_SINT32 = 0x7FFFFFFF
  INVALID_UINT16 = 0xFFFF
  INVALID_UINT32 = 0xFFFFFFFF

  def self.read(data) = new(data.b).read

  def initialize(data)
    @data = data
    @definitions = {}
    @last_timestamp = nil
  end

  def read
    @position, finish = header
    points = []

    while @position < finish
      byte = take(1).unpack1("C")

      if byte & 0x80 != 0
        points << compressed_record(byte)
      elsif byte & 0x40 != 0
        define(byte & 0x0F, developer: byte & 0x20 != 0)
      else
        points << message(byte & 0x0F)
      end
    end

    Track.new([ points.compact ])
  end

  private
    def header
      size = @data.getbyte(0)
      malformed("not a FIT file") unless [ 12, 14 ].include?(size) && @data.byteslice(8, 4) == ".FIT"

      finish = size + @data.byteslice(4, 4).unpack1("V")
      malformed("shorter than its header says") if finish > @data.bytesize

      [ size, finish ]
    end

    def define(local, developer:)
      _reserved, architecture = take(2).unpack("CC")
      big = architecture == 1
      global = take(2).unpack1(big ? "n" : "v")
      fields = take(1).unpack1("C").times.map { take(3).unpack("CC") }
      extra = developer ? take(1).unpack1("C").times.sum { take(3).unpack("CC").last } : 0

      @definitions[local] = { global:, big:, fields:, extra: }
    end

    def message(local)
      values = fields(local)
      timestamp = values[TIMESTAMP]
      @last_timestamp = timestamp if timestamp && timestamp != INVALID_UINT32

      point(values, timestamp) if definition(local)[:global] == RECORD
    end

    def compressed_record(byte)
      local = (byte >> 5) & 0x03
      offset = byte & 0x1F
      malformed("a compressed timestamp before any full one") unless @last_timestamp

      timestamp = (@last_timestamp & ~0x1F) + offset
      timestamp += 0x20 if offset < (@last_timestamp & 0x1F)
      @last_timestamp = timestamp

      values = fields(local)
      point(values, timestamp) if definition(local)[:global] == RECORD
    end

    # The fields a track needs, by number, read only when their size is the
    # size their type has; anything else is skipped by its declared size.
    def fields(local)
      definition = definition(local)
      big = definition[:big]

      values = definition[:fields].each_with_object({}) do |(number, size), found|
        bytes = take(size)
        case [ number, size ]
        when [ TIMESTAMP, 4 ], [ 78, 4 ] then found[number] = bytes.unpack1(big ? "N" : "V")
        when [ 0, 4 ], [ 1, 4 ] then found[number] = bytes.unpack1(big ? "l>" : "l<")
        when [ 2, 2 ] then found[number] = bytes.unpack1(big ? "n" : "v")
        end
      end
      take(definition[:extra])

      values
    end

    def point(values, timestamp)
      lat, lon = values[0], values[1]
      return if lat.nil? || lon.nil? || lat == INVALID_SINT32 || lon == INVALID_SINT32

      Track::Point.new(lat: degrees(lat), lon: degrees(lon), ele: altitude(values),
        time: (timestamp + EPOCH if timestamp && timestamp != INVALID_UINT32))
    end

    def altitude(values)
      raw = values[78] if values[78] && values[78] != INVALID_UINT32
      raw ||= values[2] if values[2] && values[2] != INVALID_UINT16

      raw / 5.0 - 500 if raw
    end

    def degrees(semicircles) = semicircles * 180.0 / 2**31

    def definition(local)
      @definitions[local] || malformed("a message with no definition")
    end

    def take(count)
      bytes = @data.byteslice(@position, count)
      malformed("ends in the middle of a message") if bytes.nil? || bytes.bytesize < count

      @position += count
      bytes
    end

    def malformed(what)
      raise Track::Malformed, what
    end
end
