# simple build file to be used locally by Sam
#
require 'pty'
require 'optparse'

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
  docker_squash = "https://github.com/goldmann/docker-squash/archive/master.zip"
  run ("pip install --user #{$docker_squash} --upgrade")
end


def build(image, version)
  lines = run("cd #{image[:name]} && docker build --build-arg version=#{version} .")
  img = lines[-1]["successfully built ".length..-1].strip

  if image[:squash]

    layers_to_squash = run("docker history #{img} | wc -l").first.to_i - (1 + image[:layers_to_keep])

    if layers_to_keep != nil
      run("docker-squash -t #{image[:tag]} --verbose -f #{layers_to_squash} #{img}")
    else
      run("docker-squash -t #{image[:tag]} --verbose #{img}")
    end

  else
    run("docker tag #{img} #{image[:tag]}")
  end
end

def bump(image, image_version)
  run("sed -i '' -e 's/^\(# NAME:\).*$$/\1     discourse\/#{image_dir}/' #{image_dir}/Dockerfile")
  run("sed -i '' -e 's/^\(# VERSION:\).*$$/\1  #{image_version}/' #{image_dir}/Dockerfile")
  run("sed -i '' -e 's/^\(FROM discourse\/[^:]*:\).*/\1#{image_version}/' #{image_dir}/Dockerfile")
end

options = {}
OptionParser.new do |parser|
  parser.on("-i", "--image image",
            "Build the image. No parameter means [base discourse discourse_test].") do |i|
    options[:image] = [i]
  end
  parser.on("-b", "--bump version",
            "Bumps the version in the Dockerfiles specified by --image") do |v|
    options[:version] = [v]
  end
end.parse!

DEFAULT_IMAGES = %i[base discourse discourse_test discourse_dev discourse_bench]

todo = options[:image] || DEFAULT_IMAGES
version = options[:version] || '1.3.7'

if ENV["USER"] != "root"
  STDERR.puts "Build script must be ran as root due to docker-squash"
  exit 1
end

ensure_docker_squash

images = {
  base: { name: 'base', tag: "discourse/base:#{version}", squash: true },
  discourse: { name: 'discourse', tag: "discourse/discourse:#{version}", squash: true, layers_to_keep: 1 },
  discourse_test: { name: 'discourse_test', tag: "discourse/discourse_test:#{version}", squash: true, layers_to_keep: 2 },
  discourse_dev: { name: 'discourse_dev', tag: "discourse/discourse_dev:#{version}", squash: false },
  discourse_bench: { name: 'discourse_bench', tag: "discourse/discourse_bench:#{version}", squash: false }
}

todo.each do |image|
  puts images[image]
  bump(images[image][:name], options[:version]) if options[:version]
  run "(cd base && ./download_phantomjs)" if image == 'base'  
  build(images[image], version)
end
