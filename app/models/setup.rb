# The first member cannot be invited: there is nobody here to invite them. So
# while the instance has no members at all, Kith prints a setup code to the
# server's console, and /setup accepts it. Being able to read that console is
# the only credential that exists before anybody has joined.
#
# The code is derived from secret_key_base rather than stored, so every process
# agrees on it without a shared table, file or cache, and it is never written
# down anywhere. The moment one member exists, setup closes: the code stops
# being printed, /setup returns 404, and the only way in is an invite.
class Setup
  # No 0/O/1/I: this gets read off a terminal and typed into a phone. 32
  # divides 256 evenly, so folding a random byte into it stays uniform.
  ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ".freeze
  LENGTH = 12
  GROUP = 4

  class << self
    def open?
      !Member.exists?
    end

    def code
      @code ||= Rails.application.key_generator.generate_key("kith/setup code", LENGTH)
        .each_byte.map { |byte| ALPHABET[byte % ALPHABET.size] }.join
        .scan(/.{#{GROUP}}/).join("-")
    end

    # Generous about how it was typed — case, spaces, the dashes we printed —
    # and constant-time about whether it was right.
    def correct?(given)
      ActiveSupport::SecurityUtils.secure_compare(normalise(given), normalise(code))
    end

    # Printed at boot while the instance is empty. Nothing to say once someone
    # has joined.
    def announce(io = $stdout)
      io.puts banner if open?
    rescue ActiveRecord::ActiveRecordError
      # No database yet — bin/setup is still running, and it will boot again.
    end

    def banner
      rule = "─" * 52

      <<~BANNER

        #{rule}
          Kith has no members yet.

          Open /setup and enter this code:

              #{code}

          It is printed only while nobody has joined.
        #{rule}

      BANNER
    end


    private
      def normalise(given)
        given.to_s.upcase.gsub(/[^A-Z0-9]/, "")
      end
  end
end
