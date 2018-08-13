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

  it "should parse external config" do
    src = <<-END
    version: '3.3'

    configs:
      kubeconfig:
        external: true
        name: istio-system_kubeconfig

    services:
      nginx:
        image: nginx
        configs:
          - source: kubeconfig
            target: /etc/kubeconfig
            mode: 0700
    END

    compose = Stack.parse_compose_file src

    configs = compose.configs
    kubeconfig = configs["kubeconfig"]
    kubeconfig.external.should be_true
    kubeconfig.name.should eq("kubeconfig")
    kubeconfig.real_name.should eq("istio-system_kubeconfig")

    services = compose.services
    services.should_not be(nil)
    services.empty?.should be_false
    services["nginx"].get_cmd(
      stack_name: "istio",
      ref_configs: compose.configs).should eq([
      "service", "create",
      "--name", "istio_nginx",
      "--network", "istio_default",
      "--label", "com.docker.stack.namespace=istio",
      "--config", "source=istio-system_kubeconfig,target=/etc/kubeconfig,mode=0700",
      "nginx",
    ])
  end
end
