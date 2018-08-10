#!/bin/sh
# 
#   setup_sftp_server.sh
# 
#   SYNOPSIS
#       bash setup_sftp_server.sh
# 
#   DESCRIPTION
#       This script will guide you through the process of setting up the
#       localhost as an OpenSSH SFTP server.
# 
#   SUPPORTED DISTRIBUTIONS: 
#       setup_sftp_server.sh has been tested successfully on the following.
#           Fedora 28
#           CentOS 7
#           Debian 9
#           Devuan 2
#

display_greeting() {
    echo "======================================================================"
    echo "Setting up OpenSSH SFTP Server"
    echo "======================================================================"
}

guess_os() {
    osName=""
    osVersion=""
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        osName=$ID
        osVersion=$VERSION_ID
    else
        echo "Unable to determine which OS this is. Exiting"
        exit
    fi
}

verify_sudo() {
    # Verify that the sudo binary is installed an in the execution path.
    echo "Checking for sudo"
    which sudo
    if [ $? -eq 1 ]; then
        echo "sudo is not installed or available for execution!"
        echo "sudo is required. Exiting."
        exit
    fi
    sudo uname -a
    if [ $? -eq 1 ]; then
        echo "You either don't have permission to invoke sudo or don't know your password."
        echo "Exiting."
        exit
    fi
}

verify_openssh_install() {
    if [ $osName == "fedora" ] || [ $osName == "centos" ] || [ $osName == "debian" ] || [ $osName == "devuan" ]; then
        openSshServerPackageName="openssh-server"
    fi
    # Verify the openssh-server package is installed.  Install if required.
    echo "Checking for package: $openSshServerPackageName"
    echo -n "Query Results: "
    if [ $osName == "fedora" ] || [ $osName == "centos" ]; then
        rpm -q $openSshServerPackageName
    fi
    if [ $osName == "debian" ] || [ $osName == "devuan" ]; then
        dpkg -l $openSshServerPackageName
    fi
    # If the query comes back with a return value of 1, prompt the user to
    # see if we should install the openssh package now.
    if [ $? -eq 1 ]; then
        echo "The $openSshServerPackageName package is not installed."
        echo -n "Would you like to install it now? (y/n): "
        read installOpenSshChoice
        if [ $installOpenSshChoice == 'Y' ] || [ $installOpenSshChoice == 'y' ]; then
            if [ $osName == "fedora" ]; then
                sudo dnf install $openSshServerPackageName
            elif [ $osName == "centos" ]; then
                sudo yum install $openSshServerPackageName
            elif [ $osName == "debian" ] || [ $osName == "devuan" ]; then
                sudo apt-get install $openSshServerPackageName
            fi
        else
            echo "The $openSshServerPackageName package is required to proceed."
            echo "Exiting."
            exit 0
        fi
    fi
}

check_for_selinux() {
    selinux="false"
    ## I figure the most reliable way to determine if selinux is something we
    ## need to be concerned about is to check for the config file.
    if [ -f /etc/selinux/config ]; then
        ## Pull in the config variables
        . /etc/selinux/config
        ## If SELINUX=enforcing, then it's a safe bet that we need to be
        ## concerned about selinux.
        if [ $SELINUX == "enforcing" ]; then
            selinux="true"
            ## Now we need to verify we have the chcon and semanage utilities.
            which chcon
            if [ $? -eq 1 ]; then
                echo "----------------------------------------------------------------------"
                echo "The package containing the chcon utility needs to be installed to make" 
                echo "changes to the SELinux policy and allow SFTP user's to use Public Key"
                echo "Authentication."
                echo "----------------------------------------------------------------------"
                echo -n "Install chcon now? (y/n): "
                read installCoreutils
                if [ $installCoreutils == 'y' ] || [ $installCoreutils == 'Y' ]; then
                    ## Install the package that provides chcon
                    if [ $osName == "fedora" ]; then
                        sudo dnf install coreutils
                    elif [ $osName == "centos" ]; then
                        sudo yum install coreutils
                    fi
                fi
            fi
            which semanage
            if [ $? -eq 1 ]; then
                echo "----------------------------------------------------------------------"
                echo "The package containing the semanage utility needs to be installed to"
                echo "make changes to the SELinux policy and allow SFTP user's to use Public"
                echo "Key Authentication."
                echo "----------------------------------------------------------------------"
                echo -n "Install semanage now? (y/n): "
                read installSemanage
                if [ $installSemanage == 'y' ] || [ $installSemanage == 'Y' ]; then
                    ## Install the package that provides semanage
                    if [ $osName == "fedora" ]; then
                        sudo dnf install policycoreutils-python-utils
                    elif [ $osName == "centos" ]; then
                        sudo yum install policycoreutils-python
                    fi
                fi
            fi
        fi
    fi
}

