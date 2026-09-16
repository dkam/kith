module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_member

    def connect
      set_current_member || reject_unauthorized_connection
    end

    private
      def set_current_member
        if session = Session.find_by(id: cookies.signed[:session_id])
          self.current_member = session.member
        end
      end
  end
end
