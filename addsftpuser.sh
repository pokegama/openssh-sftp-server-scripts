#!/bin/sh
# 
#   addsftpuser.sh
# 
#   SYNOPSIS
#       bash addsftpuser.sh
# 
#   DESCRIPTION
#       This script will guide you through the process of adding a new SFTP
#       user to the localhost.
# 
#   SUPPORTED DISTRIBUTIONS: 
#       addsftpuser.sh has been tested successfully on the following.
#           Fedora 28
#           CentOS 7
#           Debian 9
#           Devuan 2
#

get_config() {
    sftpServerConfigFilename="/etc/sftp_server.conf"
    if [ -f $sftpServerConfigFilename ]; then
        source $sftpServerConfigFilename
    else
        echo "----------------------------------------------------------------------"
        echo "The configuration file was not found at $sftpServerConfigFilename"
        echo "Did you setup the SFTP server with 'setup_sftp_server.sh'?"
        echo "Exiting."
        echo "----------------------------------------------------------------------"
        exit
    fi
    echo "SFTP Server root directory: $sftpRootDir"
    echo "SFTP user's group: $sftpUsersGroup"
}

verify_new_username() {
    echo "$1"
    if [ -z "$1" ]; then
        echo -n "Please provide a username: "
        read newSftpUsername
    else
        echo -n "Use $1 as the username for this new user? (y/n): "
        read useArg1AsUsername
        if [ $useArg1AsUsername == 'n' ] || [ $useArg1AsUsername == 'N' ]; then
            echo -n "Please provide a username: "
            read newSftpUsername
        else
            newSftpUsername=$1
        fi
    fi
}

create_user() {
    ## Create the new user.
    sudo useradd -g $sftpUsersGroup -d $sftpRootDir/keys/$newSftpUsername -s /sbin/nologin $newSftpUsername
    ## Set the user's password
    sudo passwd $newSftpUsername
}

create_directories() {
    sudo mkdir -p $sftpRootDir/keys/$newSftpUsername/.ssh
    sudo mkdir -p $sftpRootDir/home/$newSftpUsername/to_$newSftpUsername
    sudo mkdir -p $sftpRootDir/home/$newSftpUsername/from_$newSftpUsername
    sudo chown -R $newSftpUsername:$sftpUsersGroup $sftpRootDir/home/$newSftpUsername/to_$newSftpUsername
    sudo chown -R $newSftpUsername:$sftpUsersGroup $sftpRootDir/home/$newSftpUsername/from_$newSftpUsername
    sudo chown -R $newSftpUsername:$sftpUsersGroup $sftpRootDir/keys/$newSftpUsername/.ssh
    sudo chmod 700 $sftpRootDir/keys/$newSftpUsername/.ssh
    sudo touch $sftpRootDir/keys/$newSftpUsername/.ssh/authorized_keys
    sudo chown $newSftpUsername:$sftpUsersGroup $sftpRootDir/keys/$newSftpUsername/.ssh/authorized_keys
    sudo chmod 600 $sftpRootDir/keys/$newSftpUsername/.ssh/authorized_keys
}

change_selinux_context_type() {
    which semanage
    if [ $? -eq 1 ]; then
        echo "----------------------------------------------------------------------"
        echo "The semanage utility is required to change the SELinux context type of"
        echo "$sftpRootDir/keys/$newSftpUsername/.ssh"
        echo "but this utility is not installed."
        echo "----------------------------------------------------------------------"
        exit
    else
        sudo chcon -R -t ssh_home_t $sftpRootDir/keys/$newSftpUsername/.ssh
        sudo semanage fcontext -a -t ssh_home_t "$sftpRootDir/keys/$newSftpUsername/.ssh(/.*)?"
    fi
}

main() {
    get_config
    verify_new_username
    create_user
    create_directories
    if [ $selinux == "true" ]; then
        change_selinux_context_type
    fi
}

# ---------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------
main