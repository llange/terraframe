require 'hashie/mash'
require 'terraframe/resource'
require 'pry'

module Terraframe
  module AWS
    class AWSResource < Terraframe::Resource
      ## DSL FUNCTIONS BELOW
      def method_missing(method_name, *args, &block)
        if method_name == "tags"
          raise "This resource does not support tags."
        end  
        super(method_name, *args, &block)
      end
    end

    class AWSTaggedResource < Terraframe::Resource
      def initialize(parent_module, resource_name, resource_type, &block)
        super(parent_module, resource_name, resource_type, &block)
      # def initialize(name, vars, context, &block)
        @fields = {}
        # @vars = Hashie::Mash.new(vars)

        clear_tags!
        @fields["tags"]["Name"] = resource_name

        instance_eval &block
      end

      def tags(&block)
        tag_set = Terraframe::AWS::AWSTagBlock.new(@vars, @context, &block)
        @fields["tags"].merge!(tag_set.fields)
      end

      def clear_tags!
        @fields["tags"] = {}
      end
    end

    class AWSTagBlock < Terraframe::ScriptItem
    end

    class AWSSecurityGroupResource < AWSTaggedResource
      def initialize(parent_module, resource_name, resource_type, &block)
      # def initialize(name, vars, context, &block)
        super(parent_module, resource_name, resource_type, &block)
        # super(name, vars, context, &block)
        @fields["name"] = resource_name
      end
    end
  end
end
