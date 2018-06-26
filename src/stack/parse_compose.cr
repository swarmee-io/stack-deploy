require "yaml"

module Stack
  class Compose
    property services : Hash(String, Service)
    property networks : Hash(String, Network)
    property init_containers : Hash(String, InitContainer)
    property configs : Hash(String, Config)
    property dir : String

    def initialize
      @services = Hash(String, Service).new
      @networks = Hash(String, Network).new
      @init_containers = Hash(String, InitContainer).new
      @configs = Hash(String, Config).new
      @dir = ""
    end
  end

  def self.parse_compose(filename : String) : Compose
    src = ""
    if filename == "-"
      src = String.build(256) do |io|
        IO.copy(STDIN, io)
      end
    else
      src = File.read(filename)
    end
    compose = parse_compose_file(src)

    dir = File.dirname(filename)
    compose.dir = dir

    return compose
  end

  def self.parse_compose_file(src : String) : Compose
    compose_stack = Compose.new

    compose = YAML.parse src

    raise "version is required" if compose.as_h.has_key?("version") == false
    raise "version incorrect" if compose["version"].as_s != "3.3"

    raise "no service defined" if compose.as_h.has_key?("services") == false

    configs = compose["configs"]?
    if configs != nil
      configs = configs.as(YAML::Any)
      configs.each do |name, desc|
        name = name.as_s
        config = parse_config(name, desc)
        if config != nil
          compose_stack.configs[name] = config.as(Config)
        end
      end
    end

    networks = compose["networks"]?
    # if networks is explicit defined
    if networks != nil
      networks = networks.as(YAML::Any)
      networks.each do |net_name, net_desc|
        name = net_name.as_s
        net = parse_network(name, net_desc)
        if net != nil
          compose_stack.networks[name] = net.as(Network)
        end
      end
    else
      # if no network define, define a default one
      compose_stack.networks["default"] = Network.new("default", "default", false)
    end

    init_containers = compose["init-containers"]?
    if init_containers != nil
      init_containers = init_containers.as(YAML::Any)
      init_containers.each do |name, init_con_desc|
        val = parse_init_container(init_con_desc)
        if val != nil
          compose_stack.init_containers[name.as_s] = val.as(InitContainer)
        end
      end
    end

    services = compose["services"]
    services.each do |svc_name, svc_desc|
      name = svc_name.as_s
      svc = parse_service(name, svc_desc)
      if svc != nil
        compose_stack.services[name] = svc.as(Service)
      end
    end

    return compose_stack
  end
end
