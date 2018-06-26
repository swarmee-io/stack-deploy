require "./spec_helper"
require "yaml"

describe Stack do
  it "should parse config definition correctly" do
    src = <<-END
    version: '3.3'

    configs:
      kubeconfig:
        file: ./kubeconfig

    services:
      nginx:
        image: nginx

    END

    desc = YAML.parse(src)["configs"]["kubeconfig"]
    cfg = Stack.parse_config("kubeconfig", desc).as(Stack::Config)

    cfg.get_cmd(stack_name: "nginx").should eq([
      "config", "create",
      "--label", "com.docker.stack.namespace=nginx",
      "nginx_kubeconfig", "./kubeconfig",
    ])
  end
end
