# frozen_string_literal: true

module YARV
  # ### Summary
  #
  # `putobject_INT2FIX_1_` pushes 1 on the stack.
  # It is a specialized instruction resulting from the operand
  # unification optimization. It is the equivalent to `putobject 1`.
  #
  # ### TracePoint
  #
  # `putobject` can dispatch the line event.
  #
  # ### Usage
  #
  # ~~~ruby
  # 1
  #
  # # == disasm: #<ISeq:<compiled>@<compiled>:1 (1,0)-(1,1)> (catch: FALSE)
  # # 0000 putobject_INT2FIX_1_                                             (   1)[Li]
  # # 0001 leave
  # ~~~
  #
  class PutObjectInt2Fix1
    def call(context)
      context.stack.push(1)
    end

    def pretty_print(q)
      q.text("putobject_INT2FIX_1_")
    end
  end
end
