require 'json'
require 'hashie/mash'

require 'terraframe/variable'
require 'terraframe/module'

module Terraframe
  class NullLoger < Logger
    def initialize(*args)
    end

    def add(*args, &block)
    end
  end

  class State
    # TODO: support outputs!

    class << self
      def define(logger, vars, contexts, &block)
        template = new(logger, vars, contexts, &block)
        # StackModules.register(name, template)
      end

      def flatten_variable_arrays(variables)
        vars = variables.map do |k, v|
          if v.is_a?(Hash) && v.key?(:default) && v[:default].is_a?(Array)
            v[:default] = v[:default].join(',')
          elsif v.is_a?(Array)
            v = v.join(',')
          end
          [k, v]
        end
        Hash[vars]
      end
    end

    attr_reader :vars
    attr_reader :contexts
    attr_reader :logger
    attr_accessor :name, :secrets

    # def initialize(logger, vars, contexts)
    #   @logger = logger
    #   logger.info "Initializing state."

    #   @vars = Hashie::Mash.new(vars)
    #   logger.debug "State variables:"
    #   logger.ap vars, :debug

    #   @contexts = contexts

    #   @__output = {
    #     :provider => {},
    #     :variable => {},
    #     :resource => {}
    #   }
    # end

    def initialize(logger, vars, contexts, &block)
      @logger = logger
      logger.info "Initializing state."

      @vars = Hashie::Mash.new(vars)
      logger.debug "State variables:"
      logger.ap vars, :debug

      @contexts = contexts

      @__output = {
        :provider => {},
        :variable => {},
        :resource => {},
        :output   => {},
        :module   => {}
      }
      @block = block
    end

    # def initialize(name, &block)
    #   @name = name
    #   @stack_elements = { resource: {}, provider: {}, variable: {}, output: {}, module: {} }
    #   # @secrets = {}
    #   @block = block
    #   # variable(:cloudshaper_stack_id) { default '' }
    # end

    def __build()
      logger.info "Building Terraform script from state."
      logger.debug "Contexts:"
      @contexts.each { |c| logger.debug " - #{c}" }
      if @__output[:output].empty?
        @__output.delete(:output)
      end
      if @__output[:resource].empty?
        @__output.delete(:resource)
      end
      @__output.to_json
    end

    def __apply_script(script_name, script)
      logger.info "Applying script '#{script_name}' to state."
      instance_eval(script, script_name, 0)
      logger.info "Script '#{script_name}' applied successfully."
    end

    def build(**kwargs)
      vars = Hash[kwargs.map { |k, v| [k, { default: v }] }]
      @__output[:variable].merge!(vars)
      b = @block
      instance_eval(&b)
      self
    end

    def generate
      elts = elements
      if elts[:output].empty?
        elts.delete(:output)
      end
      if elts[:resource].empty?
        elts.delete(:resource)
      end
      JSON.pretty_generate(elts)
    end

    def get(variable)
      elements[:variable].fetch(variable)[:default]
    end

    def each_variable(&b)
      elements[:variable].each(&b)
    end

    def get_resource(type, id)
      @__output[:resource].fetch(type).fetch(id)
    end

    private

    def elements
      elements = @__output.clone
      variables = State.flatten_variable_arrays(@__output[:variable])
      @__output[:module].each do |mod, data|
        elements[:module][mod] = State.flatten_variable_arrays(data)
      end
      elements[:variable] = variables
      elements
    end

    def register_resource(resource_type, name, &block)
      handling_context_pair = @contexts.find { |k, v| v.resources.include?(resource_type.to_sym) }
      if handling_context_pair == nil
        msg = "Could not find a context that supports resource type '#{resource_type}'."
        logger.error msg
        raise msg
      end

      handling_context = handling_context_pair[1]
      resource_class = handling_context.resources[resource_type.to_sym]

      @__output[:resource] ||= {}
      @__output[:resource][resource_type.to_sym] ||= {}
      @__output[:resource][resource_type.to_sym][name.to_sym] = resource_class.new(self, name, resource_type, &block).fields
    end

    # def register_resource(resource_type, name, &block)
    #   @__output[:resource] ||= {}
    #   @__output[:resource][resource_type.to_sym] ||= {}
    #   @__output[:resource][resource_type.to_sym][name.to_sym] = Terraframe::Resource.new(self, name, resource_type, &block).fields
    # end

    def register_variable(name, &block)
      return if @__output[:variable].key?(name)

      # handling_context = {}

      # new_variable = Terraframe::Variable.new(vars, handling_context, &block).fields
      new_variable = Terraframe::Variable.new(self, &block).fields
      variable_content = {}
      if not new_variable[:description].nil?
        variable_content[:description] = new_variable[:description]
      end
      if not new_variable[:type].nil?
        if ['string', 'list', 'map'].include?(new_variable[:type])
            variable_content[:type] = new_variable[:type]
        else
            msg = "Unknown variable type: '#{new_variable[:type]}'."
            logger.fatal msg
            raise msg
        end
      end
      if not new_variable[:default].nil?
        variable_content[:default] = new_variable[:default]
      end
      @__output[:variable][name.to_sym] = variable_content
    end

    def register_output(name, &block)
      new_output = Terraframe::Output.new(self, &block).fields
      @__output[:output][name.to_sym] = new_output
    end

    def register_module(name, &block)
      new_module = Terraframe::Module.new(self, &block).fields
      @__output[:module][name.to_sym] = new_module
    end

    def register_provider(name, &block)
      provider = Terraframe::Provider.new(self, &block).fields
      @__output[:provider][name.to_sym] = provider
    end

    ## DSL FUNCTIONS BELOW ##
    # def provider(type, &block)
    #   if !@contexts[type]
    #     msg = "Unknown provider type: '#{type}'."
    #     logger.fatal msg
    #     raise msg
    #   end

    #   if @__output[:provider][type]
    #     msg = "Duplicate provider type (sorry, blame Terraform): '#{type}'"
    #     logger.fatal msg
    #     raise msg
    #   end

    #   handling_context = @contexts[type]
    #   provider = handling_context.provider_type.new(vars, handling_context, &block)
    #   logger.debug "Provider of type '#{type}': #{provider.inspect}"
    #   @__output[:provider][type] = provider

    #   provider
    # end

    # def variable(name, value)
    #   if @__output[:variable][name]
    #     msg = "Duplicate variable declaration: '#{name}'"
    #     logger.fatal msg
    #     raise msg
    #   end

    #   @__output[:variable][name] = value
    # end

    # def register_variable(name, &block)
    #   return if @__output[:variable].key?(name)

    #   # handling_context = {}

    #   # new_variable = Terraframe::Variable.new(vars, handling_context, &block).fields
    #   new_variable = Terraframe::Variable.new(self, &block).fields
    #   variable_content = {}
    #   if not new_variable[:description].nil?
    #     variable_content[:description] = new_variable[:description]
    #   end
    #   if not new_variable[:default].nil?
    #     variable_content[:default] = new_variable[:default]
    #   end
    #   @__output[:variable][name.to_sym] = variable_content
    # end

    # def register_provider(name, &block)
    #   provider = Terraframe::Provider.new(self, &block).fields
    #   @__output[:provider][name.to_sym] = provider
    # end

    # def resource(resource_type, resource_name, &block)
    #   handling_context_pair = @contexts.find { |k, v| v.resources.include?(resource_type) }
    #   if handling_context_pair == nil
    #     msg = "Could not find a context that supports resource type '#{resource_type}'."
    #     logger.error msg
    #     raise msg
    #   end

    #   handling_context = handling_context_pair[1]
    #   resource_class = handling_context.resources[resource_type]

    #   @__output[:resource][resource_type] ||= {}
    #   @__output[:resource][resource_type][resource_name.to_s] = resource_class.new(resource_name, vars, handling_context, &block)
    # end

    # anything that is not a provider or a variable should be interpreted 
    def method_missing(method_name, *args, &block)
      case method_name
        when "vars"
          @vars
        else
          if (args.length != 1)
            msg = "Too many arguments for resource invocation '#{method_name}'."
            logger.fatal(msg)
            raise msg
          end
          resource(method_name.to_sym, args[0], &block)
      end
    end

    # alias_method :variable2,  :register_variable

    alias_method :resource,  :register_resource
    alias_method :variable,  :register_variable
    alias_method :provider,  :register_provider
    alias_method :output,    :register_output
    alias_method :submodule, :register_module

  end
end
