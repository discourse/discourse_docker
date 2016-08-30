# simple build file to be used locally by Sam
#
require 'pty'

$version = "1.3.5"

$base_image = "discourse/base:#{$version}"
$image = "discourse/discourse:#{$version}"
$test = "discourse/discourse_test:#{$version}"

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
  run ("apt install python-pip")
  run ("pip install docker_squash --upgrade")
end

ensure_docker_squash

def build(path, tag)
  lines = run("cd #{path} && docker build .")
  img = lines[-1]["successfully built ".length..-1].strip

  run('echo "here it comes!!@!@"')

  run("docker-squash --tag #{tag} --verbose #{img}")
end

run "(cd base && ./download_phantomjs)"

build("base",$base_image)
build("discourse",$image)
build("discourse_test",$test)
