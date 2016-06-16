require "mini_racer/version"
require "mini_racer_extension"
require "thread"

module MiniRacer

  class EvalError < StandardError; end
  class ScriptTerminatedError < EvalError; end
  class ParseError < EvalError; end

  class RuntimeError < EvalError
    def initialize(message)
      message, js_backtrace = message.split("\n", 2)
      if js_backtrace && !js_backtrace.empty?
        @js_backtrace = js_backtrace.split("\n")
        @js_backtrace.map!{|f| "JavaScript #{f.strip}"}
      else
        @js_backtrace = nil
      end
      super(message)
    end

    def backtrace
      val = super
      return unless val
      if @js_backtrace
        @js_backtrace + val
      else
        val
      end
    end
  end

  # helper class returned when we have a JavaScript function
  class JavaScriptFunction
    def to_s
      "JavaScript Function"
    end
  end

  # eval is defined in the C class
  class Context

    class ExternalFunction
      def initialize(name, callback, parent)
        unless String === name
          raise ArgumentError, "parent_object must be a String"
        end
        parent_object, _ , @name = name.rpartition(".")
        @callback = callback
        @parent = parent
        @parent_object_eval = nil
        @parent_object = nil

        unless parent_object.empty?
          @parent_object = parent_object

          @parent_object_eval = ""
          prev = ""
          first = true
          parent_object.split(".").each do |obj|
            prev << obj
            if first
              @parent_object_eval << "if (typeof #{prev} === 'undefined') { #{prev} = {} };\n"
            else
              @parent_object_eval << "#{prev} = #{prev} || {};\n"
            end
            prev << "."
            first = false
          end
          @parent_object_eval << "#{parent_object};"
        end
        notify_v8
      end
    end

    def initialize(options = nil)
      @functions = {}
      @lock = Mutex.new
      @timeout = nil
      @current_exception = nil

      snapshot = nil
      if options
        @timeout = options[:timeout]
        snapshot = options[:snapshot]
      end

      unless snapshot.nil? || snapshot.is_a?(Snapshot)
        raise ArgumentError, "snapshot must be a MiniRacer::Snapshot object, passed a #{snapshot.inspect}"
      end

      # defined in the C class
      init_with_snapshot(snapshot)
    end

    def load(filename)
      # TODO do this native cause no need to allocate VALUE here
      eval(File.read(filename))
    end

    def eval(str)
      @lock.synchronize do
        @current_exception = nil
        eval_unsafe(str)
      end
    end

    def attach(name, callback)
      @lock.synchronize do
        external = ExternalFunction.new(name, callback, self)
        @functions["#{name}"] = external
      end
    end

  end

  class Snapshot
    def initialize(str)
      # defined in the C class
      load(str)
    end

    # TODO wkpo size helper
  end
end
