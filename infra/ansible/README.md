# CI Runner Setup with Ansible

This Ansible playbook configures a self-hosted GitHub Actions runner with all the tools needed for the CI/CD pipeline. While the challenge uses GitHub's hosted runners, this playbook demonstrates how you'd set up a dedicated build machine for more control or better performance.

## What Gets Installed

The playbook sets up everything you need for building and deploying:

- **Docker** (with buildx for multi-platform builds)
- **kubectl** (for deploying to Kubernetes)
- **Helm** (for managing releases)
- **Terraform** (for infrastructure changes)
- **gcloud CLI** (for GCP authentication and operations)
- **GitHub Actions Runner** (connects to your repository)

## Running the Playbook

### Option 1: Local Development Machine

Want to run CI jobs on your own machine? Test it in check mode first:

```bash
ansible-playbook -i inventories/hosts.yml playbooks/runner.yml --check
```

### Option 2: GCP VM Instance

For a proper self-hosted runner, create a VM and update the inventory:

```bash
# Create a VM
gcloud compute instances create github-runner \
  --zone=us-central1-a \
  --machine-type=e2-standard-2 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud

# Update inventories/hosts.yml with your VM details
```

Edit `inventories/hosts.yml`:

```yaml
all:
  hosts:
    runner:
      ansible_host: <vm-external-ip>
      ansible_user: <your-username>
      ansible_ssh_private_key_file: ~/.ssh/google_compute_engine
```

Then run the playbook:

```bash
# Set your GitHub repository
export GITHUB_REPOSITORY="your-username/your-repo"
export GITHUB_TOKEN="your-runner-registration-token"

# Run the playbook
ansible-playbook -i inventories/hosts.yml playbooks/runner.yml
```

## Getting a GitHub Runner Token

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Actions** → **Runners**
3. Click **New self-hosted runner**
4. Copy the registration token that appears

The token is valid for 1 hour, so have your playbook ready to run!

## Idempotence

The playbook is fully idempotent - you can run it multiple times safely. It checks if packages are already installed before attempting installation, making it safe to re-run for updates or if something fails partway through.

## Why Self-Hosted Runners?

While GitHub's hosted runners work great (and we use them by default), self-hosted runners give you:

- **Faster builds** - No cold starts, cached dependencies
- **More control** - Custom tools, specific versions
- **Cost savings** - For high-volume CI, especially with expensive build steps
- **Better security** - Keep secrets and builds in your own infrastructure

