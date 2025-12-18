#!/bin/bash

#variables
#iptables
## Port SSH a modifie suivant le port voulu  
SSH_PORT=22
#Fail2ban
OS=$(lsb_release -si)
#logwatch + postfix
SERVER_HOSTNAME=$HOSTNAME"@domain.net" 
SERVER_DOMAIN="domain.net"       
ALERT_EMAIL="it_alerts@domain.net"
IP_ADDRESS_OF_SMARTHOST="IP_address_of_smarthost"

# CONFIGURATION
CRON_FILE="/etc/cron.d/logwatch-domain"

# Adresses IP a ignorer
IGNORED_IPS="Ip_address_to_ignore1 Ip_address_to_ignore2..."
JAIL_CONF="/etc/fail2ban/jail.conf"

#mise a jour des paquets
sudo apt update
sudo apt upgrade -y

#iptables installation and configuration
echo "Installation et configuration d'iptables"
sudo apt install -y iptables

echo "installation d'iptables terminee."

###-----------------------------------------------------------------------------------------------
### IPV4 INIT
## Delete all rules
/usr/sbin/iptables  -F
## Delete user chains
/usr/sbin/iptables  -X


###-----------------------------------------------------------------------------------------------

## DNS (needed at the beginning for ipset)
/usr/sbin/iptables  -A OUTPUT -p tcp --dport 53 -j ACCEPT
/usr/sbin/iptables  -A OUTPUT -p udp --dport 53 -j ACCEPT

### INPUT RULES
/usr/sbin/iptables  -A INPUT -i lo -j ACCEPT
/usr/sbin/iptables  -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

## SSH - IP whitelisting
/usr/sbin/iptables  -A INPUT -p tcp --dport $SSH_PORT --source "IP_adresse_interne"  -j ACCEPT

## Pour les test en local, a retirer en prod 
/usr/sbin/iptables  -A INPUT -p tcp --dport $SSH_PORT --source "ip de la vm de test"  -j ACCEPT

##DNS MX 
/usr/sbin/iptables  -A INPUT -p tcp --dport 53 --source 172.16.0.5  -j ACCEPT
/usr/sbin/iptables  -A INPUT -p udp --dport 53 --source 172.16.0.5  -j ACCEPT

## 

## zabbix - PGI
/usr/sbin/iptables  -A INPUT -p tcp --dport 10050 --source 192.168.1.23/24  -j ACCEPT


###-----------------------------------------------------------------------------------------------
### OUTPUT RULES
/usr/sbin/iptables  -A OUTPUT -o lo -j ACCEPT
/usr/sbin/iptables  -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

## NTP
/usr/sbin/iptables  -A OUTPUT -p udp --dport 123 -j ACCEPT

## Linux updates
# 443 ports
/usr/sbin/iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
# 80 ports
/usr/sbin/iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT

###-----------------------------------------------------------------------------------------------
### DROP ALL OTHERS
/usr/sbin/iptables  -P FORWARD DROP
/usr/sbin/iptables  -P INPUT DROP
/usr/sbin/iptables  -P OUTPUT DROP

###-----------------------------------------------------------------------------------------------
### IPV6 INIT
## Delete all rules
/usr/sbin/ip6tables -F
## Delete user chains
/usr/sbin/ip6tables  -X
### Block ALL APV6
/usr/sbin/ip6tables  -P FORWARD DROP
/usr/sbin/ip6tables  -P INPUT DROP
/usr/sbin/ip6tables  -P OUTPUT DROP

echo "Configuration d'iptables terminee."

# rendre les regles persistantes
echo "Installation d'iptables-persistent..."
# Preconfigurer les reponses pour eviter les prompts interactifs
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

# Installation en mode non-interactif
DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent

iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

echo "Regles iptables sauvegardees avec succes."    

# Fail2ban 
apt install -y fail2ban


