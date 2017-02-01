# simple build file to be used locally by Sam
#
require 'pty'
require 'optparse'

TODO = [:base, :discourse_test, :discourse_dev]
VERSION = "2.0.#{Time.now.strftime('%Y%m%d')}"

images = {
  base: { name: 'base', tag: "discourse/base:", squash: true },
  discourse_test: { name: 'discourse_test', tag: "discourse/discourse_test:", squash: false},
  discourse_dev: { name: 'discourse_dev', tag: "discourse/discourse_dev:", squash: false }
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
  end

  lines
end

def build(image)
  lines = run("cd #{image[:name]} && docker build . --tag #{image[:tag] + VERSION} #{image[:squash] ? '#--squash' : ''}")
  raise "Error building the image for #{image[:name]}: #{lines[-1]}" if lines[-1] =~ /successfully built/
  run("docker tag #{image[:tag] + VERSION} #{image[:tag]}release")
end

def dev_deps()
  run("sed -e 's/\(db_name: discourse\)/\1_development/' ../templates/postgres.template.yml > discourse_dev/postgres.template.yml")
  run("cp ../templates/redis.template.yml discourse_dev/redis.template.yml")
end

TODO.each do |image|
  puts images[image]

  dev_deps() if image == :discourse_dev
  run "(cd base && ./download_phantomjs)" if image == :base

  build(images[image])
end
