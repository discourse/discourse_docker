# frozen_string_literal: true

module DiscourseSetup
  class ResourceScaler
    MAX_DB_SHARED_BUFFERS_MB = 4096
    MAX_UNICORN_WORKERS = 8

    def initialize(memory_gb:, cpu_cores:, ui:)
      @memory_gb = memory_gb
      @cpu_cores = cpu_cores
      @ui = ui
    end

    def db_shared_buffers
      # 128MB for 1GB, 256MB for 2GB, or 256MB * GB, max 4096MB
      buffers = case @memory_gb
                when 0..1 then 128
                when 2 then 256
                else [@memory_gb * 256, MAX_DB_SHARED_BUFFERS_MB].min
                end

      "#{buffers}MB"
    end

    def unicorn_workers
      # 2 * GB for 2GB or less, or 2 * CPU cores, max 8
      workers = if @memory_gb <= 2
                  2 * @memory_gb
                else
                  2 * @cpu_cores
                end

      [[workers, 1].max, MAX_UNICORN_WORKERS].min
    end

    def apply_scaling(config)
      @ui.info("Found #{@memory_gb}GB of memory and #{@cpu_cores} CPU cores")

      buffers = db_shared_buffers
      workers = unicorn_workers

      @ui.info("Setting db_shared_buffers = #{buffers}")
      @ui.info("Setting UNICORN_WORKERS = #{workers}")

      # Update config hash
      config["params"] ||= {}
      config["params"]["db_shared_buffers"] = buffers

      config["env"] ||= {}
      config["env"]["UNICORN_WORKERS"] = workers

      config
    end
  end
end
