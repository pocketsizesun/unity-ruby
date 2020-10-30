# frozen_string_literal: true

module Unity
  class URN
    ParseError = Class.new(StandardError)
    Resource = Struct.new(:type, :id)

    PATTERN = %{(?i:urn:(?!urn:)[a-z0-9][\x00-\x7F]{1,31}:} +
              %{(?:[a-z0-9()+,-.:=@;$_!*'/]|%(?:2[1-9a-f]|[3-6][0-9a-f]|7[0-9a-e]))+)}.freeze
    REGEX = /\A#{PATTERN}\z/.freeze

    attr_reader :urn, :nid, :nss
    private :urn

    def self.extract(str, &blk)
      str.scan(/\b#{PATTERN}/, &blk)
    end

    def self.parse(arg)
      new(arg.to_s)
    end

    def self.legal?(urn)
      urn.match?(REGEX)
    end

    def initialize(urn)
      unless self.class.legal?(urn)
        raise ParseError, "bad URN(is not URN?): #{urn}"
      end

      @urn = urn
      _scheme, @nid, @nss = urn.split(':', 3)
    end

    def normalize
      normalized_nid = nid.downcase
      normalized_nss = nss.gsub(/%([0-9a-f]{2})/i) { |hex| hex.downcase }

      self.class.new("urn:#{normalized_nid}:#{normalized_nss}")
    end

    def to_s
      urn
    end

    def match?(other)
      other = self.class.parse(other) unless other.is_a?(self.class)
      service == other.service && File.fnmatch(other.nss, nss)
    end

    def ===(other)
      if other.respond_to?(:normalize)
        urn_string = other.normalize.to_s
      else
        begin
          urn_string = self.class.new(other).normalize.to_s
        rescue ParseError
          return false
        end
      end

      normalize.to_s == urn_string
    end

    def ==(other)
      return false unless other.is_a?(self.class)

      normalize.to_s == other.normalize.to_s
    end

    def eql?(other)
      return false unless other.is_a?(self.class)

      to_s == other.to_s
    end

    def service
      nid
    end

    def resource
      @resource ||= Resource.new(*nss.split(/[\:\/]/, 2))
    end

    def resource_type
      resource.type
    end

    def resource_id
      resource.id
    end

    def as_json(*a)
      to_s
    end

    def to_json(*a)
      to_s.to_json(*a)
    end
  end
end
