curl -LO https://github.com/containerd/stargz-snapshotter/releases/download/v0.12.0/stargz-snapshotter-v0.12.0-linux-amd64.tar.gz
tar -C /usr/local/bin -xvf stargz-snapshotter-v0.12.0-linux-amd64.tar.gz containerd-stargz-grpc ctr-remote 
wget -O /etc/systemd/system/stargz-snapshotter.service https://raw.githubusercontent.com/containerd/stargz-snapshotter/main/script/config/etc/systemd/system/stargz-snapshotter.service

mkdir /etc/containerd-stargz-grpc
touch /etc/containerd-stargz-grpc/config.toml # Needed by stargz systemd service

# Nerdctl installation
wget https://github.com/containerd/nerdctl/releases/download/v0.20.0/nerdctl-full-0.20.0-linux-amd64.tar.gz
tar -xvf  nerdctl-full-0.20.0-linux-amd64.tar.gz
rm nerdctl-full-0.20.0-linux-amd64.tar.gz

# CNI installation
mkdir -p /opt/cni/bin
curl -LO  https://github.com/containernetworking/plugins/releases/download/v1.0.1/cni-plugins-linux-amd64-v1.0.1.tgz
tar -xvzf cni-plugins-linux-amd64-v1.0.1.tgz -C /opt/cni/bin/
rm cni-plugins-linux-amd64-v1.0.1.tgz

sudo cat <<-EOF | sudo tee /etc/containerd/config.toml
version = 2
oom_score = 0
[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "mcr.microsoft.com/oss/kubernetes/pause:3.6"
  [plugins."io.containerd.grpc.v1.cri".containerd]
    default_runtime_name = "runc"
    snapshotter = "stargz"
    disable_snapshot_annotations = false
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

[proxy_plugins]
  [proxy_plugins.stargz]
    type = "snapshot"
    address = "/run/containerd-stargz-grpc/containerd-stargz-grpc.sock"
EOF

systemctl enable --now stargz-snapshotter
systemctl restart containerd


#####
time nerdctl --snapshotter=stargz run --rm ghcr.io/stargz-containers/python:3.7-esgz python3 -c 'print("hello lazy-pulling")'

time nerdctl --snapshotter=overlayfs run -it --rm ghcr.io/stargz-containers/python:3.7-org python3 -c 'print("hi")'