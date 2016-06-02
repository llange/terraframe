require 'minitest/autorun'
require 'minitest/pride'

require 'terraframe'

class TerraframeTestObject < Minitest::Test

  class NullLoger < Logger
    def initialize(*args)
    end

    def add(*args, &block)
    end
  end

end

