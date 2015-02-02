module Respec
  VERSION = [0, 8, 0]

  class << VERSION
    include Comparable

    def to_s
      join('.')
    end
  end
end
