# frozen_string_literal: true

# Require all of the files nested under the lib/yarv directory.
Dir[File.expand_path("yarv/*.rb", __dir__)].each do |filepath|
  require_relative "yarv/#{File.basename(filepath, ".rb")}"
end

# The YARV module is a Ruby runtime that evlauates YARV instructions.
module YARV
  # This is the self object at the top of the script.
  class Main
    def inspect
      "main"
    end
  end

  # This class represents information about a specific call-site in the code.
  class CallData
    attr_reader :mid, :argc

    def initialize(mid, argc)
      @mid = mid
      @argc = argc
    end
  end

  # This is the object that gets passed around all of the instructions as they
  # are being executed.
  class ExecutionContext
    # This represents an execution frame.
    class Frame
      UNDEFINED = Object.new

      attr_reader :iseq, :locals

      def initialize(iseq)
        @iseq = iseq
        @locals = Array.new(iseq.locals.length) { UNDEFINED }
      end

      # Fetches the value of a local variable from the frame. If the value has
      # not yet been initialized, it will raise an error.
      def get_local(index)
        local_index = index_for(index)
        local = locals[local_index]

        if local == UNDEFINED
          raise NameError,
                "undefined local variable or method `#{iseq.locals[local_index]}' for #{iseq.selfo}"
        end

        local
      end

      # Sets the value of the local variable on the frame.
      def set_local(index, value)
        @locals[index_for(index)] = value
      end

      private

      def index_for(index)
        (iseq.locals.length - (index - 3)) - 1
      end
    end

    # The system stack that tracks values through the execution of the program.
    attr_reader :stack

    # The global variables accessible to the program. These mirror the runtime
    # global variables if they have not been overridden.
    attr_reader :globals

    # The set of methods defined at runtime.
    attr_reader :methods

    # This is a stack of frames as they are being executed.
    attr_accessor :frames

    # The program counter used to determine which instruction to execute next.
    # This is an attr_accessor because it can be modified by instructions being
    # executed.
    attr_accessor :program_counter

    def initialize
      @stack = []
      @globals = {}
      @methods = {}
      @frames = []
      @program_counter = 0
    end

    # Calls a method on the given receiver. This is our method dispatch logic.
    # First, it looks to see if there is a method defined on the receiver's
    # class that we defined explicitly in our runtime. If there is, then it's
    # going to save the necessary information and invoke it. Otherwise, it's
    # going to call into the parent runtime and let it handle the method call.
    #
    # Note that the array of arguments coming in here is necessarily the same
    # values that align with the parameters to the method being called. They are
    # simply the popped values off the top of the stack. It is the
    # responsibility of this method to ensure that they get copied into the
    # locals table in the correct order.
    def call_method(call_data, receiver, arguments)
      if (method = methods[[receiver.class, call_data.mid]])
        # We only support a subset of the valid argument permutations. This
        # validates each kind to make sure we don't accidentally try to handle a
        # method that we currently don't support.
        case method.args
        in {}
          # No arguments, we're good
        in { lead_num: ^(arguments.length), **nil }
          # Only leading arguments and we line up with the expected number
        end

        method.eval(self) do
          # Inside this block, we have already pushed the frame. So now we need
          # to establish the correct local variables.
          arguments.each_with_index do |argument, index|
            current_frame.locals[index] = argument
          end
        end

        stack.last
      else
        receiver.send(call_data.mid, *arguments)
      end
    end

    # This returns the current execution frame.
    def current_frame
      frames.last
    end

    # This returns the instruction sequence object that is currently being
    # executed. In other words, the instruction sequence that is at the top of
    # the frame stack.
    def current_iseq
      current_frame.iseq
    end

    # Defines a method on the given object's class keyed by the given name. The
    # iseq is an instance of the InstructionSequence class.
    def define_method(object, name, iseq)
      methods[[object.class, name]] = iseq
    end

    # This executes the given instruction sequence within a new execution frame.
    def with_frame(iseq)
      current_program_counter = program_counter
      current_stack_length = stack.length

      frames.push(Frame.new(iseq))
      @program_counter = 0

      begin
        yield
      ensure
        frames.pop
        @program_counter = current_program_counter
        @stack = @stack[0..current_stack_length]
      end
    end
  end

  # This object represents a set of instructions that will be executed.
  class InstructionSequence
    attr_reader :selfo, :insns, :labels

    # This is the native instruction sequence that we are wrapping.
    attr_reader :iseq

    def initialize(selfo, iseq)
      @selfo = selfo
      @iseq = iseq

      @insns = []
      @labels = {}

      iseq.last.each do |insn|
        case insn
        in Integer | :RUBY_EVENT_LINE
          # skip for now
        in Symbol
          @labels[insn] = @insns.length
        in :branchnil, value
          @insns << BranchNil.new(value)
        in :branchunless, value
          @insns << BranchUnless.new(value)
        in [:concatarray]
          @insns << ConcatArray.new
        in :definemethod, name, iseq
          @insns << DefineMethod.new(name, InstructionSequence.new(selfo, iseq))
        in [:dup]
          @insns << Dup.new
        in :duparray, array
          @insns << DupArray.new(array)
        in :duphash, hash
          @insns << DupHash.new(hash)
        in :getconstant, name
          @insns << GetConstant.new(name)
        in :getglobal, value
          @insns << GetGlobal.new(value)
        in :getlocal_WC_0, index
          @insns << GetLocalWC0.new(index)
        in :jump, value
          @insns << Jump.new(value)
        in [:leave]
          @insns << Leave.new
        in :newarray, size
          @insns << NewArray.new(size)
        in :newhash, size
          @insns << NewHash.new(size)
        in :opt_and, { mid: :&, orig_argc: 1 }
          @insns << OptAnd.new(CallData.new(:&, 1))
        in :opt_aref, { mid: :[], orig_argc: 1 }
          @insns << OptAref.new(CallData.new(:[], 1))
        in :opt_aref_with, key, { mid: :[], orig_argc: 1 }
          @insns << OptArefWith.new(key, CallData.new(:[], 1))
        in :opt_div, { mid: :/, orig_argc: 1 }
          @insns << OptDiv.new(CallData.new(:/, 1))
        in :opt_empty_p, { mid: :empty?, orig_argc: 0 }
          @insns << OptEmptyP.new(CallData.new(:empty?, 0))
        in :opt_eq, { mid: :==, orig_argc: 1 }
          @insns << OptEq.new(CallData.new(:==, 1))
        in :opt_ge, { mid: :>=, orig_argc: 1 }
          @insns << OptGe.new(CallData.new(:>=, 1))
        in :opt_gt, { mid: :>, orig_argc: 1 }
          @insns << OptGt.new(CallData.new(:>, 1))
        in :opt_le, { mid: :<=, orig_argc: 1 }
          @insns << OptLe.new(CallData.new(:<=, 1))
        in :opt_lt, { mid: :<, orig_argc: 1 }
          @insns << OptLt.new(CallData.new(:<, 1))
        in :opt_nil_p, { mid: :nil?, orig_argc: 0 }
          @insns << OptNilP.new(CallData.new(:nil?, 0))
        in :opt_getinlinecache, label, cache
          @insns << OptGetInlineCache.new(label, cache)
        in :opt_length, { mid: :length, orig_argc: 0 }
          @insns << OptLength.new(CallData.new(:length, 0))
        in :opt_minus, { mid: :-, orig_argc: 1 }
          @insns << OptMinus.new(CallData.new(:-, 1))
        in :opt_mod, { mid: :%, orig_argc: 1 }
          @insns << OptMod.new(CallData.new(:%, 1))
        in :opt_not, { mid: :!, orig_argc: 0 }
          @insns << OptNot.new(CallData.new(:!, 0))
        in :opt_or, { mid: :|, orig_argc: 1 }
          @insns << OptOr.new(CallData.new(:|, 1))
        in :opt_plus, { mid: :+, orig_argc: 1 }
          @insns << OptPlus.new(CallData.new(:+, 1))
        in :opt_send_without_block, { mid:, orig_argc: }
          @insns << OptSendWithoutBlock.new(CallData.new(mid, orig_argc))
        in :opt_setinlinecache, cache
          @insns << OptSetInlineCache.new(cache)
        in :opt_str_freeze, value, { mid: :freeze, orig_argc: 0 }
          @insns << OptStrFreeze.new(value)
        in :opt_str_uminus, value, { mid: :-@, orig_argc: 0 }
          @insns << OptStrUMinus.new(value, CallData.new(:-@, 0))
        in :opt_succ, { mid: :succ, orig_argc: 0 }
          @insns << OptSucc.new(CallData.new(:succ, 0))
        in [:pop]
          @insns << Pop.new
        in [:putnil]
          @insns << PutNil.new
        in :putobject, object
          @insns << PutObject.new(object)
        in [:putobject_INT2FIX_0_]
          @insns << PutObjectInt2Fix0.new
        in [:putobject_INT2FIX_1_]
          @insns << PutObjectInt2Fix1.new
        in [:putself]
          @insns << PutSelf.new(selfo)
        in :putstring, string
          @insns << PutString.new(string)
        in :setglobal, name
          @insns << SetGlobal.new(name)
        in :setlocal_WC_0, index
          @insns << SetLocalWC0.new(index)
        in [:swap]
          @insns << Swap.new
        end
      end
    end

    # These are the names of the locals in the instruction sequence.
    def locals
      iseq[10]
    end

    # This is the information about the arguments that should be passed into
    # this instruction sequence.
    def args
      iseq[11]
    end

    # Pushes a new frame onto the stack, executes the instructions contained
    # within this instruction sequence, then pops the frame off the stack.
    def eval(context = ExecutionContext.new)
      context.with_frame(self) do
        yield if block_given?

        loop do
          insn = insns[context.program_counter]
          context.program_counter += 1

          insn.call(context)
          break if insn in Leave
        end
      end
    end
  end

  # This is the main entry into the project. It accepts a Ruby string that
  # represents source code. You can optionally also pass all of the same
  # arguments as you would to RubyVM::InstructionSequence.compile.
  #
  # It compiles the source into an InstructionSequence object. You can then
  # execute it
  def self.compile(
    source,
    file = "<compiled>",
    path = "<compiled>",
    lineno = 1,
    **options
  )
    iseq =
      RubyVM::InstructionSequence.compile(
        source,
        file,
        path,
        lineno,
        **default_compile_options.merge!(options)
      )

    InstructionSequence.new(Main.new, iseq.to_a)
  end

  def self.default_compile_options
    {
      inline_const_cache: true,
      peephole_optimization: true,
      specialized_instruction: true,
      tailcall_optimization: false,
      trace_instruction: false
    }
  end
end
