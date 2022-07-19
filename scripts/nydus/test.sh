sudo nerdctl run -d --restart=always -p 5000:5000 registry
sudo nydusify convert --nydus-image /usr/local/bin/nydus-image --source ubuntu --target localhost:5000/ubuntu-nydus
sudo nerdctl --snapshotter nydus run --rm -it localhost:5000/ubuntu-nydus:latest bash
