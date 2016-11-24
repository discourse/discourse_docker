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

def build(image)
  lines = run("cd #{image[:name]} && docker build .")
  img = lines[-1]["successfully built ".length..-1].strip

  if image[:squash]

    if image[:layers_to_keep] == nil
      run("docker-squash -t #{image[:tag]} --cleanup --verbose #{img}")
    else
      layers_to_squash = run("docker history #{img} | wc -l").first.to_i - (1 + image[:layers_to_keep])
      run("docker-squash -t #{image[:tag]} --cleanup --verbose -f #{layers_to_squash} #{img}")
    end

    run("docker rmi #{img}")

  else
    run("docker tag #{img} #{image[:tag]}")
  end
end

def dev_deps()
  run("sed -e 's/\(db_name: discourse\)/\1_development/' ../templates/postgres.template.yml > discourse_dev/postgres.template.yml")
  run("cp ../templates/redis.template.yml discourse_dev/redis.template.yml")
end

options = {}
OptionParser.new do |parser|
  parser.on("-i", "--image image",
            "Build the image. No parameter means [base discourse discourse_test].") do |i|
    options[:image] = [i.to_sym]
  end
end.parse!

DEFAULT_IMAGES = [:base, :discourse, :discourse_test, :discourse_dev, :discourse_bench]

todo = options[:image] || DEFAULT_IMAGES
version = 'latest'

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

  dev_deps() if image == :discourse_dev
  run "(cd base && ./download_phantomjs)" if image == :base

  build(images[image])
end