verify_sftp_group() {
    ## Set some default values for the SFTP user group and ID
    defaultSftpUsersGroup="sftpusers"
    defaultSftpUsersGroupId="9000"
    ## Prompt for custom values to use for the SFTP users group and ID
    echo -n "Please supply a group name for your SFTP users. (Default 'sftpusers'): "
    read sftpUsersGroup
    echo -n "Please supply a group ID for your SFTP users. (Default '9000'): "
    read sftpUsersGroupId
    ## If no custom values were offered, use the fallback ones
    if [ -z "$sftpUsersGroup" ]; then
        echo "Using default SFTP users group name ($defaultSftpUsersGroup)"
        sftpUsersGroup=$defaultSftpUsersGroup
    fi
    if [ -z "$sftpUsersGroupId" ]; then
        echo "Using default SFTP users group ID ($defaultSftpUsersGroupId)"
        sftpUsersGroupId=$defaultSftpUsersGroupId
    fi
    ## Check for any existing groups with the same name
    grep --word-regexp --quiet $sftpUsersGroup /etc/group
    if [ $? -eq 0 ]; then
        echo "The SFTP users group $sftpUsersGroup already exists."
        echo -n "Would you like to proceed using this group? (y/n): "
        read useExistingSftpGroupChoice
        ## No special action is required if we are going to move forward using
        ## this existing group.  However, if the user opts to change use a
        ## different group, we should start back at the beginning.
        if [ $useExistingSftpGroupChoice == 'N' ] || [ $useExistingSftpGroupChoice == 'n' ]; then
            verify_sftp_group
        fi
    else
        echo "The group $sftpUsersGroup does not exist."
        grep --word-regexp --quiet $sftpUsersGroupId /etc/group
        if [ $? -eq 1 ]; then
            echo "And the group ID $sftpUsersGroupId is available for use."
            echo -n "Create new group $sftpUsersGroup with ID $sftpUsersGroupId? (y/n): "
            read createNewGroupAndIdChoice
            if [ $createNewGroupAndIdChoice == 'Y' ] || [ $createNewGroupAndIdChoice == 'y' ]; then
                sudo sudo groupadd --gid $sftpUsersGroupId $sftpUsersGroup
            else
                echo "A SFTP user's group is required to proceed."
                echo "Exiting."
                exit 0
            fi
        fi
    fi
}

verify_sftp_home_dir() {
    defaultSftpRootDir="/comm/sftp"
    #sudo mkdir -p /comm/sftp/home
    #sudo mkdir -p /comm/sftp/keys/testuser/.ssh
    echo "Please provide the directory path that should act as the 'root' directory"
    echo "for the SFTP server and will hold the home and keys directories. Example:"
    echo "'/comm/sftp' will house the home directory at '/comm/sftp/home/' and keys"
    echo "directory at '/comm/sftp/keys/'"
    read -p "(default '/comm/sftp'): " sftpRootDir
    ## If no custom values were offered, use the fallback ones
    if [ -z "$sftpRootDir" ]; then
        echo "Using default SFTP server root directory ($defaultSftpRootDir)"
        sftpRootDir=$defaultSftpRootDir
    fi

    if [ ! -d $sftpRootDir/home ]; then
        echo "Creating SFTP home directory at $sftpRootDir/home"
        sudo mkdir -p $sftpRootDir/home
    fi

    if [ ! -d $sftpRootDir/keys ]; then
        echo "Creating SFTP keys directory at $sftpRootDir/keys"
        sudo mkdir -p $sftpRootDir/keys
    fi
}

