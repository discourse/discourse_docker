require 'fileutils'
require 'yaml'
array_configs = ARGV.join(',').strip.chop
                    .split(',').map(&:strip).reject(&:empty?) # remove trailing comma, strip
config_file = '/ruby_scripts/config.yml'
configs = Hash[*array_configs]
@app_yml = File.read(config_file)

# Matcher to find lines that may or may not be commented out
def config_matcher(keyword)
  /
    \n\s+       # newline and some spaces
    \#?(\s+)?   # maybe commented out
    #{keyword}  # the keyword
    [^\n]*      # rest of the line
  /x
end

# Instead of just writing config to_yaml with the updates
# find and replace in file to preserve the comments
def write_config(keyword, value)
  @app_yml = @app_yml.gsub(config_matcher(keyword)) do |match|
    "#{match[/\n\s+/]}#{keyword}: #{value.to_s.strip}"
  end
end

# Write the passed in values
configs.each { |key, value| write_config(key, value) }

def write_config_if_absent(keyword, value)
  # Get the matching line and parse it if it exists
  line = config_matcher(keyword).match(@app_yml)
  parsed_line = line && YAML.load(line.to_s.strip)
  # Update unless parsed_line is present and has an actual value
  unless parsed_line && parsed_line.values.join.strip != ''
    write_config(keyword, value)
  end
end


def unicorns_from_cpus
  `nproc`.to_i * 2
end

def pg_memory_for_memory
  mem = `awk '/MemTotal/ {print $2}' /proc/meminfo`.to_i
  if mem >= 3500000
    '1GB'
  elsif mem <= 1500000
    '256MB'
  else
    '128MB'
  end
end

# Since these values are set without user input, don't overwrite
# already configured values
{
  'DISCOURSE_SMTP_ENABLE_START_TLS' => 'true',
  'DISCOURSE_SMTP_PORT' => 587,
  'UNICORN_WORKERS' => unicorns_from_cpus,
  'db_shared_buffers' => pg_memory_for_memory
}.each { |key, value| write_config_if_absent(key, value) }

File.write(config_file, @app_yml)
puts 'successfully updated configuration'
