#!/bin/bash

set -e

GITHUB_USER="orramsalem" # <-- CHANGE THIS

# Define colors for output
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=== 1. Importing GPG Public Key from GitHub ==="
curl -s "https://github.com/$GITHUB_USER.gpg" | gpg --import

echo "=== 2. Preparing GPG for Remote Forwarding ==="
# Force GPG to securely create its directory structure
gpgconf --create-socketdir

# Kill any local GPG agents that might have started up
gpgconf --kill gpg-agent

# Remove any lingering socket files to ensure a clean binding when you reconnect
rm -f "$(gpgconf --list-dirs agent-socket)"
rm -f "$(gpgconf --list-dirs agent-ssh-socket)"

echo "=== 3. Replacing SSH Agent with GPG Agent ==="
# Determine the remote GPG SSH socket path
GPG_SSH_SOCKET=$(gpgconf --list-dirs agent-ssh-socket)

# Add the environment variable to your .bashrc so it persists across sessions
if ! grep -q "SSH_AUTH_SOCK" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Point SSH to the forwarded GPG Agent" >> ~/.bashrc
    echo "export SSH_AUTH_SOCK=\"$GPG_SSH_SOCKET\"" >> ~/.bashrc
    echo "Successfully updated ~/.bashrc"
else
    echo "SSH_AUTH_SOCK already configured in ~/.bashrc."
fi

echo "=== 4. Configuring SSH Daemon for Socket Cleanup ==="
# Temporarily disable 'set -e' so a sudo failure doesn't crash the whole script
set +e 

# Check if the configuration already exists (using sudo to ensure we can read the file)
if sudo -n grep -q "^StreamLocalBindUnlink yes" /etc/ssh/sshd_config 2>/dev/null || grep -q "^StreamLocalBindUnlink yes" /etc/ssh/sshd_config 2>/dev/null; then
    echo "StreamLocalBindUnlink is already configured in sshd_config."
else
    echo "Attempting to add StreamLocalBindUnlink to /etc/ssh/sshd_config..."
    
    # Try to append the config and restart the daemon. 
    # We check for both 'ssh' and 'sshd' service names to support different Linux distributions.
    if sudo bash -c 'echo "StreamLocalBindUnlink yes" >> /etc/ssh/sshd_config && (systemctl restart ssh || systemctl restart sshd)' 2>/dev/null; then
        echo "Successfully configured and restarted SSH daemon."
    else
        echo -e "${RED}WARNING: This step was unsuccessful. You do not have the required sudo permissions to edit sshd_config and restart the daemon.${NC}"
        echo -e "${RED}Stale sockets will not be automatically cleaned up by this server.${NC}"
    fi
fi

# Re-enable exit on error
set -e

echo "=== Bootstrap Complete! ==="
echo "ACTION REQUIRED: Please log out of this SSH session, and reconnect using your socket forwarding flags."
