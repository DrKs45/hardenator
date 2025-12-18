
# hardenator

Hardenator is a personal project aimed at demonstrating my progress in shell scripting. You are, of course, free to use and modify this script as you wish.

Linux server hardening script

## Usage
0.1: Get the code

V 0.1
Clone the script:

```Shell
git clone https://github.com/DrKs45/hardenator
```

The script requires a few modifications before it can be used:

    - Add IPs to the whitelist (for SSH and other services).
    - Set the domain and email address for Postfix.

## The Script

    - Provides a basic configuration for:
    - IPTables
    - Fail2ban
    - rkhunter
    - Postfix
    - Logwatch
    - PortSentry
    - AppArmor

## Planned updates for V 0.2:
    - IPTables: Fetch an external configuration file for better flexibility.
    - SSH: Add SSH configuration management.
    - Optimization: General script optimization and making it more autonomous.