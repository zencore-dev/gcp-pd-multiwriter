# OCFS2 on GCP with Multi-Writer Disks

This repository contains code to deploy a two node OCFS2 cluster on Google Cloud using multi-writer persistent disks.

## Usage

To deploy the demo:

Create a new Google Cloud project

Open the Cloud Shell for your project and clone the demo repository:
    
```bash
git clone https://github.com/zencore-dev/gcp-pd-multiwriter.git
```

Change into the terraform code directory:
    
```bash
  cd gcp-pd-multiwriter/terraform
```

Run Terraform:

```bash
terraform init
terraform apply
```

Access each instance via SSH and run the following commands on both:

```bash
# switch to root
sudo -i

# Install the OCFS2 tools and kernel module for the current kernel version:
GCP_KERNEL_VERSION=$(uname -r)
apt install -y ocfs2-tools linux-modules-extra-${GCP_KERNEL_VERSION}
```

Run the following command in the first instance only, to format the filesystem:

```bash
mkfs.ocfs2 -b 4k -C 32K -L "ocfs2" -N 2 /dev/sdb
```

Run the following commands on both instances:

```bash
mkdir /data
dpkg-reconfigure ocfs2-tools
```

Choose Yes to enable OCFS2 at startup. Accept defaults for the other questions.

Edit /etc/ocfs2/cluster.conf on both VMs and configure the node definitions:

```bash
nano /etc/ocfs2/cluster.conf
```

Add the following to the file:

```text
node:
    ip_port = 7777
    ip_address = 10.0.0.2 
    number = 1
    name = nas-1
    cluster = ocfs2

node:
    ip_port = 7777
    ip_address = 10.0.0.3
    number = 2
    name = nas-2
    cluster = ocfs2

cluster:
    node_count = 2
    name = ocfs2
```


Finally, register the cluster and mount the shared disk:

```bash
o2cb register-cluster ocfs2
mount /dev/sdb /data
```

You should have a shared filesystem mounted at /data on both instances.

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.