# Configuration du jail 'sshd' (creation du fichier de configuration specifique)
echo "Configuration du jail 'sshd'..."
sudo bash -c 'cat > /etc/fail2ban/jail.d/defaults-"$OS".conf << EOF
[sshd] 
enabled = true
port = $SSH_PORT
EOF'

# Remplacement de la ligne 'ignoreip' dans jail.conf
# Note : Nous utilisons 'sed' pour remplacer la ligne existante, qu'elle soit commentee ou non.
echo "Mise a jour de la ligne 'ignoreip' dans $JAIL_CONF..."
# Recherche la ligne qui commence par 'ignoreip' (avec ou sans espace/commentaire) et la remplace.
sudo sed -i "/^[[:space:]]*ignoreip/c\ignoreip = $IGNORED_IPS" $JAIL_CONF

# Redemarrage du service Fail2ban
echo "Redemarrage du service Fail2ban pour appliquer les changements..."
sudo systemctl restart fail2ban

echo "--- Configuration de Fail2ban terminee ---"
# Postfix 

# installation de postfix 

echo "1. Preparation de l'environnement"
# Active le mode non-interactif
# export "$OS"_FRONTEND=noninteractive

# Pre-configure les reponses pour Debconf (evite la fenetre d'installation)
echo "postfix postfix/mailname string $SERVER_HOSTNAME" | sudo debconf-set-selections
echo "postfix postfix/main_mailer_type select Internet Site" | sudo debconf-set-selections

echo "2. Installation du paquet postfix"
sudo apt update
sudo apt install -y postfix

# Verification de l'installation
if [ $? -eq 0 ]; then
    echo "Postfix installe avec succes."
else
    echo "ERREUR : L'installation de Postfix a echoue. Arret du script."
    exit 1
fi

echo "--- 3. Configuration des parametres principaux..."

# Definit le nom d'hote de la machine (FQDN)
postconf -e "myhostname = $HOSTNAME"

# Definit le domaine d'origine pour les messages envoyes
postconf -e "mydomain = $SERVER_DOMAIN"
postconf -e "myorigin = /etc/mailname"

# Definit les destinations locales que Postfix doit accepter
# Inclut l'hote lui-meme et le domaine de base
postconf -e "mydestination = $SERVER_HOSTNAME,$HOSTNAME ,$HOSTNAME ,localhost.localdomain, localhost"

# Specifie le serveur de relais (smarthost)
postconf -e "relayhost = $IP_ADDRESS_OF_SMARTHOST"

# Specifie les reseaux de confiance (tres important pour le relais)
# 127.0.0.0/8 est le reseau local
postconf -e "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128"

# Active le support TLS (recommande pour la securite)
postconf -e "smtp_tls_security_level = may"
postconf -e "smtpd_tls_security_level = may"


echo "--- 4. Configuration des alias de securite..."
ALIAS_FILE="/etc/aliases"

# Ajout d'un alias critique pour root et postmaster vers une adresse de surveillance
if ! grep -q "^root:" "$ALIAS_FILE"; then
    echo "root: $ADMIN_EMAIL" | sudo tee -a $ALIAS_FILE > /dev/null
fi
if ! grep -q "^postmaster:" "$ALIAS_FILE"; then
    echo "postmaster: $ADMIN_EMAIL" | sudo tee -a $ALIAS_FILE > /dev/null
fi

# Compiler le fichier d'alias
sudo newaliases

echo "5. Rechargement du service Postfix"
sudo systemctl reload postfix

echo "Configuration Postfix terminee pour $SERVER_HOSTNAME."

# installation de rkhunter 
apt install rkhunter -y

# installation de logwatch 
apt install logwatch -y
mkdir /var/cache/logwatch


# La tache cron :
# instalation de cron si pas encore installe 
if ! command -v cron &> /dev/null
then
    echo "Cron n'est pas installe. Installation en cours..."
    sudo apt install -y cron 
else
    echo "Cron est deja installe. Poursuite de la configuration..."
