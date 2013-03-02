module Respec
  VERSION = [0, 5, 0]

  class << VERSION
    include Comparable

    def to_s
      join('.')
    end
  end
end
