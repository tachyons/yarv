# frozen_string_literal: true

module YARV
  # ### Summary
  #
  # `opt_aref` is a specialization of the `opt_send_without_block` instruction
  # that occurs when the `[]` operator is used. In CRuby, there are fast paths
  # if the receiver is an integer, array, or hash.
  #
  # ### TracePoint
  #
  # `opt_aref` can dispatch both the `c_call` and `c_return` events.
  #
  # ### Usage
  #
  # ~~~ruby
  # 7[2]
  #
  # # == disasm: #<ISeq:<compiled>@<compiled>:1 (1,0)-(1,5)> (catch: FALSE)
  # # 0000 putobject                              7                         (   1)[Li]
  # # 0002 putobject                              2
  # # 0004 opt_aref                               <calldata!mid:[], argc:1, ARGS_SIMPLE>[CcCr]
  # # 0006 leave
  # ~~~
  #
  class OptAref
    attr_reader :call_data

    def initialize(call_data)
      @call_data = call_data
    end

    def call(context)
      receiver, *arguments = context.stack.pop(call_data.argc + 1)
      result = context.call_method(call_data, receiver, arguments)

      context.stack.push(result)
    end

    def pretty_print(q)
      q.text("opt_aref <calldata!mid:[], argc:1, ARGS_SIMPLE>")
    end
  end
end
