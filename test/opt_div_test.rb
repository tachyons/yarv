# frozen_string_literal: true

require_relative "test_case"

module YARV
  class OptDivTest < TestCase
    def test_execute
      assert_insns([PutObject, PutObject, OptDiv, Leave], "2 / 3")
      assert_stdout("0\n", "p 2 / 3")
    end
  end
end
