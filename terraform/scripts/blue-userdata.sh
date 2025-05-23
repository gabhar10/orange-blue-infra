#!/bin/bash

echo "Starting blue instance setup..."

# Create .ssh directory for ubuntu user
mkdir -p /home/ubuntu/.ssh
chown ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh

# Generate SSH key
sudo -u ubuntu ssh-keygen -t ed25519 -f /home/ubuntu/.ssh/id_ed25519 -N ""
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_ed25519*
chmod 600 /home/ubuntu/.ssh/id_ed25519
chmod 644 /home/ubuntu/.ssh/id_ed25519.pub

# Create SSH config
echo "Host *" > /home/ubuntu/.ssh/config
echo "    StrictHostKeyChecking no" >> /home/ubuntu/.ssh/config
echo "    UserKnownHostsFile=/dev/null" >> /home/ubuntu/.ssh/config
chown ubuntu:ubuntu /home/ubuntu/.ssh/config
chmod 600 /home/ubuntu/.ssh/config

echo "SSH keys created for ubuntu user"

# Upload public key to Parameter Store
echo "Uploading public key to Parameter Store..."
aws ssm put-parameter \
  --name "/ssh/blue-to-orange/public_key" \
  --value "$(cat /home/ubuntu/.ssh/id_ed25519.pub)" \
  --type "String" \
  --region ${AWS_REGION} \
  --overwrite

# Copy SSH keys to ssm-user (already exists in Ubuntu 24.04)
echo "Setting up SSH keys for ssm-user..."
mkdir -p /home/ssm-user/.ssh
cp /home/ubuntu/.ssh/id_ed25519* /home/ssm-user/.ssh/
cp /home/ubuntu/.ssh/config /home/ssm-user/.ssh/
chown -R ssm-user:ssm-user /home/ssm-user/.ssh
chmod 700 /home/ssm-user/.ssh
chmod 600 /home/ssm-user/.ssh/id_ed25519
chmod 644 /home/ssm-user/.ssh/id_ed25519.pub
chmod 600 /home/ssm-user/.ssh/config
echo "SSH keys copied to ssm-user"

echo "Blue instance setup completed"