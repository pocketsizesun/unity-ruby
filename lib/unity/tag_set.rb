# frozen_string_literal: true

module Unity
  class TagSet < Hash
    def []=(key, value)
      return if value.nil?

      super(key.to_s, value.to_s)
    end

    def to_sha256_binary
      sha256.digest
    end

    def to_sha256
      sha256.hexdigest
    end

    private

    def sha256
      sha = Digest::SHA256.new
      sort.each do |item|
        sha << item[0]
        sha << item[1]
      end
      sha
    end
  end
end
