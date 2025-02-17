# frozen_string_literal: true

module YARV
  # ### Summary
  #
  # `setglobal` sets the value of a global variable.
  #
  # ### TracePoint
  #
  # `setglobal` does not dispatch any events.
  #
  # ### Usage
  #
  # ~~~ruby
  # $global = 5
  #
  # # == disasm: #<ISeq:<main>@-e:1 (1,0)-(1,11)> (catch: FALSE)
  # # 0000 putobject                              5                         (   1)[Li]
  # # 0002 dup
  # # 0003 setglobal                              :$global
  # # 0005 leave
  # ~~~
  #
  class SetGlobal
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def call(context)
      # If we're not currently tracking the global variable, then we're going to
      # steal the definition of it from the parent process by eval-ing it.
      if !context.globals.key?(name) && global_variables.include?(name)
        context.globals[name] = eval(name.to_s)
      end

      context.globals[name] = context.stack.pop
    end

    def pretty_print(q)
      q.text("setglobal #{name.inspect}")
    end
  end
end
