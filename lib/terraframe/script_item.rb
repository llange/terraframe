require 'json'
require 'hashie/mash'

# require 'terraframe/module'

module Terraframe
  class ScriptItem
    attr_reader :fields
    # attr_reader :vars
    # attr_reader :context

    # def initialize(vars, context, &block)
    def initialize(state, &block)
      if nil == state
          raise "Passed nil to initialize. Generally disallowed."
      end
      @state = state
      @fields = {}
      # @context = context
      # @vars = Hashie::Mash.new(vars)

      instance_eval &block
    end

    # def to_json(*a)
    #   sanitized = @fields
    #   sanitized.delete("\#")

    #   sanitized.to_json(*a)
    # end

    ## DSL FUNCTIONS BELOW
    def method_missing(method_name, *args, &block)
      symbol = method_name.to_sym
      if args.length == 1
        if args[0] == nil
          raise "Passed nil to '#{method_name}'. Generally disallowed, subclass ScriptItem if you need this."
        end
        add_field(symbol, args[0])
        # @fields[method_name.to_sym] = args[0]
      else
        add_field(symbol, Terraframe::ScriptItem.new(@state, &block).fields)
        # raise "Multiple fields passed to a scalar auto-argument '#{method_name}'."
      end
    end

    # Get the runtime value of a variable
    def get(variable_name)
      @state.get(variable_name)
    end

    # Reference a variable
    def var(variable_name)
      "${var.#{variable_name}}"
    end

    # Reference a list variable
    def var_list(variable_name)
      ["${split(\",\",var.#{variable_name})}"]
    end

    # Syntax to handle interpolation of resource variables
    def output_of(resource_type, resource_name, output_type)
      "${#{resource_type}.#{resource_name}.#{output_type}}"
    end

    # Shorthand to interpolate the ID of another resource
    def id_of(resource_type, resource_name)
      output_of(resource_type, resource_name, :id)
    end

    def add_field(symbol, value)
      existing = @fields[symbol]
      if existing
        # If it's already an array, just push to it
        @fields[symbol] = [existing] unless existing.is_a?(Array)
        @fields[symbol] << value
      else
        @fields[symbol] = value
      end
    end

    alias_method :value_of,  :output_of

  end
end