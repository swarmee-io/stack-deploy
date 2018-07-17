require "./stack/*"
require "admiral"

# TODO: Write documentation for `Stack`
module Stack
  class StackApp < Admiral::Command
    define_version Stack::VERSION
    define_help description: "stack deploy"

    register_sub_command deploy : Deploy, description: "deploy a stack"

    def run
      puts help
    end
  end

  StackApp.run
end
