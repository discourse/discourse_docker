# simple build file to be used locally by Sam
#
require 'pty'

$version = "1.3.7"

$docker_squash = "https://github.com/goldmann/docker-squash/archive/master.zip"

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
  run ("pip install --user #{$docker_squash}")
end

ensure_docker_squash

def build(path, tag, layers_to_keep = nil)
  lines = run("cd #{path} && docker build .")
  img = lines[-1]["successfully built ".length..-1].strip
  layers_to_squash = run("docker history #{img} | wc -l").first.to_i - (1 + layers_to_keep) if layers_to_keep
  if layers_to_keep != nil
    puts "docker-squash -t #{tag} --verbose -f #{layers_to_squash} #{img}"
    run("docker-squash -t #{tag} --verbose -f #{layers_to_squash} #{img}")
  else
    puts "docker-squash -t #{tag} --verbose #{img}"
    run("docker-squash -t #{tag} --verbose #{img}")
  end
end

run "(cd base && ./download_phantomjs)"

build("base",$base_image)
build("discourse",$image,1)
build("discourse_test",$test,2)
