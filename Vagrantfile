Vagrant.configure(2) do |config|
  config.vm.provider "virtualbox" do |v|
    v.memory = 2048
    v.cpus = 4
  end

  config.vm.define :dockerhost do |config|
    config.vm.box = "ubuntu/xenial64"
    config.disksize.size = '50GB'  # requires vagrant-disksize plugin

    if ENV["http_proxy"]
      config.vm.provision "shell", inline: <<-EOF
        echo "Acquire::http::Proxy \\"#{ENV['http_proxy']}\\";" >/etc/apt/apt.conf.d/50proxy
        echo "http_proxy=\"#{ENV['http_proxy']}\"" >/etc/profile.d/http_proxy.sh
      EOF
    end

    config.vm.provision "shell", inline: <<-EOF
      set -e

      export DEBIAN_FRONTEND=noninteractive

      echo "en_US.UTF-8 UTF-8" >/etc/locale.gen
      locale-gen
      echo "Apt::Install-Recommends 'false';" >/etc/apt/apt.conf.d/02no-recommends
      echo "Acquire::Languages { 'none' };" >/etc/apt/apt.conf.d/05no-languages
      apt-get update
      apt-get install -y ruby postgresql redis-server
      wget -qO- https://get.docker.com/ | sh

      ln -s /vagrant /var/discourse
    EOF
  end
end
