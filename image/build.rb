# simple build file to be used locally by Sam
#
require 'pty'

$version = "1.0.9"

$docker_squash = "https://github.com/jwilder/docker-squash/releases/download/v0.0.11/docker-squash-linux-amd64-v0.0.11.tar.gz"

$base_image = "samsaffron/discourse_base:#{$version}"
$image = "samsaffron/discourse:#{$version}"

if ENV["USER"] != "root"
  STDERR.puts "Build script must be ran as root due to docker-squash"
  exit 1
end

def run(command)
  lines = []
  PTY.spawn(command) do |stdin, stdout, pid|
    begin
      stdin.each do |line|
        lines << line
        puts line
      end
    rescue Errno::EIO
      # we are done
    end
  end

  lines
end

def ensure_docker_squash
  return if File.exist?("docker-squash")
  run ("wget #{$docker_squash}")
  run ("tar -xzvf *.tar.gz")
  run ("rm -f docker-squash-linux*")
end

ensure_docker_squash

def build(path, tag, is_base)
  lines = run("cd #{path} && docker build .")
  img = lines[-1]["successfully built ".length..-1].strip

  run("docker save #{img} | ./docker-squash -t #{tag} -verbose #{is_base && "-from root"} | docker load")
end

build("base",$base_image,true)
build("discourse",$image,false)


