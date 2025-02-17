# frozen_string_literal: true

require_relative "./test_case"

module YARV
  class OptOrTest < TestCase
    def test_execute
      assert_insns([PutObject, PutObject, OptOr, Leave], "2 | 3")
      assert_stdout("3\n", "p 2 | 3")
    end
  end
end
