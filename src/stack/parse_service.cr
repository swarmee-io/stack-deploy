require "yaml"
require "base64"
require "json"

module Stack
  class Service
    property name
    property image
    property networks
    property network_aliases
    property network_ipv4
    property network_mode
    property pid
    property ipc
    property privileged
    property init_containers
    property endpoint_mode
    property mode
    property container_labels
    property environment
    property publish_all
    property ports
    property cap_drop
    property cap_add
    property read_only
    property volumes
    property dns
    property dns_search
    property dns_opt
    property configs
    property command

    def initialize(name : String,
                   image : String,
                   networks : Hash(String, String),
                   network_aliases : Hash(String, String),
                   network_ipv4 : Hash(String, String),
                   network_mode : String,
                   pid : String,
                   ipc : String,
                   privileged : Bool,
                   init_containers : Array(String) = [] of String,
                   endpoint_mode : String = "vip",
                   mode : String = "replicated",
                   container_labels : Array(String) = [] of String,
                   environment : Array(String) = [] of String,
                   publish_all : String = "false",
                   ports : Array(String) = [] of String,
                   cap_drop : String = "",
                   cap_add : String = "",
                   read_only : Bool = false,
                   volumes : Array(String) = [] of String,
                   dns : Array(String) = [] of String,
                   dns_search : Array(String) = [] of String,
                   dns_opt : Array(String) = [] of String,
                   configs : Array(String) = [] of String,
                   command : Array(String) = [] of String)
      @name = name
      @image = image
      @networks = networks
      @network_aliases = network_aliases
      @network_ipv4 = network_ipv4
      @network_mode = network_mode
      @pid = pid
      @ipc = ipc
      @privileged = privileged
      @init_containers = init_containers
      @endpoint_mode = endpoint_mode
      @mode = mode
      @container_labels = container_labels
      @environment = environment
      @publish_all = publish_all
      @ports = ports
      @cap_drop = cap_drop
      @cap_add = cap_add
      @read_only = read_only
      @volumes = volumes
      @dns = dns
      @dns_search = dns_search
      @dns_opt = dns_opt
      @configs = configs
      @command = command
    end

    def get_cmd(stack_name : String,
                ref_init_containers = {} of String => Stack::InitContainer,
                ref_networks = {} of String => Stack::Network) : Array(String)
      # TODO
      # if network is external, just use name, not stack name
      networks = [] of String
      @networks.each do |name, real_name|
        # puts("name = #{name}")
        # puts("real_name = #{real_name}")
        ref = ref_networks[name]?
        if ref != nil
          ref = ref.as(Stack::Network)
          if ref.is_external
            # if it's external network, use its name directly
            networks = networks + ["--network", "#{real_name}"]
          else
            networks = networks + ["--network", "#{stack_name}_#{real_name}"]
          end
        else
          networks = networks + ["--network", "#{stack_name}_#{real_name}"]
        end
      end

      endpoint_mode = [] of String
      if @endpoint_mode != "" && @endpoint_mode != "vip"
        endpoint_mode = ["--endpoint-mode", @endpoint_mode]
      end

      mode = [] of String
      if @mode != "" && @mode != "replicated"
        mode = ["--mode", @mode]
      end

      container_labels = [] of String
      @container_labels.each do |label|
        container_labels = container_labels + ["--container-label", label]
      end

      @network_aliases.each do |network, aliases|
        container_labels = container_labels + ["--container-label", "io.swarmee.network-aliases.#{stack_name}_#{network}=#{aliases}"]
      end

      @network_ipv4.each do |network, ipv4|
        container_labels = container_labels + ["--container-label", "io.swarmee.ipv4.#{stack_name}_#{network}=#{ipv4}"]
      end

      if @network_mode != ""
        if @network_mode.starts_with?("service")
          container_labels = container_labels + ["--container-label", "io.swarmee.network_mode=#{sprintf(@network_mode, stack_name)}"]
        else
          container_labels = container_labels + ["--container-label", "io.swarmee.network_mode=#{@network_mode}"]
        end
      end

      if @pid != ""
        container_labels = container_labels + ["--container-label", "io.swarmee.pid=#{@pid}"]
      end

      if @ipc != ""
        container_labels = container_labels + ["--container-label", "io.swarmee.ipc=#{@ipc}"]
      end

      if @privileged
        container_labels = container_labels + ["--container-label", "io.swarmee.privileged=true"]
      end

      environment = [] of String
      @environment.each do |env|
        environment = environment + ["--env", env]
      end

      ports = [] of String

      if @publish_all != "false"
        port_spec = @publish_all.split("-", 2)
        from = port_spec[0].to_i
        to = port_spec[1].to_i

        from.upto(to) do |port|
          ports = ports + ["--publish", "published=#{port},target=#{port},mode=host"]
        end
      else
        @ports.each do |port|
          ports = ports + ["--publish", port]
        end
      end

      cap_drop = [] of String
      if @cap_drop != ""
        cap_drop = ["--container-label", "io.swarmee.cap_drop=#{@cap_drop}"]
      end
      cap_add = [] of String
      if @cap_add != ""
        cap_add = ["--container-label", "io.swarmee.cap_add=#{@cap_add}"]
      end

      init_containers = [] of String
      if @init_containers.empty? == false
        @init_containers.each do |name|
          obj = ref_init_containers[name]
          js = obj.get_cmd.to_json
          init_containers += ["--container-label", "io.swarmee.init-container.#{name}=#{Base64.encode(js)}"]
        end
        init_containers += ["--container-label", "io.swarmee.init-containers=#{@init_containers.join(",")}"]
      end

      read_only = [] of String
      if @read_only
        read_only = ["--read-only"]
      end

      volumes = [] of String
      @volumes.each do |volume|
        volumes = volumes + ["--mount", volume]
      end

      dns = [] of String
      @dns.each do |v|
        dns = dns + ["--dns", v]
      end

      dns_search = [] of String
      @dns_search.each do |v|
        dns_search = dns_search + ["--dns-search", v]
      end

      dns_opt = [] of String
      @dns_opt.each do |v|
        dns_opt = dns_opt + ["--dns-opt", v]
      end

      configs = [] of String
      @configs.each do |config|
        configs = configs + ["--config", sprintf(config, stack_name)]
      end

      cmd = ["service", "create"] +
            ["--name", "#{stack_name}_#{@name}"] +
            networks +
            endpoint_mode +
            mode +
            ["--label", "com.docker.stack.namespace=#{stack_name}"] +
            container_labels +
            environment +
            init_containers +
            cap_drop +
            cap_add +
            ports +
            read_only +
            volumes +
            dns +
            dns_search +
            dns_opt +
            configs +
            [image] +
            @command

      return cmd
    end

    def create(stack_name : String,
               ref_init_containers = {} of String => Stack::InitContainer,
               ref_networks = {} of String => Stack::Network)
      Process.run("docker", get_cmd(stack_name, ref_init_containers, ref_networks),
        input: STDIN,
        output: STDOUT,
        error: STDERR)
    end
  end

  def self.parse_service(name : String, service : YAML::Any) : (Service | Nil)
    image = service["image"]?
    return nil if image == nil

    endpoint_mode = "vip"
    begin
      endpoint_mode = service["deploy"]["endpoint_mode"].as_s
    rescue KeyError
    end

    mode = "replicated"
    begin
      mode = service["deploy"]["mode"].as_s
    rescue KeyError
    end

    container_labels = [] of String
    begin
      var = service["labels"].as_a?
      if var != nil
        var = var.as(Array(YAML::Any))
        var.each do |label|
          container_labels << label.as_s # (String)
        end
      else
        var = service["labels"].as_h?
        if var != nil
          var = var.as(Hash(YAML::Any, YAML::Any))
          var.each do |k, v|
            container_labels << "#{k}=#{v}"
          end
        end
      end
    rescue KeyError
    end

    environment = [] of String
    begin
      var = service["environment"].as_a?
      if var != nil
        var = var.as(Array(YAML::Any))
        var.each do |label|
          environment << label.as_s # (String)
        end
      else
        var = service["environment"].as_h?
        if var != nil
          var = var.as(Hash(YAML::Any, YAML::Any))
          var.each do |k, v|
            environment << "#{k}=#{v}"
          end
        end
      end
    rescue KeyError
    end

    networks = Hash(String, String).new
    network_aliases = Hash(String, String).new
    network_ipv4 = Hash(String, String).new

    if service["networks"]? != nil
      var = service["networks"].as_a?
      if var != nil
        var = var.as(Array(YAML::Any))
        var.each do |network|
          networks[network.as_s] = network.as_s # (String)
        end
      else
        var = service["networks"].as_h?
        if var != nil
          var = var.as(Hash(YAML::Any, YAML::Any))
          var.each do |network_name, v|
            network_name = network_name.as_s # (String)
            networks[network_name] = network_name

            v = v.as_h # (Hash(YAML::Any, YAML::Any))
            begin
              aliases = v["aliases"].as_a                                      # (Array(YAML::Any))
              network_aliases[network_name] = aliases.join(',') { |a| a.as_s } # (String) }
            rescue KeyError
            end

            begin
              network_ipv4[network_name] = v["ipv4_address"].as_s # (String)
            rescue KeyError
            end
          end
        end
      end
    else
      networks["default"] = "default"
    end

    network_mode = ""
    begin
      val = service["network_mode"].as_s
      parts = val.split(":", 2)
      if parts[0] == "service"
        network_mode = "service:" + "%s_" + parts[1]
      else
        network_mode = val
      end
    rescue KeyError
    end

    pid = ""
    begin
      pid = service["pid"].as_s
    rescue KeyError
    end

    ipc = ""
    begin
      ipc = service["ipc"].as_s
    rescue KeyError
    end

    privileged = false
    begin
      privileged = service["privileged"].raw.as(Bool)
    rescue KeyError
    end

    init_containers = [] of String
    begin
      if var = service["init-containers"].as_a?
        var = var.as(Array(YAML::Any))
        init_containers = var.map { |c| c.as_s } # (String) }
      end
    rescue KeyError
    end

    publish_all = "false"
    begin
      publish_all = service["publish_all"].as_s
    rescue KeyError
    end

    ports = [] of String
    if service["ports"]? != nil
      var = service["ports"].as_a?
      if var != nil
        var = var.as(Array(YAML::Any))
        var.each do |port|
          if port.as_s?
            ports << port.as_s
          elsif port.as_h?   # is_a?(Hash(YAML::Any, YAML::Any))
            port = port.as_h # (Hash(YAML::Any, YAML::Any))
            ports << port.join(",") { |k, v| "#{k}=#{v}" }
          end
        end
      end
    end

    cap_drop = ""
    begin
      if var = service["cap_drop"].as_a?
        var = var.as(Array(YAML::Any))
        cap_drop = var.join(",") { |cap| cap.as_s } # (String) }
      end
    rescue KeyError
    end

    cap_add = ""
    begin
      if var = service["cap_add"].as_a?
        var = var.as(Array(YAML::Any))
        cap_add = var.join(",") { |cap| cap.as_s } # (String) }
      end
    rescue KeyError
    end

    read_only = false
    begin
      read_only = service["read_only"].raw.as(Bool)
    rescue KeyError
    end

    volumes = [] of String
    if service["volumes"]? != nil
      var = service["volumes"].as_a?
      if var != nil
        var = var.as(Array(YAML::Any))
        var.each do |volume|
          if volume.as_s?
            src_n_dest = volume.as_s.split(":")
            if src_n_dest.size == 2
              volumes << "type=bind,source=#{src_n_dest[0]},destination=#{src_n_dest[1]}"
            elsif src_n_dest.size == 3
              if src_n_dest[2] == "ro"
                volumes << "type=bind,source=#{src_n_dest[0]},destination=#{src_n_dest[1]},readonly=true"
              elsif src_n_dest[2] == "rw"
                volumes << "type=bind,source=#{src_n_dest[0]},destination=#{src_n_dest[1]},readonly=false"
              end
            end
          elsif volume.as_h?
            volume = volume.as_h
            volumes << volume.join(",") { |k, v| "#{k}=#{v}" }
          end
        end
      end
    end

    dns = [] of String
    begin
      if var = service["dns"].as_a?
        var = var.as(Array(YAML::Any))
        dns = var.map { |v| v.as_s } # (String) }
      end
    rescue KeyError
    end

    dns_search = [] of String
    begin
      if var = service["dns_search"].as_a?
        var = var.as(Array(YAML::Any))
        dns_search = var.map { |v| v.as_s } # (String) }
      end
    rescue KeyError
    end

    dns_opt = [] of String
    begin
      if var = service["dns_opt"].as_a?
        var = var.as(Array(YAML::Any))
        dns_opt = var.map { |v| v.as_s }
      end
    rescue KeyError
    end

    configs = [] of String
    if service["configs"]? != nil
      var = service["configs"].as_a?
      if var != nil
        var = var.as(Array(YAML::Any))
        var.each do |config|
          config = config.as_h
          configs << config.join(",") do |k, v|
            if k == "mode"
              "#{k}=#{sprintf("%04o", v.as_i)}"
            elsif k == "source"
              "#{k}=%s_#{v}"
            else
              "#{k}=#{v}"
            end
          end
        end
      end
    end

    command = [] of String
    begin
      if var = service["command"].as_s?
        # TODO pass command lines
        command << var
      elsif var = service["command"].as_a?
        var.each do |v|
          command << v.as_s # (String)
        end
      end
    rescue KeyError
    end

    return Service.new(
      name,
      image.as(YAML::Any).as_s,
      networks,
      network_aliases,
      network_ipv4,
      network_mode,
      pid,
      ipc,
      privileged,
      init_containers,
      endpoint_mode,
      mode,
      container_labels,
      environment,
      publish_all,
      ports,
      cap_drop,
      cap_add,
      read_only,
      volumes,
      dns,
      dns_search,
      dns_opt,
      configs,
      command,
    )
  end
end
