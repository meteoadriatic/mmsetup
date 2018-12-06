#!/bin/bash

argument=$1

version="0.1.7"

if [ $# -eq 0 ]
then
    echo "One argument is mandatory. Possible arguments:"
    echo "installdeps [must use sudo] - Installs all dependencies."
    echo "systemcheck - Check system compliance to WRF requirements."
    echo "deploy - Sync system from central repo to localhost."
    exit
fi

if [ "$argument" == "installdeps" ]
then

    if [ "$EUID" -ne 0 ]
    then
        echo "Please run installdeps as root."
        exit
    fi

    echo "||| Installing dependencies |||"
    # Update system
    yum update -y

    # Basic deps
    yum install -y epel-release
    
    yum install -y tree mc nano \
    htop ksh tcsh bc nco perl-Env \
    ncl sendmail wget curl yum-utils \
    rsync mlocate pigz bzip2 \
    util-linux perl-XML-LibXML nginx

    # Development group
    yum -y groupinstall development

    # Python 3
    yum -y install https://centos7.iuscommunity.org/ius-release.rpm
    yum -y install python36u
    yum -y install python36u-pip

    # Python3 modules
    pip3.6 install --upgrade pip
    pip3.6 install pandas matplotlib sqlalchemy pymysql flask gunicorn

    # Upgrade MariaDB
    systemctl stop mariadb
    yum -y remove mariadb mariadb-server

    echo '[mariadb]' | sudo tee /etc/yum.repos.d/mariadb.repo > /dev/null
    echo 'name = MariaDB' | sudo tee --append /etc/yum.repos.d/mariadb.repo > /dev/null
    echo 'baseurl = http://yum.mariadb.org/10.3/centos7-amd64' | sudo tee --append /etc/yum.repos.d/mariadb.repo > /dev/null
    echo 'gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB' | sudo tee --append /etc/yum.repos.d/mariadb.repo > /dev/null
    echo 'gpgcheck=1' | sudo tee --append /etc/yum.repos.d/mariadb.repo > /dev/null

    yum install MariaDB-server MariaDB-client -y

    systemctl start mariadb
    mysql_upgrade
    systemctl stop mariadb

    echo ""
    echo "Dependencies are installed."
    echo "MariaDB is not enabled/started. You can do it manually:"
    echo "sudo systemctl enable mariadb ; sudo systemctl start mariadb"
    echo "Nginx is not enabled/started. You can do it manually:"
    echo "sudo systemctl enable nginx ; sudo systemctl start nginx"
fi


if [ "$argument" == "systemcheck" ]
then
    echo "||| Checking system |||"

    if sestatus -v | grep "SELinux status:" | grep -q 'enabled'; then selinux=EE ; else selinux=OK; fi
    echo "SELinux ... $selinux"
    if systemctl status firewalld | grep "Active:" | grep -q 'running'; then firewall=WW ; else firewall=OK ; fi
    echo "Firewall ... $firewall"


    echo ""
    echo "OK: Checked item is fine"
    echo "EE: Error, item must be corrected by human"
    echo "WW: Warning, item should be checked out by human"
    
    echo "The contents of /etc/hosts file:"
    cat /etc/hosts
fi


if [ "$argument" == "deploy" ]
then

    if [ "$EUID" -eq 0 ]
    then
        echo "Please don't run deploy as root."
        exit
    fi

    echo ""
    echo "!!! WARNING !!!"
    echo "This operation will rewrite all existing files on localhost with central repo versions!"
    echo "This operation should be performed as ARW system user in order to set correct files ownership."
    echo "Central repo username:"
    read repouser
    echo "Central repo full URL - add trailing slash  ( ex. server:/home/user/AY/ ):"
    read repourl
    echo "Central repo ssh port:"
    read port
    echo "Localhost path to write to - add trailing slash  ( ex: '/home/arw/AY/' ):"
    read localpath

    echo ""
    echo "Double check please:"
    echo "Repo user:  $repouser"
    echo "Repo URL:   $repourl"
    echo "Repo port:  $port"
    echo "Local path: $localpath"
    echo ""

    echo "Answer 'YES' in order to proceed with rsync:"
    read confirm

    rsync -rvz -e "ssh -p ${port}" --copy-links ${repouser}@${repourl} ${localpath}

    echo "MeteoAdriatic ARW has been installed into $localpath"

    echo "If this is first install, add next two lines to ~/.bash_profile"
    echo ""
    echo "export ANTEY=$localpath"
    echo 'export PATH=$ANTEY/BIN:/usr/local/bin:$ANTEY/MET:$ANTEY/GRADS/Contents:$NCARG_ROOT/bin:$PATH'
    echo ""
    echo "then reload ~/.bash_profile manually:"
    echo "source ~/.bash_profile"
    echo ""
    echo "and then check for mm command:"
    echo "which mm"

    echo "All done. Have a nice day, admin."
fi
