require "yaml"

module Stack
  class Network
    property name : String
    property real_name : String
    property is_default : Bool
    property is_external : Bool
    property driver : String
    property attachable : Bool
    property ipam_driver : String
    property sub_nets : Array(String)
    property ip_ranges : Array(String)

    def initialize(name : String,
                   real_name : String,
                   is_external : Bool,
                   driver : String = "overlay",
                   attachable : Bool = false,
                   ipam_driver : String = "default",
                   sub_nets : Array(String) = [] of String,
                   ip_ranges : Array(String) = [] of String)
      @name = name
      @real_name = real_name
      @is_default = if name == "default"
                      true
                    else
                      false
                    end
      @is_external = is_external
      @driver = driver
      @attachable = attachable
      @ipam_driver = ipam_driver
      @sub_nets = sub_nets
      @ip_ranges = ip_ranges
    end

    def get_cmd(stack_name : String) : Array(String)
      attachable = [] of String
      if @attachable
        attachable = ["--attachable"]
      end

      ipam_driver = [] of String
      if @ipam_driver != "" && @ipam_driver != "default"
        ipam_driver = ["--ipam-driver", @ipam_driver]
      end

      sub_nets = [] of String
      @sub_nets.each do |s|
        sub_nets += ["--subnet", s]
      end

      ip_ranges = [] of String
      @ip_ranges.each do |s|
        ip_ranges += ["--ip-range", s]
      end

      cmd = ["network", "create"] +
            ["-d", driver] +
            attachable +
            ipam_driver +
            sub_nets +
            ip_ranges +
            ["--label", "com.docker.stack.namespace=#{stack_name}"] +
            ["#{stack_name}_#{@real_name}"]

      return cmd
    end

    def create(stack_name : String)
      if @is_external == false
        Process.run("docker", get_cmd(stack_name),
          input: STDIN,
          output: STDOUT,
          error: STDERR)
      end
    end

    def pre_check(stack_name : String) : Bool
      return true
      # check by inspect the network
      # docker network ls -q -f label=com.docker.stack.namespace=nginx -f name=nginx_default

      # if it's not an external
      # if @is_external == false
      #  status = Process.run("docker", [
      #  	"network", "ls",
      #  	"-q", "-f", "label=com.docker.stack.namespace=nginx"
      #  	"#{stack_name}_#{@real_name}"])
      #  # the network must not be found to be OK
      #  # parse json, check stack name to be correct
      #  return status.success
      # else
      #  # if it's external, the network must be found
      #  return status.success?
      # end
    end
  end

  def self.parse_network(name : String, network : YAML::Any) : (Network | Nil)
    external = false
    begin
      external = network["external"].raw.as(Bool)
    rescue KeyError
    end

    driver = "overlay"
    begin
      driver = network["driver"].as_s
    rescue KeyError
    end

    attachable = false
    begin
      attachable = network["attachable"].raw.as(Bool)
    rescue KeyError
    end

    real_name = name
    begin
      real_name = network["name"].as_s
    rescue KeyError
    end

    ipam_driver = "default"
    begin
      ipam_driver = network["ipam"]["driver"].as_s
    rescue KeyError
    end

    sub_nets = [] of String
    begin
      configs = network["ipam"]["config"].as_a
      configs.each do |config|
        # config = config.as(Hash(YAML::Type, YAML::Type))
        if config["subnet"]?
          sub_nets << config["subnet"].as_s # (String)
        end
      end
    rescue KeyError
    end

    ip_ranges = [] of String
    begin
      configs = network["ipam"]["config"].as_a
      configs.each do |config|
        # config = config.as(Hash(YAML::Type, YAML::Type))
        # if arr = config["ip_ranges"].as?(Array(YAML::Type))
        arr = config["ip_ranges"].as_a
        arr.each do |ip_range|
          ip_ranges << ip_range.as_s # (String)
        end
        # end
      end
    rescue KeyError
    end

    return Network.new(
      name,
      real_name,
      external,
      driver,
      attachable,
      ipam_driver,
      sub_nets,
      ip_ranges)
  end
end
