# frozen_string_literal: true

require_relative "test_case"

module YARV
  class PutStringTest < TestCase
    def test_execute
      assert_insns([PutString, Leave], "'foo'")
      assert_stdout("foo\n", "puts 'foo'")
    end
  end
end
