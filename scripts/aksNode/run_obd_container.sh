
sudo ctr plugin ls | grep overlaybd

sudo ctr snapshot --snapshotter overlaybd ls

#wget https://github.com/containerd/nerdctl/releases/download/v0.20.0/nerdctl-full-0.20.0-linux-amd64.tar.gz

#tar -xvf  nerdctl-full-0.20.0-linux-amd64.tar.gz
#rm nerdctl-full-0.20.0-linux-amd64.tar.gz 

sudo bin/nerdctl run --net host -it --rm --snapshotter=overlaybd registry.hub.docker.com/overlaybd/redis:6.2.1_obd
