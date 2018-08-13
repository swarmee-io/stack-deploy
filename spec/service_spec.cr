require "./spec_helper"
require "yaml"

describe Stack do
  # TODO: Write tests

  it "version is required" do
    # false.should eq(true)
    src = <<-END
    ---
    xversion: '3.3'
    END

    expect_raises(Exception, "version is required") do
      result = Stack.parse_compose_file src
    end
  end

  it "detect if version is 3.3" do
    # false.should eq(true)
    src = <<-END
    ---
    version: '3.3'
    END

    expect_raises(Exception, "no service defined") do
      result = Stack.parse_compose_file src
    end
  end

  it "detect if version is NOT 3.3" do
    # false.should eq(true)
    src = <<-END
    ---
    version: '3.2'
    END

    expect_raises(Exception, "version incorrect") do
      result = Stack.parse_compose_file src
    end
  end

  it "a service is defined" do
    # false.should eq(true)
    src = <<-END
    ---
    version: '3.3'
    services:
      s: {}
    END

    result = Stack.parse_compose_file src
    result.services.empty?.should be_true
  end

  it "nginx service is correct" do
    # false.should eq(true)
    src = <<-END
    ---
    version: '3.3'
    services:
      nginx:
        image: nginx
    END

    result = Stack.parse_compose_file src
    services = result.services

    services.should_not be(nil)
    services.empty?.should be_false
    services["nginx"].get_cmd("nginx").should eq([
      "service", "create",
      "--name", "nginx_nginx",
      "--network", "nginx_default",
      "--label", "com.docker.stack.namespace=nginx",
      "nginx",
    ])
  end

  it "nginx service created successfully" do
    # false.should eq(true)
    src = <<-END
    nginx:
      image: nginx
    END

    nginx_desc = YAML.parse(src)["nginx"]
    svc = Stack.parse_service("nginx", nginx_desc).as(Stack::Service)

    svc.name.should eq("nginx")
    svc.image.should eq("nginx")
  end

  it "should generate etcd service with labels as strings correctly" do
    src = <<-END
    ---
    version: '3.3'
    services:
      etcd:
        image: quay.io/coreos/etcd:latest
        deploy:
          endpoint_mode: dnsrr
        labels:
          - io.swarmee.ipv4.istio_istiomesh=10.32.0.11
          - SERVICE_IGNORE=1
    END

    result = Stack.parse_compose_file src
    services = result.services

    services.should_not be(nil)
    services.empty?.should be_false
    services["etcd"].get_cmd(stack_name: "istio").should eq([
      "service", "create",
      "--name", "istio_etcd",
      "--network", "istio_default",
      "--endpoint-mode", "dnsrr",
      "--label", "com.docker.stack.namespace=istio",
      "--container-label", "io.swarmee.ipv4.istio_istiomesh=10.32.0.11",
      "--container-label", "SERVICE_IGNORE=1",
      "quay.io/coreos/etcd:latest",
    ])
  end

  it "should generate etcd service with labels as maps correctly" do
    src = <<-END
    ---
    version: '3.3'
    services:
      etcd:
        image: quay.io/coreos/etcd:latest
        deploy:
          endpoint_mode: dnsrr
        labels:
          io.swarmee.ipv4.istio_istiomesh: 10.32.0.11
          SERVICE_IGNORE: 1
    END

    result = Stack.parse_compose_file src
    services = result.services

    services.should_not be(nil)
    services.empty?.should be_false
    services["etcd"].get_cmd(stack_name: "istio").should eq([
      "service", "create",
      "--name", "istio_etcd",
      "--network", "istio_default",
      "--endpoint-mode", "dnsrr",
      "--label", "com.docker.stack.namespace=istio",
      "--container-label", "io.swarmee.ipv4.istio_istiomesh=10.32.0.11",
      "--container-label", "SERVICE_IGNORE=1",
      "quay.io/coreos/etcd:latest",
    ])
  end

  it "should generate etcd service with cmds correctly" do
    src = <<-END
    ---
    version: '3.3'
    services:
      etcd:
        image: quay.io/coreos/etcd:latest
        deploy:
          endpoint_mode: dnsrr
        labels:
          - io.swarmee.ipv4.istio_istiomesh=10.32.0.11
          - SERVICE_IGNORE=1
        command: ["/usr/local/bin/etcd",
                  "-advertise-client-urls=http://0.0.0.0:2379",
                  "-listen-client-urls=http://0.0.0.0:2379"]
    END

    result = Stack.parse_compose_file src
    services = result.services

    services.should_not be(nil)
    services.empty?.should be_false
    services["etcd"].get_cmd(stack_name: "istio").should eq([
      "service", "create",
      "--name", "istio_etcd",
      "--network", "istio_default",
      "--endpoint-mode", "dnsrr",
      "--label", "com.docker.stack.namespace=istio",
      "--container-label", "io.swarmee.ipv4.istio_istiomesh=10.32.0.11",
      "--container-label", "SERVICE_IGNORE=1",
      "quay.io/coreos/etcd:latest",
      "/usr/local/bin/etcd",
      "-advertise-client-urls=http://0.0.0.0:2379",
      "-listen-client-urls=http://0.0.0.0:2379",
    ])
  end

  it "should parse network aliases" do
    src = <<-END
    ---
    version: '3.3'
    services:
      apiserver:
        image: gcr.io/google_containers/kube-apiserver-amd64:v1.7.3
        labels:
          - io.swarmee.privileged=true
          - SERVICE_IGNORE=1
        deploy:
          endpoint_mode: dnsrr
        networks:
          default:
            aliases:
              - istio-apiserver
              - apiserver
        command: ["kube-apiserver",
                  "--etcd-servers",
                  "http://etcd:2379",
                  "--service-cluster-ip-range", "10.99.0.0/16",
                  "--insecure-port", "8080",
                  "-v", "2",
                  "--insecure-bind-address", "0.0.0.0"]
    END

    result = Stack.parse_compose_file src
    services = result.services

    services.should_not be(nil)
    services.empty?.should be_false
    services["apiserver"].get_cmd(stack_name: "istio").should eq([
      "service", "create",
      "--name", "istio_apiserver",
      "--network", "istio_default",
      "--endpoint-mode", "dnsrr",
      "--label", "com.docker.stack.namespace=istio",
      "--container-label", "io.swarmee.privileged=true",
      "--container-label", "SERVICE_IGNORE=1",
      "--container-label", "io.swarmee.network-aliases.istio_default=istio-apiserver,apiserver",
      "gcr.io/google_containers/kube-apiserver-amd64:v1.7.3",
      "kube-apiserver",
      "--etcd-servers",
      "http://etcd:2379",
      "--service-cluster-ip-range", "10.99.0.0/16",
      "--insecure-port", "8080",
      "-v", "2",
      "--insecure-bind-address", "0.0.0.0",
    ])
  end

  # TODO "--published", "published=8080,target=8080,mode=host",
  it "should parse port in host mode" do
    src = <<-END
    ---
    version: '3.3'
    services:
      consul:
        image: gliderlabs/consul-server
        labels:
          - io.swarmee.ipv4.istio_default=10.32.88.88
          - io.swarmee.dns.ipv4=10.32.88.88
          - io.swarmee.dns.port=8600
          - SERVICE_IGNORE=1
        deploy:
          endpoint_mode: dnsrr
        ports:
          - published: 8500
            target: 8500
            mode: host
          - published: 8600
            target: 8600
            mode: host
            protocol: tcp
        command: ["-bootstrap", "-ui", "-advertise=10.32.88.88"]
    END

    result = Stack.parse_compose_file src
    services = result.services

    services.should_not be(nil)
    services.empty?.should be_false
    services["consul"].get_cmd(stack_name: "istio").should eq([
      "service", "create",
      "--name", "istio_consul",
      "--network", "istio_default",
      "--endpoint-mode", "dnsrr",
      "--label", "com.docker.stack.namespace=istio",
      "--container-label", "io.swarmee.ipv4.istio_default=10.32.88.88",
      "--container-label", "io.swarmee.dns.ipv4=10.32.88.88",
      "--container-label", "io.swarmee.dns.port=8600",
      "--container-label", "SERVICE_IGNORE=1",
      "--publish", "published=8500,target=8500,mode=host",
      "--publish", "published=8600,target=8600,mode=host,protocol=tcp",
      "gliderlabs/consul-server",
      "-bootstrap", "-ui", "-advertise=10.32.88.88",
    ])
  end

  # TODO "--published", "published=8080,target=8080,mode=host",
  it "should parse ports as string array" do
    src = <<-END
    ---
    version: '3.3'
    services:
      consul:
        image: gliderlabs/consul-server
        labels:
          - io.swarmee.ipv4.istio_default=10.32.88.88
          - io.swarmee.dns.ipv4=10.32.88.88
          - io.swarmee.dns.port=8600
          - SERVICE_IGNORE=1
        deploy:
          endpoint_mode: dnsrr
        ports:
          - 9000:9000/tcp
          - 8000:8000/tcp
        command: ["-bootstrap", "-ui", "-advertise=10.32.88.88"]
    END

    result = Stack.parse_compose_file src
    services = result.services

    services.should_not be(nil)
    services.empty?.should be_false
    services["consul"].get_cmd(stack_name: "istio").should eq([
      "service", "create",
      "--name", "istio_consul",
      "--network", "istio_default",
      "--endpoint-mode", "dnsrr",
      "--label", "com.docker.stack.namespace=istio",
      "--container-label", "io.swarmee.ipv4.istio_default=10.32.88.88",
      "--container-label", "io.swarmee.dns.ipv4=10.32.88.88",
      "--container-label", "io.swarmee.dns.port=8600",
      "--container-label", "SERVICE_IGNORE=1",
      "--publish", "9000:9000/tcp",
      "--publish", "8000:8000/tcp",
      "gliderlabs/consul-server",
      "-bootstrap", "-ui", "-advertise=10.32.88.88",
    ])
  end

  it "should parse deploy in global mode correctly" do
    src = <<-END
    version: '3.3'
    services:
      sidecar-injector:
        image: swarmee/hooks:latest
        networks: {}
        labels:
          io.swarmee.privileged: "true"
        deploy:
          mode: global
    END

    result = Stack.parse_compose_file src
    services = result.services

    services.should_not be(nil)
    services.empty?.should be_false
    services["sidecar-injector"].get_cmd(stack_name: "istio").should eq([
      "service", "create",
      "--name", "istio_sidecar-injector",
      "--mode", "global",
      "--label", "com.docker.stack.namespace=istio",
      "--container-label", "io.swarmee.privileged=true",
      "swarmee/hooks:latest",
    ])
  end

  it "should parse command as string" do
    src = <<-END
    version: '3.3'
    services:
      coredns:
        image: coredns/coredns
        command: -conf /data/Corefile
        ports:
          - "53:53/udp"
          - "53:53/tcp"
          - "9153:9153/tcp"
    END

    result = Stack.parse_compose_file src
    services = result.services

    services.should_not be(nil)
    services.empty?.should be_false
    services["coredns"].get_cmd(stack_name: "istio").should eq([
      "service", "create",
      "--name", "istio_coredns",
      "--network", "istio_default",
      "--label", "com.docker.stack.namespace=istio",
      "--publish", "53:53/udp",
      "--publish", "53:53/tcp",
      "--publish", "9153:9153/tcp",
      "coredns/coredns",
      "-conf /data/Corefile",
    ])
  end

  it "should parse cap_drop cap_add and read_only successfully" do
    src = <<-END
    version: '3.3'
    services:
      coredns:
        image: coredns/coredns
        command: -conf /data/Corefile
        ports:
          - "53:53/udp"
          - "53:53/tcp"
          - "9153:9153/tcp"
        cap_drop:
          - ALL
        cap_add:
          - NET_BIND_SERVICE
        read_only: true
    END

    result = Stack.parse_compose_file src
    services = result.services
    services.should_not be(nil)
    services.empty?.should be_false
    services["coredns"].get_cmd(stack_name: "istio").should eq([
      "service", "create",
      "--name", "istio_coredns",
      "--network", "istio_default",
      "--label", "com.docker.stack.namespace=istio",
      "--container-label", "io.swarmee.cap_drop=ALL",
      "--container-label", "io.swarmee.cap_add=NET_BIND_SERVICE",
      "--publish", "53:53/udp",
      "--publish", "53:53/tcp",
      "--publish", "9153:9153/tcp",
      "--read-only",
      "coredns/coredns",
      "-conf /data/Corefile",
    ])
  end

  it "should parse service even with no aliases" do
    src = <<-END
    version: '3.3'
    services:
      nginx:
        image: nginx
        init-containers:
          - dns-init
        networks:
          istiomesh: {}
    END

    result = Stack.parse_compose_file src
    services = result.services
    services.should_not be(nil)
    services.empty?.should be_false
  end

  it "should parse service with simple volume" do
    src = <<-END
    version: '3.3'
    services:
      nginx:
        image: nginx
        volumes:
          - /var/run/from:/var/run/to
    END

    result = Stack.parse_compose_file src
    services = result.services
    services.should_not be(nil)
    services.empty?.should be_false
    services["nginx"].get_cmd(stack_name: "istio").should eq([
      "service", "create",
      "--name", "istio_nginx",
      "--network", "istio_default",
      "--label", "com.docker.stack.namespace=istio",
      "--mount", "type=bind,source=/var/run/from,destination=/var/run/to",
      "nginx",
    ])
  end

  it "should parse service dns and dns_search" do
    src = <<-END
    version: '3.3'
    services:
      nginx:
        image: nginx
        dns:
          - 10.32.88.88
        dns_search:
          - service.consul
    END

    result = Stack.parse_compose_file src
    services = result.services
    services.should_not be(nil)
    services.empty?.should be_false
    services["nginx"].get_cmd(stack_name: "istio").should eq([
      "service", "create",
      "--name", "istio_nginx",
      "--network", "istio_default",
      "--label", "com.docker.stack.namespace=istio",
      "--dns", "10.32.88.88",
      "--dns-search", "service.consul",
      "nginx",
    ])
  end

  it "should parse service with configs" do
    src = <<-END
    version: '3.3'

    configs:
      kubeconfig:
        file: ./test

    services:
      nginx:
        image: nginx
        configs:
          - source: kubeconfig
            target: /etc/kubeconfig
            mode: 0700
    END

    result = Stack.parse_compose_file src
    services = result.services
    services.should_not be(nil)
    services.empty?.should be_false
    services["nginx"].get_cmd(stack_name: "istio",
      ref_configs: result.configs).should eq([
      "service", "create",
      "--name", "istio_nginx",
      "--network", "istio_default",
      "--label", "com.docker.stack.namespace=istio",
      "--config", "source=istio_kubeconfig,target=/etc/kubeconfig,mode=0700",
      "nginx",
    ])
  end
