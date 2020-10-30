# frozen_string_literal: true

require 'socket'

module Unity
  class CommonLogger < ::Logger
    def initialize(app_name, logdev = STDOUT, shift_age = 1, shift_size = 52_428_800)
      super(logdev, shift_age, shift_size)

      @hostname = Socket.gethostname
      @app_name = app_name.to_s
      self.formatter = proc do |severity, date, progname, msg|
        date = date.iso8601 if date.is_a?(Time)
        data = {
          '_date' => date,
          '_severity' => severity,
          '_source' => @app_name,
          '_host' => @hostname
        }
        if msg.is_a?(Hash)
          data = data.merge(msg)
        else
          data['message'] = msg
        end
        data.to_json + "\n"
      end
    end
  end
end
