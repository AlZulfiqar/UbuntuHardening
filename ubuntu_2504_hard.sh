#!/bin/bash

# Ubuntu 25.04 Hardening Script (Basic + Recommended)
# Run as root or with sudo: sudo bash ubuntu-harden.sh

set -euo pipefail

echo "=== Updating system..."
apt update && apt full-upgrade -y
apt autoremove -y
apt autoclean -y

echo "=== Enabling UFW Firewall..."
apt install ufw -y
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

echo "=== Installing and configuring Fail2Ban..."
apt install fail2ban -y
systemctl enable --now fail2ban

echo "=== Installing and enabling AppArmor..."
apt install apparmor apparmor-utils -y
systemctl enable --now apparmor

echo "=== Enabling automatic security updates..."
apt install unattended-upgrades -y
dpkg-reconfigure --priority=low unattended-upgrades

echo "=== Securing SSH configuration..."
SSH_CONF="/etc/ssh/sshd_config"

sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' $SSH_CONF
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' $SSH_CONF
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' $SSH_CONF
sed -i 's/^#*UseDNS.*/UseDNS no/' $SSH_CONF

# Optional: restrict SSH to specific user (edit this line)
# echo "AllowUsers yourusername" >> $SSH_CONF

systemctl restart ssh

echo "=== Setting password complexity policy..."
apt install libpam-pwquality -y

PWQUALITY="/etc/pam.d/common-password"
if ! grep -q "pam_pwquality.so" "$PWQUALITY"; then
    echo "password requisite pam_pwquality.s o retry=3 minlen=12 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1" >> "$PWQUALITY"
else
    sed -i 's/^password.*pam_pwquality\.so.*/password requisite pam_pwquality.so retry=3 minlen=12 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1/' "$PWQUALITY"
fi

echo "=== Installing auditd for logging and auditing..."
apt install auditd -y
systemctl enable --now auditd

echo "=== Disabling uncommon services (if installed)..."
for service in avahi-daemon cups bluetooth rpcbind; do
    if systemctl is-enabled "$service" &> /dev/null; then
        systemctl disable --now "$service"
    fi
done

echo "=== Checking for world-writable files (info only)..."
find / -xdev -type f -perm -0002 -print

echo "=== DONE: Basic hardening applied ==="

echo "=== nable some basic sysctl settings ==="

echo "net.ipv4.tcp_syncookies=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.icmp_echo_ignore_broadcasts=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.icmp_ignore_bogus_error_responses=1" | sudo tee -a /etc/sysctl.conf
echo "kernel.randomize_va_space=2" | sudo tee -a /etc/sysctl.conf
echo "fs.suid_dumpable=0" | sudo tee -a /etc/sysctl.conf

# Apply the sysctl changes
sysctl -p