end

it "should parse network with ip address" do
  src = <<-END
  ---
  version: '3.3'
  services:
    apiserver:
      image: gcr.io/google_containers/kube-apiserver-amd64:v1.7.3
      privileged: true
      labels:
        - SERVICE_IGNORE=1
      deploy:
        endpoint_mode: dnsrr
      networks:
        default:
          ipv4_address: 10.32.0.1
          aliases:
            - istio-apiserver
            - apiserver
      command: ["kube-apiserver",
                "--etcd-servers",
                "http://etcd:2379",
                "--service-cluster-ip-range", "10.99.0.0/16",
                "--insecure-port", "8080",
                "-v", "2",
                "--insecure-bind-address", "0.0.0.0"]
  END

  result = Stack.parse_compose_file src
  services = result.services

  services.should_not be(nil)
  services.empty?.should be_false
  services["apiserver"].get_cmd(stack_name: "istio").should eq([
    "service", "create",
    "--name", "istio_apiserver",
    "--network", "istio_default",
    "--endpoint-mode", "dnsrr",
    "--label", "com.docker.stack.namespace=istio",
    "--container-label", "SERVICE_IGNORE=1",
    "--container-label", "io.swarmee.network-aliases.istio_default=istio-apiserver,apiserver",
    "--container-label", "io.swarmee.ipv4.istio_default=10.32.0.1",
    "--container-label", "io.swarmee.privileged=true",
    "gcr.io/google_containers/kube-apiserver-amd64:v1.7.3",
    "kube-apiserver",
    "--etcd-servers",
    "http://etcd:2379",
    "--service-cluster-ip-range", "10.99.0.0/16",
    "--insecure-port", "8080",
    "-v", "2",
    "--insecure-bind-address", "0.0.0.0",
  ])
