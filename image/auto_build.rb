# simple build file to be used locally by Sam
#
require 'pty'
require 'optparse'

images = {
  base: { name: 'base', tag: "discourse/base:build", squash: true },
  base_slim: { name: 'base', tag: "discourse/base:build_slim", squash: true, extra_args: ' --target base-slim ' },
  discourse_test_build: { name: 'discourse_test', tag: "discourse/discourse_test:build", squash: false},
  discourse_test_public: { name: 'discourse_test', tag: "discourse/discourse_test:release", squash: true, extra_args: ' --build-arg tag=release '},
  discourse_dev: { name: 'discourse_dev', tag: "discourse/discourse_dev:build", squash: false },
}

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
    Process.wait(pid)
  end

  raise "'#{command}' exited with status #{$?.exitstatus}" if $?.exitstatus != 0

  lines
end

def build(image)
  lines = run("cd #{image[:name]} && docker build . --no-cache --tag #{image[:tag]} #{image[:squash] ? '--squash' : ''} #{image[:extra_args] ? image[:extra_args] : ''}")
  raise "Error building the image for #{image[:name]}: #{lines[-1]}" if lines[-1] =~ /successfully built/
end

def dev_deps()
  run("sed -e 's/\(db_name: discourse\)/\1_development/' ../templates/postgres.template.yml > discourse_dev/postgres.template.yml")
  run("cp ../templates/redis.template.yml discourse_dev/redis.template.yml")
end

image = ARGV[0].intern
raise 'Image not found' unless images.include?(image)

puts "Building #{images[image]}"
dev_deps() if image == :discourse_dev

build(images[image])
