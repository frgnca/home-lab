#!/bin/bash
# Copyright (c) 2017 Francois Gendron <fg@frgn.ca>
# GNU Affero General Public License v3.0

# removeTemplateUser.sh
# Shell script that removes template user and a call to itself in /etc/rc.local


################################################################################
templateUser="user"
########################
# Remove template user
userdel -r $templateUser

# Remove script call from /etc/rc.local
exit0="exit 0"
scriptCall="/home/user/./removeTemplateUser.sh"
sed -i "s#$scriptCall#$exit0#" /etc/rc.local