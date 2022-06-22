### Run in a node, in user node pool

set -euxo pipefail
set +o xtrace

echo "Part 1"
modprobe target_core_user

git clone https://github.com/containerd/overlaybd.git
cd overlaybd
git submodule update --init

wget https://github.com/containerd/overlaybd/releases/download/v0.4.1/overlaybd-0.4.1-1.x86_64.deb

sudo dpkg -i overlaybd-0.4.1-1.x86_64.deb 

echo "Part 2"
cd ..
git clone https://github.com/containerd/accelerated-container-image.git
cd accelerated-container-image

wget https://go.dev/dl/go1.18.3.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.18.3.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
go version

make


sudo mkdir /etc/overlaybd-snapshotter
sudo cat <<-EOF | sudo tee /etc/overlaybd-snapshotter/config.json
{
    "root": "/var/lib/overlaybd/",
    "address": "/run/overlaybd-snapshotter/overlaybd.sock"
}
EOF

sudo cat <<-EOF | sudo tee --append /etc/containerd/config.toml

[proxy_plugins.overlaybd]
    type = "snapshot"
    address = "/run/overlaybd-snapshotter/overlaybd.sock"
EOF

echo "Wrote to /etc/containerd/config.toml"

sudo bin/overlaybd-snapshotter &

sudo systemctl restart containerd
