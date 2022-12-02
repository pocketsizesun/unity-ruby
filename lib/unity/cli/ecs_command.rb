# frozen_string_literal: true

module Unity
  module CLI
    class EcsCommand < Unity::CLI::Command
      def initialize
        super
        @root_dir = Dir.pwd
        @configuration_file = "#{@root_dir}/unity.yml"
        @docker_binary = ENV['DOCKER_EXECUTABLE'] || find_docker_executable || 'docker'
        @aws_executable = ENV['AWS_EXECUTABLE'] || find_aws_executable || 'aws'
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

      # @return [String, nil]
      def find_docker_executable
        %w[/usr/local/bin/docker /usr/bin/docker].find do |path|
          File.exist?(path)
        end
      end

      # @return [String, nil]
      def find_aws_executable
        %w[/opt/homebrew/bin/aws /usr/local/bin/aws /usr/bin/aws].find do |item|
          File.exist?(item)
        end
      end

      # @param args [Array<String>]
      # @return [void]
      def deploy_handler(args)
        options = {
          dry_run: false
        }
        OptionParser.new do |opts|
          opts.on('--dry-run', 'Enable dry run') do
            options[:dry_run] = true
          end
        end.parse!(args)

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
        ecs_name = ecs_configuration.fetch('name')
        cluster_name = configuration.fetch('cluster_name')
        image_configuration = configuration.fetch('image')
        image_name = image_configuration.fetch('name')
        image_tag_name = image_configuration['tag_name'] || Time.now.strftime("%Y%m%d_%H%M%S")
        image_repository_url = image_configuration['repository_url'] || "#{image_configuration.fetch('repository')}/#{image_name}"
        services_configuration = configuration.fetch('services')

        # build image
        execute_and_wait_success :image_build, dry_run: options[:dry_run] do |cmd_args|
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
        execute_and_wait_success :image_tag, dry_run: options[:dry_run] do |cmd_args|
          cmd_args << @docker_binary
          cmd_args << 'tag'

          # tag name
          cmd_args << "#{image_name}:#{image_tag_name}"

          # repository url
          cmd_args << "#{image_repository_url}:#{image_tag_name}"
        end

        # push image
        execute_and_wait_success :image_push, dry_run: options[:dry_run] do |cmd_args|
          cmd_args << @docker_binary
          cmd_args << 'push'

          # push destination
          cmd_args << "#{image_repository_url}:#{image_tag_name}"
        end

        # deploy on ECS cluster
        unless configuration['aws_profile'].nil?
          ENV['AWS_PROFILE'] ||= configuration['aws_profile']
        end
        services_configuration.each do |service_configuration|
          # aws ecs update-service --cluster <cluster name> --service <service name> --force-new-deployment
          execute_and_wait_success :ecs_update_service, dry_run: options[:dry_run] do |cmd_args|
            cmd_args << @aws_executable
            cmd_args << 'ecs'
            cmd_args << 'update-service'
            cmd_args << '--cluster'
            cmd_args << cluster_name
            cmd_args << '--service'
            cmd_args << "#{ecs_name}_#{service_configuration.fetch('name')}"
            cmd_args << '--force-new-deployment'
          end
        end
      end

      def execute_and_wait(**kwargs, &block)
        cmd_args = []
        block.call(cmd_args)
        @logger.info "execute command: #{cmd_args.join(' ')}"

        if kwargs[:dry_run] == true
          return 0
        else
          pid = fork do
            exec(*cmd_args)
          end

          pid, status = Process.waitpid2(pid)

          return status.exitstatus
        end
      end

      def execute_and_wait_success(name, **kwargs, &block)
        exitcode = execute_and_wait(**kwargs, &block)
        return if exitcode == 0

        abort "Command '#{name}' has failed"
      end
    end
  end
end
