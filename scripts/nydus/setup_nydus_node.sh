wget https://github.com/dragonflyoss/image-service/releases/download/v2.1.0-alpha.4/nydus-static-v2.1.0-alpha.4-linux-amd64.tgz

tar -xvf nydus-static-v2.1.0-alpha.4-linux-amd64.tgz
rm nydus-static-v2.1.0-alpha.4-linux-amd64.tgz

cd nydus-static
mv  nydusd-fusedev  nydusd # what about the other 
cp nydusd nydus-image /usr/local/bin
cp nydusify /usr/local/bin
# sudo cp nydusify containerd-nydus-grpc /usr/local/bin # containerd-nydus-grpc not available in release?
cp ctr-remote nydus-overlayfs /usr/local/bin
cd ..

# Go installation
wget https://go.dev/dl/go1.18.3.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.18.3.linux-amd64.tar.gz
rm go1.18.3.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
go version

wget https://github.com/containerd/nydus-snapshotter/archive/refs/tags/v0.3.0-alpha.4.tar.gz
tar -xvf v0.3.0-alpha.4.tar.gz
rm v0.3.0-alpha.4.tar.gz
cd nydus-snapshotter-0.3.0-alpha.4
make all
cp bin/containerd-nydus-grpc  /usr/local/bin

# Nerdctl installation
cd ..
wget https://github.com/containerd/nerdctl/releases/download/v0.22.0/nerdctl-full-0.22.0-linux-amd64.tar.gz
tar -xvf nerdctl-full-0.22.0-linux-amd64.tar.gz
rm nerdctl-full-0.22.0-linux-amd64.tar.gz

nerdctl login
# Login with credentials

# CNI installation
mkdir -p /opt/cni/bin
curl -LO https://github.com/containernetworking/plugins/releases/download/v1.0.1/cni-plugins-linux-amd64-v1.0.1.tgz
tar -xvzf cni-plugins-linux-amd64-v1.0.1.tgz -C /opt/cni/bin/
rm cni-plugins-linux-amd64-v1.0.1.tgz

sudo tee /etc/nydusd-config.json > /dev/null << EOF
{
  "device": {
    "backend": {
      "type": "registry",
      "config": {
        "scheme": "http",
        "skip_verify": false,
        "timeout": 5,
        "connect_timeout": 5,
        "retry_limit": 2,
        "auth": "YOUR_LOGIN_AUTH="
      }
    },
    "cache": {
      "type": "blobcache",
      "config": {
        "work_dir": "cache"
      }
    }
  },
  "mode": "direct",
  "digest_validate": false,
  "iostats_files": false,
  "enable_xattr": true,
  "fs_prefetch": {
    "enable": true,
    "threads_count": 4
  }
}
EOF

# sudo /usr/local/bin/containerd-nydus-grpc \
#     --config-path /etc/nydusd-config.json \
#     --shared-daemon \
#     --log-level info \
#     --root /var/lib/containerd/io.containerd.snapshotter.v1.nydus \
#     --cache-dir /var/lib/nydus/cache \
#     --address /run/containerd/containerd-nydus-grpc.sock \
#     --nydusd-path /usr/local/bin/nydusd \
#     --nydusimg-path /usr/local/bin/nydus-image \
#     --log-to-stdout &


git clone https://github.com/containerd/nydus-snapshotter
cd nydus-snapshotter
make install

# tee /etc/systemd/system/containerd-nydus-grpc.service > /dev/null <<EOF
# [Unit]
# Description=nydus snapshotter
# After=network.target
# Before=containerd.service
# [Service]
# Type=simple
# Environment=HOME=/root
# ExecStart=/usr/local/bin/containerd-nydus-grpc \
#     --config-path /etc/nydusd-config.json \
#     --shared-daemon \
#     --log-level info \
#     --root /var/lib/containerd/io.containerd.snapshotter.v1.nydus \
#     --cache-dir /var/lib/nydus/cache \
#     --address /run/containerd/containerd-nydus-grpc.sock \
#     --nydusd-path /usr/local/bin/nydusd \
#     --nydusimg-path /usr/local/bin/nydus-image \
#     --log-to-stdout
# Restart=always
# RestartSec=1
# [Install]
# WantedBy=multi-user.target
# EOF

sudo cat <<-EOF | sudo tee /etc/containerd/config.toml
version = 2
oom_score = 0
[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "mcr.microsoft.com/oss/kubernetes/pause:3.6"
  [plugins."io.containerd.grpc.v1.cri".containerd]
    default_runtime_name = "runc"
    snapshotter = "nydus"
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

[proxy_plugins.nydus]
    type = "snapshot"
    address = "/run/containerd-nydus/containerd-nydus-grpc.sock"
EOF

systemctl enable --now containerd-nydus-grpc.service

systemctl restart containerd

