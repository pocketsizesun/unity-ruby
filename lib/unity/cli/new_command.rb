# frozen_string_literal: true
require 'fileutils'
require 'erb'

module Unity
  module Cli
    class NewCommand
      MAIN_MODULE_TEMPLATE = <<~TPL
        # frozen_string_literal: true

        module <%= @app_module_name %>
        end
      TPL

      TEST_OPERATION_TEMPLATE = <<~TPL
        # frozen_string_literal: true

        module <%= @app_module_name %>
          module Operations
            class TestOperation < Unity::Operation
              def call(args)
                Output.new('args' => args)
              end
            end
          end
        end
      TPL

      def self.call(argv)
        new.call(argv)
      end

      def call(argv)
        @target_directory = nil
        OptionParser.new do |opts|
          opts.on('-d', '--directory=NAME') do |v|
            @target_directory = v.to_s
          end

          opts.on('-p', '--port=PORT') do |v|
            @app_port = v.to_s
          end
        end.parse!(argv)

        @skel_path = File.realpath(File.dirname(__FILE__) + '/../../../skel')
        @app_name = argv.shift
        @app_module_name = @app_name.camelize
        @app_standard_name = @app_name.tr('-_', '')
        @target_directory ||= @app_name

        FileUtils.mkdir_p(@target_directory)
        ['lib', 'lib/tasks', "lib/#{@app_name}", "lib/#{@app_name}/operations", 'log'].each do |dir|
          FileUtils.mkdir_p("#{@target_directory}/#{dir}")
        end

        ["lib/#{@app_name}/.keep", 'log/.keep', 'lib/tasks/.keep'].each do |file|
          FileUtils.touch("#{@target_directory}/#{file}")
        end

        # write main module
        File.write(
          "#{@target_directory}/lib/#{@app_name}.rb",
          ERB.new(MAIN_MODULE_TEMPLATE).result(binding)
        )

        # write test operation
        File.write(
          "#{@target_directory}/lib/#{@app_name}/operations/test_operation.rb",
          ERB.new(TEST_OPERATION_TEMPLATE).result(binding)
        )

        # render all files
        render_directory(@skel_path)

        puts "----------------------------------"
        p @target_directory
        p @skel_path, @app_name, @app_module_name, @app_standard_name
      end

      private

      def render_directory(dir)
        Dir.entries(dir).each do |entry|
          next if entry == '.' || entry == '..'

          entry_path = "#{dir}/#{entry}"

          if File.directory?(entry_path)
            dir_target_path = entry_path.gsub("#{@skel_path}/", '')
            FileUtils.mkdir_p("#{@target_directory}/#{dir_target_path}")
            render_directory(entry_path)
          else
            file_target_path = entry_path.gsub("#{@skel_path}/", '')
            tpl = ERB.new(File.read(entry_path))
            File.write("#{@target_directory}/#{file_target_path}", tpl.result(binding))
          end
        end
      end
    end
  end
end
