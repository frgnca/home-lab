#!/bin/bash
# Copyright (c) 2017-2018 Francois Gendron <fg@frgn.ca>
# MIT License

# setupTemplate.sh
# Shell script that modifies basic Ubuntu Server 16.04.02 template


################################################################################
# Set new configuration
newHostname="test2"
newUser="test"
newIP="192.168.1.32"
########################
# Set internal variables
templateUser="username"
templateHostname="ubuntu"
templateIP="192.168.1.100"

# Create new user
sudo adduser --gecos "" $newUser
sudo usermod -aG sudo $newUser

# Fix apt-get problem from template
sudo rm /var/lib/dpkg/lock > /dev/null 2>&1
sudo dpkg --configure -a > /dev/null 2>&1

# Bring up to date
sudo apt-get update > /dev/null 2>&1
sudo apt-get -y upgrade > /dev/null 2>&1

# Create shell script to remove template user and script call from /etc/rc.local
echo "#!/bin/bash" > removeTemplateUser.sh
echo "# Copyright (c) 2017-2018 Francois Gendron <fg@frgn.ca>" >> removeTemplateUser.sh
echo "# MIT License" >> removeTemplateUser.sh
echo "" >> removeTemplateUser.sh
echo "# removeTemplateUser.sh" >> removeTemplateUser.sh
echo "# Shell script that removes template user and a call to itself in /etc/rc.local" >> removeTemplateUser.sh
echo "" >> removeTemplateUser.sh
echo "" >> removeTemplateUser.sh
echo "################################################################################"	>> removeTemplateUser.sh
echo "templateUser=\"username\"" >> removeTemplateUser.sh
echo "########################" >> removeTemplateUser.sh
echo "# Remove template user" >> removeTemplateUser.sh
echo "userdel -r \$templateUser" >> removeTemplateUser.sh
echo "" >> removeTemplateUser.sh
echo "# Remove script call from /etc/rc.local" >> removeTemplateUser.sh
echo "exit0=\"exit 0\"" >> removeTemplateUser.sh
echo "scriptCall=\"/home/$templateUser/./removeTemplateUser.sh\"" >> removeTemplateUser.sh
echo "sed -i \"s#\$scriptCall#\$exit0#\" /etc/rc.local" >> removeTemplateUser.sh

# Make script executable
chmod +x removeTemplateUser.sh

# Call script from /etc/rc.local on next boot
exit0="exit 0"
scriptCall="/home/$templateUser/./removeTemplateUser.sh"
sudo sed -i "s#$exit0#$scriptCall#" /etc/rc.local

# Change static IP
sudo sed -i "s/$templateIP/$newIP/" /etc/network/interfaces
sudo sed -i "s/$templateIP/$newIP/" /etc/hosts

# Change hostname
sudo sed -i "s/$templateHostname/$newHostname/" /etc/hostname
sudo sed -i "s/$templateHostname/$newHostname/" /etc/hosts

# Shutdown
sudo shutdown now
