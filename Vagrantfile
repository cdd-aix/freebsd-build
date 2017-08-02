# -*- mode: ruby -*-
# vi: set ft=ruby :

# Look at https://gist.github.com/leifg/4713995 to move to sata with FreeBSD.

Vagrant.configure("2") do |config|
  VAGRANT_ROOT = File.dirname(File.expand_path(__FILE__))
  file_to_disk = File.join(VAGRANT_ROOT, 'poudriere.vdi')
  # From https://groups.google.com/forum/#!topic/vagrant-up/dNnloUOVCI4
  config.vm.guest = :freebsd
  config.ssh.shell = "sh"
  config.vm.base_mac = "080027D14C66"
  config.vm.box = "freebsd/FreeBSD-11.1-RELEASE"
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", "5120"]
    vb.customize ["modifyvm", :id, "--cpus", "4"]
    vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
    vb.customize ["modifyvm", :id, "--audio", "none"]
    vb.customize ["modifyvm", :id, "--nictype1", "virtio"]
    vb.customize ["modifyvm", :id, "--nictype2", "virtio"]
    unless File.exists?(file_to_disk)
      vb.customize ['createhd', '--filename', file_to_disk, '--size', 500 * 1024]
    end
    vb.customize ['storageattach', :id, '--storagectl',
                  'IDE Controller', '--port', 1, '--device', 0,
                  '--type', 'hdd', '--medium', file_to_disk]
  end


  config.vm.network "forwarded_port", guest: 80, host: 8080

  # required for NFS shared folder
  config.vm.network "private_network", type: "dhcp"
  config.vm.network "forwarded_port", guest: 80, host: 8080

  config.vm.synced_folder ".", "/vagrant", id: "vagrant-root", type: "nfs"

  config.vm.provision "shell" do |s|
    s.path = "poudriere.sh"
    s.args = [ "init" ]
  end

  # Consider an always to start builds on start
  # Consider converting above to inline

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
end
