#!/bin/bash

# variables
# iptables
## SSH Port to modify according to the desired port
SSH_PORT=22
# Fail2ban
OS=$(lsb_release -si)
# logwatch + postfix
SERVER_HOSTNAME=$HOSTNAME"@domain.net" 
SERVER_DOMAIN="domain.net"       
ALERT_EMAIL="it_alerts@domain.net"
IP_ADDRESS_OF_SMARTHOST="IP_address_of_smarthost"

# CONFIGURATION
CRON_FILE="/etc/cron.d/logwatch-domain"

# IP addresses to ignore
IGNORED_IPS="Ip_address_to_ignore1 Ip_address_to_ignore2..."
JAIL_CONF="/etc/fail2ban/jail.conf"

## SSH configuration
apt install -y openssh-server
sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
# Enable PubkeyAuthentication (make sure you have set up SSH keys before disabling password authentication)
sed -i "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sed -i "s/#MaxAuthTries.*/MaxAuthTries 3/" /etc/ssh/sshd_config

systemctl restart sshd

# Update packages
sudo apt update
sudo apt upgrade -y

# iptables installation and configuration
echo "Installing and configuring iptables..."
sudo apt install -y iptables

echo "Iptables installation completed."

# Execute iptables rules from the example file
bash iptables_file_exemple.sh


# Make rules persistent
echo "Installing iptables-persistent..."
# Preconfigure responses to avoid interactive prompts
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

# Installation in non-interactive mode
DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent

iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

echo "Iptables rules saved successfully."    

# Fail2ban 
apt install -y fail2ban


# Configuration of the 'sshd' jail (creation of the specific configuration file)
echo "Configuring 'sshd' jail..."
sudo bash -c 'cat > /etc/fail2ban/jail.d/defaults-"$OS".conf << EOF
[sshd] 
enabled = true
port = $SSH_PORT
EOF'

# Replace 'ignoreip' line in jail.conf
# Note: We use 'sed' to replace the existing line, whether commented or not.
echo "Updating 'ignoreip' line in $JAIL_CONF..."
# Search for the line that starts with 'ignoreip' (with or without space/comment) and replace it.
sudo sed -i "/^[[:space:]]*ignoreip/c\ignoreip = $IGNORED_IPS" $JAIL_CONF

# Restart the Fail2ban service
echo "Restarting Fail2ban service to apply changes..."
sudo systemctl restart fail2ban

echo "--- Fail2ban configuration completed ---"

# Postfix 

# Installation of postfix 

echo "1. Environment preparation"
# Activate non-interactive mode
# export "$OS"_FRONTEND=noninteractive

# Pre-configure responses for Debconf (avoids the installation window)
echo "postfix postfix/mailname string $SERVER_HOSTNAME" | sudo debconf-set-selections
echo "postfix postfix/main_mailer_type select Internet Site" | sudo debconf-set-selections

echo "2. Installing postfix package"
sudo apt update
sudo apt install -y postfix

# Verification of the installation
if [ $? -eq 0 ]; then
    echo "Postfix installed successfully."
else
    echo "ERROR: Postfix installation failed. Script stopped."
    exit 1
fi

echo "--- 3. Configuring main parameters..."

# Define the hostname of the machine (FQDN)
postconf -e "myhostname = $HOSTNAME"

# Define the origin domain for sent messages
postconf -e "mydomain = $SERVER_DOMAIN"
postconf -e "myorigin = /etc/mailname"

# Define the local destinations that Postfix must accept
# Includes the host itself and the base domain
postconf -e "mydestination = $SERVER_HOSTNAME,$HOSTNAME ,$HOSTNAME ,localhost.localdomain, localhost"

# Specify the relay server (smarthost)
postconf -e "relayhost = $IP_ADDRESS_OF_SMARTHOST"

# Define the trusted networks (very important for relaying)
# 127.0.0.0/8 is the local network
postconf -e "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128"

# Activate TLS support (recommended for security)
postconf -e "smtp_tls_security_level = may"
postconf -e "smtpd_tls_security_level = may"


echo "--- 4. Configuring security aliases..."
ALIAS_FILE="/etc/aliases"

# Add a critical alias for root and postmaster to an alerting address
if ! grep -q "^root:" "$ALIAS_FILE"; then
    echo "root: $ALERT_EMAIL" | sudo tee -a $ALIAS_FILE > /dev/null
