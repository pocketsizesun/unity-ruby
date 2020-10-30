module Unity
  class Logger < ::Logger
    def initialize(*args)
      super
      self.formatter = proc do |severity, datetime, progname, msg|
        row = {
          '_severity' => severity,
          '_date' => datetime.iso8601,
          '_source' => Unity.application.name
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
