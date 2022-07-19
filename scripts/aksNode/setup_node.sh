### Run in a node, in user node pool

#!/bin/bash

set -euxo pipefail
set +o xtrace

echo "Part 1"
modprobe target_core_user

# Go installation
wget https://go.dev/dl/go1.18.3.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.18.3.linux-amd64.tar.gz
rm go1.18.3.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
go version

# Nerdctl installation
wget https://github.com/containerd/nerdctl/releases/download/v0.20.0/nerdctl-full-0.20.0-linux-amd64.tar.gz
tar -xvf  nerdctl-full-0.20.0-linux-amd64.tar.gz
rm nerdctl-full-0.20.0-linux-amd64.tar.gz

git clone https://github.com/containerd/overlaybd.git
cd overlaybd
git submodule update --init

wget https://github.com/containerd/overlaybd/releases/download/v0.4.1/overlaybd-0.4.1-1.x86_64.deb

sudo dpkg -i overlaybd-0.4.1-1.x86_64.deb 

echo "Part 2"
cd ..
git clone https://github.com/containerd/accelerated-container-image.git
cd accelerated-container-image

make

# echo "alias remove-images=/accelerated-container-image/script/performance/clean-env.sh" >> ~/.bashrc
# source ~/.bashrc

sudo mkdir /etc/overlaybd-snapshotter
sudo cat <<-EOF | sudo tee /etc/overlaybd-snapshotter/config.json
{
    "root": "/var/lib/overlaybd/",
    "address": "/run/overlaybd-snapshotter/overlaybd.sock"
}
EOF

# sudo cat <<-EOF | sudo tee --append /etc/containerd/config.toml

# [proxy_plugins.overlaybd]
#     type = "snapshot"
#     address = "/run/overlaybd-snapshotter/overlaybd.sock"
# EOF

sudo cat <<-EOF | sudo tee /etc/containerd/config.toml
version = 2
oom_score = 0
[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "mcr.microsoft.com/oss/kubernetes/pause:3.6"
  [plugins."io.containerd.grpc.v1.cri".containerd]
    default_runtime_name = "runc"
    snapshotter = "overlaybd"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
      runtime_type = "io.containerd.runc.v2"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
      BinaryName = "/usr/bin/runc"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.untrusted]
      runtime_type = "io.containerd.runc.v2"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.untrusted.options]
      BinaryName = "/usr/bin/runc"
  [plugins."io.containerd.grpc.v1.cri".cni]
    bin_dir = "/opt/cni/bin"
    conf_dir = "/etc/cni/net.d"
    conf_template = "/etc/containerd/kubenet_template.conf"
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
  [plugins."io.containerd.grpc.v1.cri".registry.headers]
    X-Meta-Source-Client = ["azure/aks"]
[metrics]
  address = "0.0.0.0:10257"

[proxy_plugins.overlaybd]
    type = "snapshot"
    address = "/run/overlaybd-snapshotter/overlaybd.sock"
EOF


echo "Wrote to /etc/containerd/config.toml"

tee /etc/systemd/system/overlaybd-snapshotter.service > /dev/null <<EOF
[Unit]
Description=overlaybd snapshotter
After=network.target
Before=containerd.service
[Service]
Type=simple
Environment=HOME=/root
ExecStart=/accelerated-container-image/bin/overlaybd-snapshotter
Restart=always
RestartSec=1
[Install]
WantedBy=multi-user.target
EOF

tee /etc/systemd/system/overlaybd-tcmu.service > /dev/null <<EOF
[Unit]
Description=overlaybd-tcmu service
After=network.target
Before=local-fs-pre.target shutdown.target
DefaultDependencies=no
Conflicts=shutdown.target
[Service]
LimitNOFILE=1048576
LimitCORE=infinity
Type=simple
ExecStartPre=/sbin/modprobe target_core_user
ExecStart=/opt/overlaybd/bin/overlaybd-tcmu
GuessMainPID=no
Restart=always
RestartSec=1s
KillMode=process
OOMScoreAdjust=-999
[Install]
WantedBy=multi-user.target
EOF


#sudo bin/overlaybd-snapshotter &
systemctl enable --now overlaybd-snapshotter overlaybd-tcmu

sudo systemctl restart containerd
