#!/bin/bash

echo "Starting orange instance setup..."

# Create .ssh directory for ubuntu user
mkdir -p /home/ubuntu/.ssh
chown ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh

# Wait for blue to upload its public key and retrieve it
echo "Waiting for blue instance's public key..."
for i in {1..40}; do
    if aws ssm get-parameter \
      --name "/ssh/blue-to-orange/public_key" \
      --region ${AWS_REGION} \
      --query 'Parameter.Value' \
      --output text > /tmp/blue_key.pub 2>/dev/null; then
        
        # Check if this is a valid SSH key
        KEY_CONTENT=$(cat /tmp/blue_key.pub)
        if [[ "$KEY_CONTENT" =~ ^ssh-ed25519[[:space:]]+AAAA[A-Za-z0-9+/] ]] && [[ "$KEY_CONTENT" != "UNINITIALIZED" ]]; then
            echo "Valid SSH key found!"
            echo "Key: $KEY_CONTENT"
            # Clear any existing keys and add the new one
            > /home/ubuntu/.ssh/authorized_keys
            cat /tmp/blue_key.pub >> /home/ubuntu/.ssh/authorized_keys
            rm /tmp/blue_key.pub
            echo "Successfully configured public key from blue instance"
            break
        else
            echo "Parameter contains: '$KEY_CONTENT' - waiting for blue to upload real key..."
        fi
    else
        echo "Failed to retrieve parameter, retrying..."
    fi
    echo "Waiting for valid public key... attempt $i/40"
    sleep 15
done

# Verify we got a key
if [ ! -s /home/ubuntu/.ssh/authorized_keys ]; then
    echo "ERROR: No valid SSH key was retrieved after 40 attempts"
    echo "Current parameter value: $(aws ssm get-parameter --name "/ssh/blue-to-orange/public_key" --region ${AWS_REGION} --query 'Parameter.Value' --output text 2>/dev/null || echo 'FAILED TO RETRIEVE')"
    exit 1
fi

# Set proper permissions for ubuntu
chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys

# Copy authorized_keys to ssm-user (already exists in Ubuntu 24.04)
echo "Setting up authorized_keys for ssm-user..."
mkdir -p /home/ssm-user/.ssh
cp /home/ubuntu/.ssh/authorized_keys /home/ssm-user/.ssh/
chown -R ssm-user:ssm-user /home/ssm-user/.ssh
chmod 700 /home/ssm-user/.ssh
chmod 600 /home/ssm-user/.ssh/authorized_keys
echo "SSH keys set up for ssm-user"

echo "Orange instance setup completed"
