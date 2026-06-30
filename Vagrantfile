# Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  # 3 Manager Nodes
  (1..3).each do |i|
    config.vm.define "manager-#{i}" do |node|
      node.vm.network "private_network", ip: "192.168.56.1#{i}"
      node.vm.hostname = "manager-#{i}"
      node.vm.provider "virtualbox" do |vb|
        vb.memory = 1024
        vb.cpus = 1
      end
      node.vm.provision "shell", inline: <<-SHELL
        curl -fsSL https://get.docker.com | sh
        usermod -aG docker vagrant
      SHELL
    end
  end

  # 2 Worker Nodes
  (1..2).each do |i|
    config.vm.define "worker-#{i}" do |node|
      node.vm.network "private_network", ip: "192.168.56.2#{i}"
      node.vm.hostname = "worker-#{i}"
      node.vm.provider "virtualbox" do |vb|
        vb.memory = 1024
        vb.cpus = 1
      end
      node.vm.provision "shell", inline: <<-SHELL
        curl -fsSL https://get.docker.com | sh
        usermod -aG docker vagrant
      SHELL
    end
  end
end