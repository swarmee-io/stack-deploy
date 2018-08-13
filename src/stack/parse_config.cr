require "digest"

module Stack
  class Config
    property name
    property file
    property data
    property content_hash
    property real_name
    property external

    def initialize(name : String,
                   file : String,
                   data : String,
                   content_hash : String,
                   real_name : String,
                   external : Bool = false)
      @name = name
      @file = file
      @data = data
      @content_hash = content_hash
      @real_name = real_name
      @external = external
    end

    def get_cmd(stack_name : String)
      return [
        "config", "create",
        "--label", "com.docker.stack.namespace=#{stack_name}",
        "#{stack_name}_#{@name}", @file,
      ]
    end

    def create(dir : String, stack_name : String)
      if @external == true
        return
      end

      if @data != ""
        stdin = IO::Memory.new(@data)
        Process.run("docker", get_cmd(stack_name),
          input: stdin,
          output: STDOUT,
          error: STDERR,
          chdir: dir)
      else
        Process.run("docker", get_cmd(stack_name),
          input: STDIN,
          output: STDOUT,
          error: STDERR,
          chdir: dir)
      end
    end
  end

  def self.parse_config(name : String, config : YAML::Any)
    external = false
    real_name = ""
    begin
      external = config["external"].raw.as(Bool)
      if external
        real_name = config["name"].as_s
      end
    rescue KeyError
    end

    data = ""
    begin
      data = config["data"].as_s
    rescue KeyError
    end

    file = "-"
    if data == ""
      begin
        file = config["file"].as_s
        # content = File.read(file)
      rescue KeyError
      end
    end

    # content_hash = Digest::MD5.hexdigest(content)

    return Config.new(
      name,
      file,
      data,
      "",
      real_name,
      external
    )
  end
end
