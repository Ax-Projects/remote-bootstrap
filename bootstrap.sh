#!/bin/bash

set -e

GITHUB_USER="orramsalem" # <-- CHANGE THIS

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

echo "=== Bootstrap Complete! ==="
echo "ACTION REQUIRED: Please log out of this SSH session, and reconnect using your socket forwarding flags."
