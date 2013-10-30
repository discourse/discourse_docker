# trap "SIGHUP" do
#   STDERR.puts "Trapped SIGHUP"
#   STDERR.flush
#   exit
# end
# 
# trap "SIGINT" do
#   STDERR.puts "Trapped SIGINT"
#   STDERR.flush
#   exit
# end
# 
# trap "SIGTERM" do
#   STDERR.puts "Trapped SIGTERM"
#   STDERR.flush
#   exit
# end

STDERR.puts "Started #{Process.pid}"
STDERR.puts `ps aux`

while true
  gets
    STDERR.puts "HERE"
    sleep 1
end

STDERR.puts "HERE"

exit

require 'yaml'
require 'open3'
require 'readline'

@host = ARGV[0]

STDERR.puts "Started bootloader for #{@host} at: #{Time.now}"

module Discourse; end

class Discourse::Config
  def initialize(config, discourse_root=nil)
    @config = YAML.load_file(config)
    @discourse_root = discourse_root || "/var/www/discourse"
  end

  def startup
    load_env
    ensure_git_version
    ensure_database_config
    start_roles
  end

  def load_env
    @config["env"].each do |k,v|
      ENV[k.to_s] = v.to_s
    end if @config["env"]
  end

  def ensure_database_config
    current = YAML.load_file("#{@discourse_root}/config/database.yml.production-sample")
    current = current.merge(@config["databases"])
    File.open("#{@discourse_root}/config/database.yml", "w"){|f| f.write current.to_yaml }
  end

  def ensure_git_version
    STDERR.puts `cd #{@discourse_root} && git pull`
  end

  def start_roles
    @config["roles"].each do |role|
      case role
      when "unicorn"
        start_unicorn
      end
    end
  end

  def start_unicorn
    STDERR.puts `cd #{@discourse_root} && RAILS_ENV=production bundle exec rake db:migrate`
  end

end

class Discourse::Process
  def self.pids
    @@pids ||= []
  end

  def self.spawn(*args)
    pid = Process.spawn(*args)
    STDERR.puts "Spawned #{args.inspect} pid: #{pid}"
    pids << pid

    Thread.start do
      Process.wait(pid)
      pids.delete(pid)
    end

    pid
  end

  def spawn(*args)
    self.class.spawn(*args)
  end

  # trap "HUP" do
  #   STDERR.puts "Trapped SIGHUP"
  # end

  # trap "INT" do
  #   STDERR.puts "Trapped SIGINT"
  # end

  # trap "TERM" do
  #   STDERR.puts "Trapped SIGTERM"
  #   pids.dup.each do |pid|
  #     STDERR.puts "Sending TERM to #{pid}"
  #     # no such process
  #     Process.kill("TERM", pid) rescue nil
  #   end

  #   pids.dup.each do |pid|
  #     # no such process
  #     Process.wait(pid) rescue nil
  #   end

  #   STDERR.puts "Exiting"
  #   exit 1
  # end
end

class Discourse::Postgres
  attr_accessor :data_dir
  def start
  end
end

class Discourse::Sshd < Discourse::Process
  def start
    # we need this dir to run sshd
    `mkdir /var/run/sshd` unless File.directory? "/var/run/sshd"
    spawn("/usr/sbin/sshd")
  end
end

# tmp = "/home/sam/Source/discourse_docker/shared/config/web1/conf.yml"
tmp = "/shared/config/web1/conf.yml"
conf = Discourse::Config.new(tmp)
#conf.startup


#Discourse::Sshd.new.start

