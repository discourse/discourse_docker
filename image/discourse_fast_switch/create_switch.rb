require 'fileutils'

puts "-"*100,"creating switch","-"*100

Dir.glob('/usr/ruby_20/*/**').each do |file|
  file = file.gsub('/usr/ruby_20/', '/usr/local/')
  FileUtils.rm(file) if File.exists?(file) && !File.directory?(file)
end

system("cd /var/www/discourse && git pull")

['22', '23'].each do |v|

  bin = "/usr/local/bin/use_#{v}"

File.write(bin, <<RUBY
#!/usr/ruby_22/bin/ruby

Dir.glob('/usr/ruby_#{v}/bin/*').each do |file|
  `rm -f /usr/local/bin/\#{File.basename(file)}`
  `cd /usr/local/bin && ln -s \#{file}`
end

RUBY
)

  system("chmod +x #{bin}")
  system("use_#{v} && gem update --system && gem install bundler --force")
  system("use_#{v} && cd /var/www/discourse && sudo -u discourse bundle install --deployment --without test --without development")
end
