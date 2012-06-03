module SlangerHelperMethods
  class HaveAttributes
    attr_reader :messages, :attributes
    def initialize attributes
      @attributes = attributes
    end

    CHECKS = %w(first_event last_event last_data )

    def matches?(messages)
      @messages = messages
      @failures = []

      check_connection_established if attributes[:connection_established]
      check_id_present             if attributes[:id_present]

      CHECKS.each { |a| attributes[a.to_sym] ?  check(a) : true }

      @failures.empty?
    end

    def check message
      send(message) == attributes[message.to_sym] or @failures << message
    end

    def failure_message
      @failures.map {|f| "expected #{f}: to equal #{attributes[f]} but got #{send(f)}"}.join "\n"
    end

    private

    def check_connection_established
      if first_event != 'pusher:connection_established'
        @failures << :connection_established
      end
    end

    def check_id_present
      if messages.first['data']['socket_id'] == nil
        @failures << :id_present
      end
    end

    def first_event
      messages.first['event']
    end

    def last_event
      messages.last['event']
    end

    def last_data
      messages.last['data']
    end

    def count
      messages.length
    end
  end

  def have_attributes attributes
    HaveAttributes.new attributes
  end
end
