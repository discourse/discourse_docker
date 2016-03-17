require 'fileutils'
require 'yaml'
config_path = 'containers/app.yml'
FileUtils.copy_file('samples/standalone.yml', config_path) unless File.exist?(config_path)
@app_yml = File.read(config_path)

@email_config = {
  'DISCOURSE_SMTP_ADDRESS' => 'SMTP Address',
  'DISCOURSE_SMTP_PORT' => 'SMTP Port',
  'DISCOURSE_SMTP_USER_NAME' => 'SMTP Username',
  'DISCOURSE_SMTP_PASSWORD' => 'SMTP Password'
}

@domain_config = {
  'DISCOURSE_HOSTNAME' => 'The domain name this Discourse instance will respond to, example: discourse.example.org',
  'DISCOURSE_DEVELOPER_EMAILS' => "List of comma delimited emails that will be made admin and developer on initial signup, example: 'user1@example.com,user2@example.com'"
}

def setup_prompter(keyword, description)
  puts description
  while (print "> "; input = gets) do
    input.chomp!
    write_config(keyword, input)
    break
  end
  input
end

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

# Silently configure these options
{
  'DISCOURSE_SMTP_ENABLE_START_TLS' => 'true',
  'UNICORN_WORKERS' => unicorns_from_cpus,
  'db_shared_buffers' => pg_memory_for_memory
}.each { |key, value| write_config(key, value) }

def get_user_configuration(inputs = {})
  puts
  @domain_config.each { |key, value| inputs[key] = setup_prompter(key, value) }

  puts "\nThe next 4 questions are about your email provider. For help, go to https://github.com/discourse/discourse/blob/master/docs/INSTALL-email.md\n"
  @email_config.each { |key, value|  inputs[key] = setup_prompter(key, value) }

  puts "You entered:"
  inputs.each { |key, value| puts "   #{key}:  #{value}" }
end

loop do
  get_user_configuration
  print 'Accept this configuration? (Y/n): '
  input = gets
  break if input.match(/y/i)
end

File.write(config_path, @app_yml) # write the updated config string
begin
  !!YAML.load_file(config_path) # Validate the finished yaml
rescue => e
  puts "\n\nCompleted app.yml file IS INVALID! Setup process aborted"
  puts e.message
end

puts "\nBootstrapping app\nWill take between 2 and 8 minutes to complete"
exec('./launcher bootstrap app && ./launcher start app')