# OpenSSH SFTP Server Setup and Administration
A set of scripts to help automate the process of setting up a new OpenSSH SFTP
server, and handle user account administration.

## Fedora OpenSSH v7.x SFTP Server Setup - Manual Procedures
https://www.devsblock.com/?p=71

Make sure the openssh-server package is installed.
```rpm -q openssh-server```

If it isn't already installed, do
```sudo dnf install openssh-server```

Create a special group for the SFTP users
```sudo groupadd --gid 2000 sftpusers```

You'll need to manually create the home directory for the SFTP users.
```sudo mkdir -p /comm/sftp/home```

And the directory that will hold their SSH public keys
```sudo mkdir -p /comm/sftp/keys```


## Adding a New SFTP User Account - Manual Procedures
```sudo useradd -g sftpusers -d /comm/sftp/keys/testuser -s /sbin/nologin testuser```

```sudo useradd -g sftpusers -d /comm/sftp/keys/testuser -s /sbin/nologin testuser```
```sudo mkdir -p /comm/sftp/keys/testuser/.ssh```
```sudo mkdir -p /comm/sftp/home/testuser/inbound```
```sudo mkdir -p /comm/sftp/home/testuser/outbound```

```sudo chown -R testuser:sftpusers /comm/sftp/home/testuser/inbound```
```sudo chown -R testuser:sftpusers /comm/sftp/home/testuser/outbound```
```sudo chown -R testuser:sftpusers /comm/sftp/keys/testuser/.ssh```
```sudo chmod 700 /comm/sftp/keys/testuser/.ssh```
```sudo touch /comm/sftp/keys/testuser/.ssh/authorized_keys```

```sudo chown testuser:sftpusers /comm/sftp/keys/testuser/.ssh/authorized_keys```
```sudo chmod 600 /comm/sftp/keys/testuser/.ssh/authorized_keys```

```passwd suP3r$ecreTP@ssw0rd```