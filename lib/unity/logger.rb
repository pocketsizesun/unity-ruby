module Unity
  class Logger < ::Logger
    def initialize(*args)
      super

      @local_hostname = Socket.gethostname
      self.formatter = proc do |severity, datetime, progname, msg|
        row = {
          '@severity' => severity,
          '@date' => datetime.utc.iso8601,
          '@hostname' => @local_hostname,
          '@source' => Unity.application&.name
        }
        if msg.is_a?(Hash)
          row.merge!(msg)
        else
          row['message'] = msg.to_s
        end
        JSON.dump(row) + "\n"
      end
    end
  end
end