fi
if ! grep -q "^postmaster:" "$ALIAS_FILE"; then
    echo "postmaster: $ALERT_EMAIL" | sudo tee -a $ALIAS_FILE > /dev/null
fi

# Compile the alias file
sudo newaliases

echo "5. Reloading Postfix service"
sudo systemctl reload postfix

echo "Postfix configuration completed for $SERVER_HOSTNAME."

# Install rkhunter 
apt install rkhunter -y

# Install logwatch 
apt install logwatch -y
mkdir -p /var/cache/logwatch


# The cron task:
# Install cron if not already installed 
if ! command -v cron &> /dev/null
then
    echo "Cron is not installed. Installing..."
    sudo apt install -y cron 
else
    echo "Cron is already installed. Proceeding with configuration..."
fi 
# m h dom mon dow   USER    COMMAND
# 0 6 * * * -> At 06:00, every day, as root.
CRON_JOB="0 6 * * * root /usr/sbin/logwatch --mailto $ALERT_EMAIL --output mail"

# EXECUTION

echo "Adding cron task for Logwatch to $CRON_FILE..."

# 1. Add the command to the cron file
# The 'tee' command with 'sudo' allows writing to the file while overwriting (idempotence).
echo "$CRON_JOB" | sudo tee $CRON_FILE > /dev/null

# 2. Define permissions (required for /etc/cron.d/ files)
sudo chmod 0644 $CRON_FILE

echo "Cron job added and configured."
echo "The Logwatch report will be sent to $ALERT_EMAIL every day at 06:00."

# test if logwatch works
echo "Testing if logwatch works..." 
logwatch --mailto $ALERT_EMAIL

# PortSentry

if ! command -v portsentry &> /dev/null
then
    echo "PortSentry is not installed. Installing..."
    sudo apt install -y portsentry || { echo "PortSentry installation failed."; exit 1; }
else
    echo "PortSentry is already installed. Proceeding with configuration..."
fi

echo "Configuring $PS_CONF..."

# Modify blocking options (BLOCK_UDP="1" and BLOCK_TCP="1")
sudo sed -i 's/^BLOCK_UDP="0"/BLOCK_UDP="1"/' "$PS_CONF"
sudo sed -i 's/^BLOCK_TCP="0"/BLOCK_TCP="1"/' "$PS_CONF"

# Configure the blocking command (KILL_ROUTE to use iptables)
# Commenting out the default route and adding the iptables rule
sudo sed -i 's/^KILL_ROUTE="\/sbin\/route add -host \$TARGET\$ reject"/#KILL_ROUTE="\/sbin\/route add -host \$TARGET\$ reject"/' "$PS_CONF"
sudo sed -i '/# Custom Blocking Command here/a KILL_ROUTE="\/sbin\/iptables -I INPUT -s \$TARGET\$ -j DROP"' "$PS_CONF"

# Configure the mail sending command (KILL_RUN_CMD)
# Replace the existing line and ensure it is activated
MAIL_CMD="echo 'Port scan detected and blocked from \$TARGET\$' | mail -s 'Portscan ban: \$TARGET\$' $ALERT_EMAIL"
sudo sed -i "/^#?KILL_RUN_CMD/c\KILL_RUN_CMD=\"$MAIL_CMD\"" "$PS_CONF"

# Ensure that Portsentry starts in advanced mode (atcp/audp)
# File /etc/default/portsentry
sudo sed -i 's/TCP_MODE="tcp"/TCP_MODE="atcp"/' /etc/default/portsentry
sudo sed -i 's/UDP_MODE="udp"/UDP_MODE="audp"/' /etc/default/portsentry

# Restart the PortSentry service
echo "Restarting PortSentry service..."
sudo systemctl restart portsentry

echo "PortSentry configuration completed."

# apparmor 
sudo apt -y install apparmor apparmor-utils apparmor-profiles apparmor-profiles-extra

# Setup apparmor 
echo 'GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT apparmor=1 security=apparmor"' | sudo tee /etc/default/grub.d/apparmor.cfg
update-grub
echo "A reboot will be necessary to update AppArmor security rules."

# Reboot the server
echo "Rebooting the server in 10 seconds... (Ctrl+C to cancel)"
sleep 10
init 6