update_sshd_config() {
    allowPasswordAuthDefault="y"
    allowPublicKeyAuthDefault="y"
    forcePasswordPubKeyDefault="n"
    passwordAuth="yes"
    pubkeyAuth="no"
    echo -n "Allow users to authenticate with a password? (y/n) (Default y): "
    read allowPasswordAuth
    echo -n "Allow users to authenticate with a public key? (y/n) (Default y): "
    read allowPublicKeyAuth
    echo -n "Force users to authenticate with a public key and password? (y/n) (Default n): "
    read forcePasswordPubKey
    ## If no custom values were offered, use the fallback ones
    if [ -z "$allowPasswordAuth" ]; then
        allowPasswordAuth=$allowPasswordAuthDefault
    fi
    if [ -z "$allowPublicKeyAuth" ]; then
        allowPublicKeyAuth=$allowPublicKeyAuthDefault
    fi
    if [ -z "$forcePasswordPubKey" ]; then
        forcePasswordPubKey=$forcePasswordPubKeyDefault
    fi

    if [ $allowPasswordAuth == 'y' ] || [ $allowPasswordAuth == 'Y' ]; then
        passwordAuth="yes"
    elif [ $allowPasswordAuth == 'n' ] || [ $allowPasswordAuth == 'N' ]; then
        passwordAuth="no"
    fi

    if [ $allowPublicKeyAuth == 'y' ] || [ $allowPublicKeyAuth == 'Y' ]; then
        pubkeyAuth="yes"
    elif [ $allowPublicKeyAuth == 'n' ] || [ $allowPublicKeyAuth == 'N' ]; then
        pubkeyAuth="no"
    fi

    sudo sed -i "s|Subsystem|#Subsystem|g" /etc/ssh/sshd_config
    ## Check if a 'Match Group' entry already exists for the SFTP user's group.
    ## If there entry doesn't exist already, we should be safe to create the
    ## configuration.
    sudo grep --line-regexp --quiet "Match Group $sftpUsersGroup" /etc/ssh/sshd_config
    if [ $? -eq 1 ]; then
        if [ $forcePasswordPubKey == 'y' ] || [ $forcePasswordPubKey == 'Y' ]; then
            echo "Appending SFTP configuration to end of OpenSSH Server config."
            sudo tee -a /etc/ssh/sshd_config <<EOT
# Use built in SFTP subsystem
Subsystem sftp internal-sftp
Match Group $sftpUsersGroup
    ChrootDirectory $sftpRootDir/home/%u
    ForceCommand internal-sftp
    PubkeyAuthentication $pubkeyAuth
    PasswordAuthentication $passwordAuth
    AuthenticationMethods publickey,password
    AllowTCPForwarding no
    X11Forwarding no
EOT
        elif [ $forcePasswordPubKey == 'n' ] || [ $forcePasswordPubKey == 'N' ]; then
            echo "Appending SFTP configuration to end of OpenSSH Server config."
            sudo tee -a /etc/ssh/sshd_config <<EOT
# Use built in SFTP subsystem
Subsystem sftp internal-sftp
Match Group $sftpUsersGroup
    ChrootDirectory $sftpRootDir/home/%u
    ForceCommand internal-sftp
    PubkeyAuthentication $pubkeyAuth
    PasswordAuthentication $passwordAuth
    AllowTCPForwarding no
    X11Forwarding no
EOT
        fi
    else
        echo $(sudo grep --line-regexp --line-number "Match Group $sftpUsersGroup" /etc/ssh/sshd_config)
        echo "A configuration matching on group $sftpUsersGroup already exists."
        echo "If you would like to make changes to this configuration, please do so manually."
    fi
}

review_restart_sshd() {
    makeFurtherChangesDefault="n"
    echo "Please review your OpenSSH server configuration file to verify it is sane."
    read -p "Press Enter when ready."
    sudo less /etc/ssh/sshd_config
    echo -n "Would you like to make further changes to your configuration manually? (y/n): "
    read makeFurtherChanges
    if [ -z "$makeFurtherChanges" ]; then
        makeFurtherChanges=$makeFurtherChangesDefault
    fi
    if [ $makeFurtherChanges == 'y' ] || [ $makeFurtherChanges == 'Y' ]; then
        sudo vi /etc/ssh/sshd_config
    fi
    echo "You need to restart the OpenSSH Server process to use the new changes."
    echo -n "Would you like to restart now (y/n): "
    read restartNow
    if [ $restartNow == 'y' ] || [ $restartNow == 'Y' ]; then
        if [ $osName == "fedora" ] || [ $osName == "centos" ] || [ $osName == "debian" ]; then
            sudo systemctl restart sshd
            sudo systemctl status sshd
        elif [ $osName == "devuan" ]; then
            sudo service ssh restart
        fi
        
    fi
}

save_config() {
    sftpServerConfigFilename="/etc/sftp_server.conf"
    sftpServerConfigFilenameTemp="/tmp/sftp4808981234"
    if [ -f $sftpServerConfigFilename ]; then
        echo "WARNING!  /etc/sftp_server.conf already exists!"
        echo "Exiting."
        exit
    fi
    sudo cat <<EOT > $sftpServerConfigFilenameTemp
# This configuration file is used by the addsftpuser script. Please do
# not edit this manually unless you know what you are doing.
sftpRootDir=$sftpRootDir
sftpUsersGroup=$sftpUsersGroup
selinux=$selinux
EOT
    sudo mv $sftpServerConfigFilenameTemp $sftpServerConfigFilename
    echo "Configuration saved to disk at /etc/sftp_server.conf"
}

finish_message() {
    echo "All done.  Bye :)"
    exit
}

main() {
    display_greeting
    guess_os
    verify_sudo
    verify_openssh_install
    check_for_selinux
    verify_sftp_group
    verify_sftp_home_dir
    update_sshd_config
    review_restart_sshd
    save_config
    finish_message
}

# ---------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------
main
