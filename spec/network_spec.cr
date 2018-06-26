require "./spec_helper"
require "yaml"

describe Stack do
  it "should parse a default network to a command correctly" do
    src = <<-END
    version: '3.3'

    services:
      nginx:
        image: nginx

    networks:
      default:
        name: net
    END

    default_desc = YAML.parse(src)["networks"]["default"]
    net = Stack.parse_network("default", default_desc).as(Stack::Network)

    net.name.should eq("default")
    net.real_name.should eq("net")
    net.is_default.should be_true
    net.is_external.should be_false

    net.get_cmd("nginx").should eq([
      "network", "create",
      "-d", "overlay",
      "--label", "com.docker.stack.namespace=nginx",
      "nginx_net",
    ])
  end

  it "should parse a default external network" do
    src = <<-END
    version: '3.3'

    services:
      nginx:
        image: nginx

    networks:
      default:
        name: net
        external: true
    END

    default_desc = YAML.parse(src)["networks"]["default"]
    net = Stack.parse_network("default", default_desc).as(Stack::Network)

    net.name.should eq("default")
    net.real_name.should eq("net")
    net.is_default.should be_true
    net.is_external.should be_true
  end

  it "should parse a network with driver specified" do
    src = <<-END
    version: '3.3'

    services:
      nginx:
        image: nginx

    networks:
      istiomesh:
        driver: weaveworks/net-plugin:2.3.0
    END

    default_desc = YAML.parse(src)["networks"]["istiomesh"]
    net = Stack.parse_network("istiomesh", default_desc).as(Stack::Network)

    net.name.should eq("istiomesh")
    net.real_name.should eq("istiomesh")
    net.is_default.should be_false
    net.is_external.should be_false

    net.get_cmd(stack_name: "nginx").should eq([
      "network", "create",
      "-d", "weaveworks/net-plugin:2.3.0",
      "--label", "com.docker.stack.namespace=nginx",
      "nginx_istiomesh",
    ])
  end

  it "should parse a network with attachable and ipam" do
    src = <<-END
    version: '3.3'

    services:
      nginx:
        image: nginx

    networks:
      istiomesh:
        driver: weaveworks/net-plugin:2.3.0
        attachable: true
        ipam:
          driver: my-driver
    END

    default_desc = YAML.parse(src)["networks"]["istiomesh"]
    net = Stack.parse_network("istiomesh", default_desc).as(Stack::Network)

    net.name.should eq("istiomesh")
    net.real_name.should eq("istiomesh")
    net.is_default.should be_false
    net.is_external.should be_false

    net.get_cmd(stack_name: "nginx").should eq([
      "network", "create",
      "-d", "weaveworks/net-plugin:2.3.0",
      "--attachable",
      "--ipam-driver", "my-driver",
      "--label", "com.docker.stack.namespace=nginx",
      "nginx_istiomesh",
    ])
  end

  it "should parse a network with multiple subnets" do
    src = <<-END
    version: '3.3'

    services:
      nginx:
        image: nginx

    networks:
      istiomesh:
        driver: weaveworks/net-plugin:2.3.0
        attachable: true
        ipam:
          driver: default
          config:
            - subnet: 10.32.0.0/16
            - subnet: 10.33.0.0/16
    END

    default_desc = YAML.parse(src)["networks"]["istiomesh"]
    net = Stack.parse_network("istiomesh", default_desc).as(Stack::Network)

    net.name.should eq("istiomesh")
    net.real_name.should eq("istiomesh")
    net.is_default.should be_false
    net.is_external.should be_false

    net.get_cmd(stack_name: "nginx").should eq([
      "network", "create",
      "-d", "weaveworks/net-plugin:2.3.0",
      "--attachable",
      "--subnet", "10.32.0.0/16",
      "--subnet", "10.33.0.0/16",
      "--label", "com.docker.stack.namespace=nginx",
      "nginx_istiomesh",
    ])
  end

  it "should parse a network with a subnet and ip-ranges" do
    src = <<-END
    version: '3.3'

    services:
      nginx:
        image: nginx

    networks:
      istiomesh:
        driver: weaveworks/net-plugin:2.3.0
        ipam:
          driver: default
          config:
            - subnet: 10.32.0.0/16
              ip_ranges:
                - 10.32.0.0/18
                - 10.32.0.1/18
    END

    default_desc = YAML.parse(src)["networks"]["istiomesh"]
    net = Stack.parse_network("istiomesh", default_desc).as(Stack::Network)

    net.name.should eq("istiomesh")
    net.real_name.should eq("istiomesh")
    net.is_default.should be_false
    net.is_external.should be_false

    net.get_cmd(stack_name: "nginx").should eq([
      "network", "create",
      "-d", "weaveworks/net-plugin:2.3.0",
      "--subnet", "10.32.0.0/16",
      "--ip-range", "10.32.0.0/18",
      "--ip-range", "10.32.0.1/18",
      "--label", "com.docker.stack.namespace=nginx",
      "nginx_istiomesh",
    ])
  end
end
