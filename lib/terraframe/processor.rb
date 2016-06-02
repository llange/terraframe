require 'logger'
require 'digest/sha1'
require 'yaml'

require 'active_support/core_ext/hash'
require 'awesome_print'

require 'terraframe/state'
require 'terraframe/aws/aws_context'

module Terraframe
  class Processor
    attr_reader :logger
    attr_reader :contexts


    def initialize
      @logger = Logger.new($stderr)
      logger.level = Logger::DEBUG

      logger.debug "Logger initialized."

      @contexts = {}
      register_context(:aws, Terraframe::AWS::AWSContext.new)
    end

    def register_context(name, context)
    logger.info "Defining context '#{name}'."
      name = name.to_sym
      if @contexts[name]
        logger.warn "A context with the name '#{name}' has been registered more than once."
      end
      @contexts[name] = context
    end

    def process_files(scripts, variable_files, override_variables)
      scripts = scripts.map { |f| File.expand_path(f) }
      variable_files = variable_files.map { |f| File.expand_path(f) }

      missing_scripts = scripts.reject { |f| File.exist?(f) }
      missing_variable_files = variable_files.reject { |f| File.exist?(f) }
      unless missing_scripts.empty? && missing_variable_files.empty?
        missing_scripts.each { |f| logger.fatal "Script file not found: #{f}" }
        missing_variable_files.each { |f| logger.fatal "Variable file not found: #{f}" }
        raise "One or more specified files were missing."
      end


      script_pairs = scripts.zip(scripts.map { |f| IO.read(f) })
      vars = load_variable_files(variable_files).deep_merge(override_variables)

      apply(script_pairs.to_h, vars)
    end

    def load_variable_files(variable_files)
      vars = {}
      variable_files.each { |f| vars = vars.deep_merge(YAML::load_file(f)) }
      vars
    end

    def apply(inputs, vars)
      logger.info "Beginning state execution."

      state = State.new(logger, vars, @contexts)
      inputs.each { |input| state.__apply_script(input[0], input[1])}
      state.__build()
    end
  end
end