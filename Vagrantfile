Vagrant.configure('2') do |config|

    # Use the same centos6.5 box for everyone
    config.vm.box     = "centos65-x86_64-20140116"
    config.vm.box_url = "https://github.com/2creatives/vagrant-centos/releases/download/v6.5.3/centos65-x86_64-20140116.box"
    
    # Everyone gets the common install parts
    config.vm.provision :shell, :path => "./files/install.sh"

    config.vm.hostname = "kafkademo.local.dev"
    config.vm.network :private_network, ip: "192.168.56.71"
    config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "2048"]
    end

end
