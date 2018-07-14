require "yaml"

module Stack
  class InitContainer
    property image
    property privileged
    property cap_add
    property cap_drop
    property command

    def initialize(image : String,
                   privileged : Bool,
                   cap_add : String,
                   cap_drop : String,
                   command : Array(String) = [] of String)
      @image = image
      @privileged = privileged
      @cap_add = cap_add
      @cap_drop = cap_drop
      @command = command
    end

    def get_cmd
      cap_add = [] of String
      if @cap_add != ""
        cap_add = ["--cap-add", @cap_add]
      end

      cap_drop = [] of String
      if @cap_drop != ""
        cap_drop = ["--cap-drop", @cap_drop]
      end

      privileged = [] of String
      if @privileged
        privileged = ["--privileged"]
      end

      return privileged +
        cap_add +
        cap_drop +
        [image] + @command
    end
  end

  def self.parse_init_container(init_container : YAML::Any)
    image = init_container["image"]?
    return nil if image == nil

    privileged = false
    begin
      privileged = init_container["privileged"].raw.as(Bool)
    rescue KeyError
    end

    cap_add = ""
    begin
      if var = init_container["cap_add"].as_a?
        # var = var.as(Array(YAML::Type))
        cap_add = var.join(",") { |cap| cap.as_s } # (String) }
      end
    rescue KeyError
    end

    cap_drop = ""
    begin
      if var = init_container["cap_drop"].as_a?
        # var = var.as(Array(YAML::Type))
        cap_drop = var.join(",") { |cap| cap.as_s } # (String) }
      end
    rescue KeyError
    end

    command = [] of String
    begin
      if var = init_container["command"].as_s?
        # TODO pass command lines
        command << var # (String)
      elsif var = init_container["command"].as_a?
        var.each do |v|
          command << v.as_s # (String)
        end
      end
    rescue KeyError
    end

    return InitContainer.new(
      image.as(YAML::Any).as_s,
      privileged,
      cap_add,
      cap_drop,
      command,
    )
  end
end