end

it "should parse volume with ro/rw flag" do
  src = <<-END
  version: '3.3'
  services:
    nginx:
      image: nginx
      volumes:
        - /var/run/from:/var/run/to:ro
        - /var/run/from:/var/run/to:rw
  END

  result = Stack.parse_compose_file src
  services = result.services
  services.should_not be(nil)
  services.empty?.should be_false
  services["nginx"].get_cmd(stack_name: "istio").should eq([
    "service", "create",
    "--name", "istio_nginx",
    "--network", "istio_default",
    "--label", "com.docker.stack.namespace=istio",
    "--mount", "type=bind,source=/var/run/from,destination=/var/run/to,readonly=true",
    "--mount", "type=bind,source=/var/run/from,destination=/var/run/to,readonly=false",
    "nginx",
  ])
end

it "should parse network mode" do
  src = <<-END
  version: '3.3'
  services:
    nginx:
      image: nginx
      network_mode: "service:node"
      volumes:
        - /var/run/from:/var/run/to:ro
        - /var/run/from:/var/run/to:rw
  END

  result = Stack.parse_compose_file src
  services = result.services
  services.should_not be(nil)
  services.empty?.should be_false
  services["nginx"].get_cmd(stack_name: "istio").should eq([
    "service", "create",
    "--name", "istio_nginx",
    "--network", "istio_default",
    "--label", "com.docker.stack.namespace=istio",
    "--container-label", "io.swarmee.network_mode=service:istio_node",
    "--mount", "type=bind,source=/var/run/from,destination=/var/run/to,readonly=true",
    "--mount", "type=bind,source=/var/run/from,destination=/var/run/to,readonly=false",
    "nginx",
  ])
