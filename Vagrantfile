Vagrant.configure(2) do |config|
  config.vm.provider "virtualbox" do |v|
    v.memory = 2048
  end

  config.vm.define :dockerhost do |config|
    config.vm.box = "trusty64"
    config.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"

    config.vm.provision "shell", inline: <<-EOF
      set -e

      export DEBIAN_FRONTEND=noninteractive

      echo "en_US.UTF-8 UTF-8" >/etc/locale.gen
      locale-gen
      echo "Apt::Install-Recommends 'false';" >/etc/apt/apt.conf.d/02no-recommends
      echo "Acquire::Languages { 'none' };" >/etc/apt/apt.conf.d/05no-languages
      apt-get update
      apt-get -y remove --purge puppet juju
      apt-get -y autoremove --purge
      wget -qO- https://get.docker.com/ | sh

      ln -s /vagrant /var/discourse
    EOF

    if ENV["http_proxy"]
      config.vm.provision "shell", inline: <<-EOF
        echo "Acquire::http::Proxy \\"#{ENV['http_proxy']}\\";" >/etc/apt/apt.conf.d/50proxy
        echo "http_proxy=\"#{ENV['http_proxy']}\"" >/etc/profile.d/http_proxy.sh
      EOF
    end
  end
end
