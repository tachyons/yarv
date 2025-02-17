# frozen_string_literal: true

require_relative "test_case"

module YARV
  class OptStrUMinusTest < TestCase
    def test_execute
      assert_insns([OptStrUMinus, Leave], "-\"string\"")
      assert_stdout("\"string\"\n", "p(-'string')")
    end
  end
end