end

it "should parse pid and ipc" do
  src = <<-END
  version: '3.3'
  services:
    nginx:
      image: nginx
      pid: host
      ipc: host
      networks: {}
  END
  result = Stack.parse_compose_file src
  services = result.services
  services.should_not be(nil)
  services.empty?.should be_false
  services["nginx"].get_cmd(stack_name: "istio").should eq([
    "service", "create",
    "--name", "istio_nginx",
    "--label", "com.docker.stack.namespace=istio",
    "--container-label", "io.swarmee.pid=host",
    "--container-label", "io.swarmee.ipc=host",
    "nginx",
  ])
end

it "should parse publish all" do
  src = <<-END
  version: '3.3'
  services:
    nginx:
      image: nginx
      pid: host
      ipc: host
      networks: {}
      publish_all: 1025-1026
  END
  result = Stack.parse_compose_file src
  services = result.services
  services.should_not be(nil)
  services.empty?.should be_false
  services["nginx"].get_cmd(stack_name: "istio").should eq([
    "service", "create",
    "--name", "istio_nginx",
    "--label", "com.docker.stack.namespace=istio",
    "--container-label", "io.swarmee.pid=host",
    "--container-label", "io.swarmee.ipc=host",
    "--publish", "published=1025,target=1025,mode=host",
    "--publish", "published=1026,target=1026,mode=host",
    "nginx",
  ])
