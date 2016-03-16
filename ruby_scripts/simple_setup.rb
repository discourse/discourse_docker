require 'fileutils'
require 'yaml'
array_configs = ARGV.join(',').strip.chop
                    .split(',').map(&:strip).reject(&:empty?) # remove trailing comma, strip
config_file = '/ruby_scripts/config.yml'
configs = Hash[*array_configs]
@app_yml = File.read(config_file)
# Instead of just writing config to_yaml with the updates
# find and replace in file to preserve the comments
def write_config(keyword, value)
  matcher = /
    \n\s+       # newline and some spaces
    \#?(\s+)?   # maybe commented out
    #{keyword}  # the keyword
    [^\n]*      # rest of the line
  /x
  @app_yml = @app_yml.gsub(matcher) { |match| "#{match[/\n\s+/]}#{keyword}: #{value.to_s.strip}" }
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

{
  'DISCOURSE_SMTP_ENABLE_START_TLS' => 'true',
  'UNICORN_WORKERS' => unicorns_from_cpus,
  'db_shared_buffers' => pg_memory_for_memory
}.merge(configs).each { |key, value| write_config(key, value) }

File.write(config_file, @app_yml)
puts 'successfully updated configuration'
