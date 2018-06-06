require 'fileutils'

puts "-"*100,"creating switch","-"*100

system("cd /var/www/discourse && git pull")

['24', '25'].each do |v|
  bin = "/usr/local/bin/use_#{v}"

File.write(bin, <<RUBY
#!/usr/ruby_24/bin/ruby

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
