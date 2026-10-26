# Writes just enough of the FIT format to build the test fixtures for
# Track::Fit, so the bytes a test feeds the decoder can be read here rather
# than in a hex dump. Only what the decoder must cope with: definitions in
# either byte order, developer fields, compressed-timestamp headers.
#
#   FitWriter.build do |fit|
#     fit.define(local: 0, global: 20, fields: [ [ 253, 4 ], [ 0, 4 ], [ 1, 4 ] ])
#     fit.record(local: 0, values: [ timestamp, lat, lon ])
#   end
#
# Values are integers, packed to each field's declared size; a negative value
# goes in as its two's complement. Nothing checks the CRCs, so they are zero.
class FitWriter
  EPOCH = 631_065_600 # 1989-12-31T00:00:00Z

  def self.build(header_size: 14, &block)
    new.tap(&block).to_s(header_size:)
  end

  # Seconds since the FIT epoch, from a Time.
  def self.timestamp(time) = time.to_i - EPOCH

  # Degrees to semicircles.
  def self.semicircles(degrees) = (degrees * 2**31 / 180.0).round

  def initialize
    @records = "".b
    @definitions = {}
  end

  def define(local:, global:, fields:, big_endian: false, developer_fields: [])
    @definitions[local] = { fields:, big_endian:, developer_fields: }

    header = 0x40 | local
    header |= 0x20 if developer_fields.any?
    bytes = [ header, 0, big_endian ? 1 : 0 ].pack("CCC")
    bytes << [ global ].pack(big_endian ? "n" : "v")
    bytes << [ fields.size ].pack("C")
    fields.each { |number, size, base_type = 0| bytes << [ number, size, base_type ].pack("CCC") }
    if developer_fields.any?
      bytes << [ developer_fields.size ].pack("C")
      developer_fields.each { |number, size, index = 0| bytes << [ number, size, index ].pack("CCC") }
    end

    @records << bytes
  end

  def record(local:, values:, developer_bytes: [])
    @records << [ local ].pack("C") << pack(local, values, developer_bytes)
  end

  # A compressed-timestamp header: the time is the last full timestamp with
  # its low five bits replaced by `offset`, rolling over if they go backwards.
  def compressed(local:, offset:, values:, developer_bytes: [])
    @records << [ 0x80 | (local << 5) | (offset & 0x1F) ].pack("C") << pack(local, values, developer_bytes)
  end

  def to_s(header_size: 14)
    header = [ header_size, 0x20, 2132, @records.bytesize ].pack("CCvV") << ".FIT"
    header << [ 0 ].pack("v") if header_size == 14

    header << @records << [ 0 ].pack("v") # the file CRC, unchecked
  end

  private
    def pack(local, values, developer_bytes)
      definition = @definitions.fetch(local)
      big = definition[:big_endian]

      bytes = definition[:fields].zip(values).map { |(_, size), value|
        unsigned = value & ((1 << (size * 8)) - 1)
        case size
        when 1 then [ unsigned ].pack("C")
        when 2 then [ unsigned ].pack(big ? "n" : "v")
        when 4 then [ unsigned ].pack(big ? "N" : "V")
        else [ unsigned ].pack("C") * size
        end
      }.join.b

      bytes << developer_bytes.pack("C*")
    end
end
