Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"

  config.vm.define "manager1" do |node|
    node.vm.hostname = "swarm-manager-1"
    node.vm.network "private_network", ip: "192.168.56.10"
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end
    node.vm.provision "shell", inline: "apt-get update && apt-get install -y docker.io"
  end

  config.vm.define "manager2" do |node|
    node.vm.hostname = "swarm-manager-2"
    node.vm.network "private_network", ip: "192.168.56.11"
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end
    node.vm.provision "shell", inline: "apt-get update && apt-get install -y docker.io"
  end

  config.vm.define "manager3" do |node|
    node.vm.hostname = "swarm-manager-3"
    node.vm.network "private_network", ip: "192.168.56.12"
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end
    node.vm.provision "shell", inline: "apt-get update && apt-get install -y docker.io"
  end

  config.vm.define "worker1" do |node|
    node.vm.hostname = "swarm-worker-1"
    node.vm.network "private_network", ip: "192.168.56.13"
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end
    node.vm.provision "shell", inline: "apt-get update && apt-get install -y docker.io"
  end

  config.vm.define "worker2" do |node|
    node.vm.hostname = "swarm-worker-2"
    node.vm.network "private_network", ip: "192.168.56.14"
    node.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end
    node.vm.provision "shell", inline: "apt-get update && apt-get install -y docker.io"
  end
end