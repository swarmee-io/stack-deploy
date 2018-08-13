require "admiral"

module Stack
  class Deploy < Admiral::Command
    define_flag compose_file : String,
      default: "docker-compose.yaml",
      long: "compose-file",
      short: c,
      required: true

    define_argument stack_name : String,
      required: true

    def run
      compose = Stack.parse_compose(flags.compose_file)
      stack_name = arguments.stack_name

      compose.configs.each do |name, config|
        puts("Creating config #{name} ...")
        config.create(compose.dir, stack_name)
      end

      compose.networks.each do |name, network|
        if network.pre_check(stack_name) == false
          return
        end
      end

      compose.networks.each do |name, network|
        puts("Creating network #{name} ...")
        network.create(stack_name)
      end

      compose.services.each do |name, service|
        puts("Creating service #{name} ...")
        service.create(stack_name,
          ref_init_containers: compose.init_containers,
          ref_networks: compose.networks,
          ref_configs: compose.configs)
      end
    end
  end
end
