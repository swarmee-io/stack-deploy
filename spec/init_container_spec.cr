require "./spec_helper"
require "yaml"
require "json"
require "base64"

describe Stack do
  it "should parse init container correctly" do
    src = <<-END
    version: '3.3'

    init-containers:
      dns-init:
        image: swarmee/dns-init:0.8.0
        cap_drop:
        - ALL
        cap_add:
        - NET_BIND
        privileged: true
        command: ["10.32.88.88", "8600"]

    services:
      nginx:
        image: nginx
        init-containers:
          - dns-init
    END

    dns_init_desc = YAML.parse(src)["init-containers"]["dns-init"]
    dns_init = Stack.parse_init_container(dns_init_desc).as(Stack::InitContainer)
    dns_init.get_cmd.should eq([
      "--privileged",
      "--cap-add", "NET_BIND",
      "--cap-drop", "ALL",
      "swarmee/dns-init:0.8.0",
      "10.32.88.88", "8600",
    ])

    init_containers = {"dns-init" => dns_init}

    nginx_desc = YAML.parse(src)["services"]["nginx"]
    nginx = Stack.parse_service("nginx", nginx_desc).as(Stack::Service)
    cmd = nginx.get_cmd("istio", init_containers)

    s = cmd.find { |x| x.starts_with?("io.swarmee.init-containers=") }
    s = s.as(String)
    name = s.split("=")[1]
    name.should eq("dns-init")

    s = cmd.find { |x| x.starts_with?("io.swarmee.init-container.dns-init=") }
    s = s.as(String)
    b64 = s.split("=")[1]
    json = Base64.decode_string(b64)
    result = Array(String).from_json(json)
    result.should eq([
      "--privileged",
      "--cap-add", "NET_BIND",
      "--cap-drop", "ALL",
      "swarmee/dns-init:0.8.0",
      "10.32.88.88", "8600",
    ])
  end

  it "should parse multiple init containers correctly" do
    src = <<-END
    version: '3.3'

    init-containers:
      dns-init:
        image: swarmee/dns-init:0.8.0
        cap_drop:
        - ALL
        cap_add:
        - NET_BIND
        privileged: true
        command: ["10.32.88.88", "8600"]
      dns-init-2:
        image: swarmee/dns-init-2:0.8.0
        cap_drop:
        - ALL
        cap_add:
        - NET_BIND
        privileged: true
        command: ["10.32.88.88", "8600"]

    services:
      nginx:
        image: nginx
        init-containers:
          - dns-init
          - dns-init-2
    END

    dns_init_desc = YAML.parse(src)["init-containers"]["dns-init"]
    dns_init = Stack.parse_init_container(dns_init_desc).as(Stack::InitContainer)
    dns_init.get_cmd.should eq([
      "--privileged",
      "--cap-add", "NET_BIND",
      "--cap-drop", "ALL",
      "swarmee/dns-init:0.8.0",
      "10.32.88.88", "8600",
    ])

    dns_init_desc_2 = YAML.parse(src)["init-containers"]["dns-init-2"]
    dns_init_2 = Stack.parse_init_container(dns_init_desc_2).as(Stack::InitContainer)
    dns_init_2.get_cmd.should eq([
      "--privileged",
      "--cap-add", "NET_BIND",
      "--cap-drop", "ALL",
      "swarmee/dns-init-2:0.8.0",
      "10.32.88.88", "8600",
    ])

    init_containers = {"dns-init" => dns_init, "dns-init-2" => dns_init_2}

    nginx_desc = YAML.parse(src)["services"]["nginx"]
    nginx = Stack.parse_service("nginx", nginx_desc).as(Stack::Service)
    cmd = nginx.get_cmd("istio", init_containers)

    s = cmd.find { |x| x.starts_with?("io.swarmee.init-containers=") }
    s = s.as(String)
    name = s.split("=")[1]
    name.should eq("dns-init,dns-init-2")

    s = cmd.find { |x| x.starts_with?("io.swarmee.init-container.dns-init=") }
    s = s.as(String)
    b64 = s.split("=")[1]
    json = Base64.decode_string(b64)
    result = Array(String).from_json(json)
    result.should eq([
      "--privileged",
      "--cap-add", "NET_BIND",
      "--cap-drop", "ALL",
      "swarmee/dns-init:0.8.0",
      "10.32.88.88", "8600",
    ])

    s = cmd.find { |x| x.starts_with?("io.swarmee.init-container.dns-init-2=") }
    s = s.as(String)
    b64 = s.split("=")[1]
    json = Base64.decode_string(b64)
    result = Array(String).from_json(json)
    result.should eq([
      "--privileged",
      "--cap-add", "NET_BIND",
      "--cap-drop", "ALL",
      "swarmee/dns-init-2:0.8.0",
      "10.32.88.88", "8600",
    ])
  end
end