end

it "should generate envs as strings correctly" do
  src = <<-END
  ---
  version: '3.3'
  services:
    etcd:
      image: quay.io/coreos/etcd:latest
      deploy:
        endpoint_mode: dnsrr
      environment:
        - E=2
        - SERVICE_IGNORE=1
  END

  result = Stack.parse_compose_file src
  services = result.services

  services.should_not be(nil)
  services.empty?.should be_false
  services["etcd"].get_cmd(stack_name: "istio").should eq([
    "service", "create",
    "--name", "istio_etcd",
    "--network", "istio_default",
    "--endpoint-mode", "dnsrr",
    "--label", "com.docker.stack.namespace=istio",
    "--env", "E=2",
    "--env", "SERVICE_IGNORE=1",
    "quay.io/coreos/etcd:latest",
  ])
end

it "should parse service dns, dns_search, and dns_opt" do
  src = <<-END
  version: '3.3'
  services:
    nginx:
      image: nginx
      dns:
        - 10.32.88.88
      dns_search:
        - service.consul
      dns_opt:
        - 'ndots:1'
  END

  result = Stack.parse_compose_file src
  services = result.services
  services.should_not be(nil)
  services.empty?.should be_false
  services["nginx"].get_cmd(stack_name: "istio").should eq([
    "service", "create",
    "--name", "istio_nginx",
    "--network", "istio_default",
    "--label", "com.docker.stack.namespace=istio",
    "--dns", "10.32.88.88",
    "--dns-search", "service.consul",
    "--dns-option", "ndots:1",
    "nginx",
  ])
end

it "should parse service entrypoint" do
  src = <<-END
  version: '3.3'
  services:
    nginx:
      image: nginx
      dns:
        - 10.32.88.88
      dns_search:
        - service.consul
      dns_opt:
        - 'ndots:1'
      entrypoint: su
      command: ["a","b","c"]
  END

  result = Stack.parse_compose_file src
  services = result.services
  services.should_not be(nil)
  services.empty?.should be_false
  services["nginx"].get_cmd(stack_name: "istio").should eq([
    "service", "create",
    "--name", "istio_nginx",
    "--network", "istio_default",
    "--label", "com.docker.stack.namespace=istio",
    "--dns", "10.32.88.88",
    "--dns-search", "service.consul",
    "--dns-option", "ndots:1",
    "--entrypoint", "su",
    "nginx", "a", "b", "c",
  ])
end
