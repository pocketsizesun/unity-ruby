# frozen_string_literal: true

module Unity
  module CLI
    class EcsCommand < Unity::CLI::Command


      def initialize
        super
        @root_dir = Dir.pwd
        @configuration_file = "#{@root_dir}/unity.yml"
        @docker_binary = ENV['DOCKER_EXECUTABLE'] || find_docker_executable
      end

      # @return [void]
      def call(*args)
        sub_command = args.shift

        case sub_command
        when 'deploy'
          deploy_handler(args)
        end
      end

      private

      def find_docker_executable
        %w[/usr/local/bin/docker /usr/bin/docker].find do |path|
          File.exist?(path)
        end
      end

      # @param args [Array<String>]
      # @return [void]
      def deploy_handler(args)
        @logger.info "Run ECS deploy in: #{@root_dir}"

        ecs_configuration = YAML.load_file(@configuration_file).fetch('ecs')
        environment_name = args.shift

        if environment_name.nil? || environment_name.empty?
          @logger.fatal 'Environment must be provided, example: bundle exec unity ecs deploy staging'
          exit(-1)
        end
        @logger.info "Read configuration for environment '#{environment_name}' from '#{@root_dir}/unity.yml'"

        configuration = ecs_configuration.dig('environments', environment_name)
        if configuration.nil?
          @logger.fatal "Environment '#{environment_name}' does not have a configuration"
          exit(-1)
        end

        # retrieve build configuration
        image_configuration = configuration.fetch('image')
        image_name = image_configuration.fetch('name')
        image_tag_name = image_configuration['tag_name'] || Time.now.strftime("%Y%m%d_%H%M%S")
        image_repository_url = image_configuration['repository_url'] || "#{image_configuration.fetch('repository')}/#{image_name}"

        # build image
        execute_and_wait_success :image_build do |cmd_args|
          cmd_args << @docker_binary
          cmd_args << 'buildx'
          cmd_args << 'build'

          # platforms
          if !image_configuration['platforms'].nil? && image_configuration['platforms'].length > 0
            image_configuration['platforms'].each do |platform_name|
              cmd_args << '--platform'
              cmd_args << platform_name
            end
          end

          # build name
          cmd_args << '-t'
          cmd_args << image_name

          # dockerfile
          cmd_args << '-f'
          cmd_args << 'Dockerfile'
          cmd_args << '.'
        end

        # tag image
        execute_and_wait_success :image_tag do |cmd_args|
          cmd_args << @docker_binary
          cmd_args << 'tag'

          # tag name
          cmd_args << "#{image_name}:#{image_tag_name}"

          # repository url
          cmd_args << "#{image_repository_url}:#{image_tag_name}"
        end

        # push image
        execute_and_wait_success :image_push do |cmd_args|
          cmd_args << @docker_binary
          cmd_args << 'push'

          # push destination
          cmd_args << "#{image_repository_url}:#{image_tag_name}"
        end
      end

      def execute_and_wait(&block)
        cmd_args = []
        block.call(cmd_args)
        @logger.info "execute command: #{cmd_args.join(' ')}"

        pid = fork do
          exec(*cmd_args)
        end
        Process.waitpid2(pid)
      end

      def execute_and_wait_success(name, &block)
        pid, process_status = execute_and_wait(&block)
        return if process_status.exitstatus == 0

        abort "Command '#{name}' has failed"
      end
    end
  end
end
