# frozen_string_literal: true

module Unity
  class TagSet < Hash
    def []=(key, value)
      return if value.nil?

      super(key.to_s, value.to_s)
    end

    def to_sha256(hex: false)
      hex == true ? sha2.hexdigest : sha2.digest
    end

    def to_sha1(hex: false)
      hex == true ? sha1.hexdigest : sha1.digest
    end

    private

    def sha1
      sha = Digest::SHA1.new
      sort.each do |item|
        sha << item[0]
        sha << item[1]
      end
      sha
    end

    def sha2
      sha = Digest::SHA256.new
      sort.each do |item|
        sha << item[0]
        sha << item[1]
      end
      sha
    end
  end
end
