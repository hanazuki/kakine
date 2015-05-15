require 'thor'
require 'fog'
require 'yaml'
require 'hashdiff'
require 'kakine/operation'

module Kakine
  class CLI < Thor
    include Kakine::Operation
    option :tenant, type: :string, aliases: '-t'
    desc 'show', 'show Security Groups specified tenant'
    def show
      puts Kakine::Resource.security_groups_hash(options[:tenant]).to_yaml
    end

    option :tenant, type: :string, aliases: "-t"
    option :dryrun, type: :boolean, aliases: "-d"
    option :filename, type: :string, aliases: "-f"
    desc 'apply', "apply local configuration into OpenStack"
    def apply
      adapter = if options[:dryrun]
        Kakine::Adapter::Mock.new
      else
        Kakine::Adapter::Real.new
      end

      filename = options[:filename] ? options[:filename] : "#{options[:tenant]}.yaml"

      reg_sg = Kakine::Resource.security_groups_hash(options[:tenant])
      diffs = HashDiff.diff(reg_sg, Kakine::Resource.yaml(filename))
      diffs.each do |diff|

        (sg_name, rule_modification) = diff[1].split(/[\.\[]/, 2)
        modify_content = Kakine::Resource.format_modify_contents(options[:tenant], sg_name, reg_sg, diff)
        modify_content = set_remote_security_group_id(modify_content, options[:tenant])

        if rule_modification # foo[2]

          case modify_content["div"]
          when "+"
            create_security_rule(sg_name, modify_content, options[:tenant], adapter)
          when "-"
            delete_security_rule(sg_name, modify_content, options[:tenant], adapter)
          when "~"
          else
            raise
          end

        else # foo
          case modify_content["div"]
          when "+"
            create_security_group(sg_name, modify_content, options[:tenant], adapter)
            create_security_rule(sg_name, modify_content, options[:tenant], adapter)
          when "-"
            delete_security_group(sg_name, options[:tenant], adapter)
          when "~"
          else
            raise
          end
        end
      end
    end
  end
end
