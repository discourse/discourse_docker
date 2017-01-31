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
  sucess = false
  lines = run("cd #{image[:name]} && docker build . --tag #{image[:tag]} #{image[:squash] ? '--squash' : ''}")
  sucess = true if lines[-1] =~ 'successfully built'
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
version = 'release'

images = {
  base: { name: 'base', tag: "discourse/base:#{version}", squash: true },
  discourse_test: { name: 'discourse_test', tag: "discourse/discourse_test:#{version}", squash: false},
  discourse_dev: { name: 'discourse_dev', tag: "discourse/discourse_dev:#{version}", squash: false }
}

todo.each do |image|
  puts images[image]
  bump(images[image][:name], options[:version]) if options[:version]

  dev_deps() if image == :discourse_dev
  run "(cd base && ./download_phantomjs)" if image == :base

  build(images[image])
end