fi 
# m h dom mon dow   USER    COMMAND
# 0 6 * * * -> A 06:00, tous les jours, en tant que root.
CRON_JOB="0 6 * * * root /usr/sbin/logwatch --mailto $ALERT_EMAIL --output mail"

# EXECUTION

echo "Ajout de la tache cron pour Logwatch a $CRON_FILE..."

# 1. Ajout de la commande au fichier /etc/cron.d/logwatch-pginsight
# La commande 'tee' avec 'sudo' permet d'ecrire dans le fichier en ecrasant l'ancien (idempotence).
echo "$CRON_JOB" | sudo tee $CRON_FILE > /dev/null

# 2. Definir les permissions (requis pour les fichiers /etc/cron.d/)
sudo chmod 0644 $CRON_FILE

echo "Tache cron ajoutee et configuree."
echo "Le rapport Logwatch sera envoye a $ALERT_EMAIL tous les jours a 06:00."

#test d'envoi de logwatch
echo "test si logwatch fonctionne" 
logwatch --mailto $ALERT_EMAIL

#PortSentry

if ! command -v portsentry &> /dev/null
then
    echo "PortSentry n'est pas installe. Installation en cours..."
    sudo apt install -y portsentry || { echo "Erreur installation PortSentry."; exit 1; }
else
    echo "PortSentry est deja installe. Poursuite de la configuration..."
fi

echo "Configuration de $PS_CONF..."

# Modification des options de blocage (BLOCK_UDP="1" et BLOCK_TCP="1")
# Utilise sed pour remplacer la ligne existante
sudo sed -i 's/^BLOCK_UDP="0"/BLOCK_UDP="1"/' "$PS_CONF"
sudo sed -i 's/^BLOCK_TCP="0"/BLOCK_TCP="1"/' "$PS_CONF"

# Configuration de la commande de blocage (KILL_ROUTE pour utiliser iptables)
# On commente la route par defaut et on ajoute la regle iptables
sudo sed -i 's/^KILL_ROUTE="\/sbin\/route add -host \$TARGET\$ reject"/#KILL_ROUTE="\/sbin\/route add -host \$TARGET\$ reject"/' "$PS_CONF"
sudo sed -i '/# Custom Blocking Command here/a KILL_ROUTE="\/sbin\/iptables -I INPUT -s \$TARGET\$ -j DROP"' "$PS_CONF"

# Configuration de la commande d'envoi de mail (KILL_RUN_CMD)
# On remplace la ligne existante (elle est souvent commentee, on s'assure de l'activer)
MAIL_CMD="echo 'Blocage scan de port \$TARGET\$' | mail -s 'scan port ban \$TARGET\$' it_alerts@pginsight.com"
sudo sed -i "/^#?KILL_RUN_CMD/c\KILL_RUN_CMD=\"$MAIL_CMD\"" "$PS_CONF"

# S'assurer que Portsentry demarre en mode avance (atcp/audp)
# Fichier /etc/default/portsentry
sudo sed -i 's/TCP_MODE="tcp"/TCP_MODE="atcp"/' /etc/default/portsentry
sudo sed -i 's/UDP_MODE="udp"/UDP_MODE="audp"/' /etc/default/portsentry

# Redemarrage du service PortSentry
echo "Redemarrage du service PortSentry..."
sudo systemctl restart portsentry

echo "--- Configuration de PortSentry terminee ---"

#apparmor 
sudo apt -y install apparmor apparmor-utils apparmor-profiles apparmor-profiles-extra

# mise en place de apparmor 
echo 'GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT apparmor=1 security=apparmor"' | sudo tee /etc/default/grub.d/apparmor.cfg
update-grub
echo "un redemarrage du serveur sera necessaire pour mettre a jours les regle de securite de apparmor"

# redemarrage du serveur (preferables de le faire manuellement)
echo "redemarrage du serveur dans 10 secondes...(crtl+c pour annuler)"
sleep 10
init 6