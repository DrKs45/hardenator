
# hardenator

Hardenator is a personal project aimed at demonstrating my progress in shell scripting. You are, of course, free to use and modify this script as you wish.


## Usage

Clone the script:

```Shell
git clone https://github.com/DrKs45/hardenator
```

The script requires a few modifications before it can be used:

    - Add IPs to the whitelist (for SSH and other services).
    - Set the domain and email address for Postfix.

## The Script

    Provides a basic configuration for:
    - IPTables
    - Fail2ban
    - rkhunter
    - Postfix
    - Logwatch
    - PortSentry
    - AppArmor
    - SSH 

## V 0.2 (Alpha) 

### New feature : 

IPtables:
    - Externalized Config: Rules are now managed via separate files.
    - Flexibility: Allows for greater flexibility, enabling you to add your own iptables rules without modifying the core script directly.
    - Example File: A template file (iptables_file_example) is included, containing essential rules and common examples.

SSH:
    - Installation: Automated installation of openssh-server.
    - Port Management: Custom SSH port configuration.
    - Hardening: Security settings applied based on ANSSI recommendations (French National Agency for the Security of Information Systems).

Other:
    - Language: Transitioned all code and documentation to English for broader accessibility.
    - Security: Added .gitignore to prevent sensitive local data from being committed.

    
## V 0.3

Summary : 
    - adding new step verification for Logwatch, rkhunter, Postfix and PortSentry
    - ssh_key files and adding .ssh files for 1 user needed  
    - Upgrade Iptables integration 
    - Fix updtate from some mistake... 
 

ssh : add new file for the public keys : now you configure fully the ssh configuration 

IPtables : adding other exemples and fixing some things : 
    - ssh variable 
    - adding #!/bin/bash (oops...) 
    - add smtp port 
    

### Planned updates for next patch (1.0):
    - optimize script
    - interactive menu (for choose for full install or by module)
    - being more prod friendly the script
    - multi ssh key + user creation options 
