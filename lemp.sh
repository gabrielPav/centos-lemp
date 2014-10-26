#!/bin/bash

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install LEMP"
    exit 1
fi

clear
echo "==========================================================="
echo "LEMP web stack v1.0 for Linux CentOS 6.x, written by GP"
echo "==========================================================="
echo "A tool to auto-compile & install Nginx+MySQL+PHP on Linux "
echo ""
echo "For more information please visit http://makewebfast.net"
echo "==========================================================="

# Dummy Credentials
DOMAIN_NAME=makewebfast
FTP_USERNAME=makewebfast
FTP_GROUP=makewebfast
FTP_USER_PASSWORD=mwfpasswd
MYSQL_ROOT_PASSWORD=mwfpasswd

########################
# Add the necessary repos #
########################

###########################
# Check and update all RPM(S) #
###########################
clear
echo "========================"
echo "Updating CentOS System"
echo "========================"
sudo yum -y update


# Webtatic for PHP 5.4
rpm -Uvh http://mirror.webtatic.com/yum/el6/latest.rpm

##############################
# Add the necessary dependencies #
##############################
sudo yum -y install wget zip unzip


#################################################################################################
# Install NGINX - build it from source with all necessary modules - always check for updates here: http://goo.gl/B5PteX #
#################################################################################################

# Install dependencies
sudo yum -y install openssl openssl-devel gcc-c++ pcre-dev pcre-devel zlib-devel make

# Download ngx_pagespeed
cd
NPS_VERSION=1.9.32.1
wget https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.zip
unzip release-${NPS_VERSION}-beta.zip
cd ngx_pagespeed-release-${NPS_VERSION}-beta/
wget https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz
tar -xzvf ${NPS_VERSION}.tar.gz

# Download and build nginx with all the necessary modules - check http://nginx.org/en/download.html for the latest version
cd
NGINX_VERSION=1.6.2
wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
tar -xvzf nginx-${NGINX_VERSION}.tar.gz
cd nginx-${NGINX_VERSION}/
./configure --add-module=$HOME/ngx_pagespeed-release-${NPS_VERSION}-beta --with-http_gzip_static_module --with-http_realip_module --with-http_ssl_module
make
sudo make install

# Create / replace the Nginx configuration files
mkdir -p /usr/local/nginx/conf

touch /usr/local/nginx/conf/nginx.conf
touch /usr/local/nginx/conf/makewebfast.net.conf
touch /etc/init.d/nginx

wget https://raw.githubusercontent.com/gabrielPav/centos-lemp/master/conf/nginx/nginx.conf -O /usr/local/nginx/conf/nginx.conf
wget https://raw.githubusercontent.com/gabrielPav/centos-lemp/master/conf/nginx/makewebfast.net.conf -O /usr/local/nginx/conf/makewebfast.net.conf
wget https://raw.githubusercontent.com/gabrielPav/centos-lemp/master/conf/nginx/nginx.init.txt -O /etc/init.d/nginx

chmod +x /etc/init.d/nginx
chkconfig nginx on
service nginx start
sudo /etc/init.d/nginx status
sudo /etc/init.d/nginx configtest
sleep 10
service nginx stop

######################################
# install PHP-FPM with latest PHP 5.4 version #
######################################

# Install all necessary PHP modules from Webtatic repo
cd
yum -y install php54w-fpm php54w-common php54w-cli php54w-gd php54w-imap php54w-mysqlnd php54w-odbc php54w-pdo php54w-xml php54w-mbstring php54w-mcrypt php54w-soap php54w-tidy php54w-ldap php54w-process php54w-snmp php54w-devel php54w-pear php54w-pecl-zendopcache php54w-pecl-memcache libmcrypt-devel 

chkconfig php-fpm on

# Change the user/group of PHP-FPM processes
sed -i 's/user = apache/user = nobody/g' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = nobody/g' /etc/php-fpm.d/www.conf

# Change some PHP variables
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 90/g' /etc/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 512M/g' /etc/php.ini
sed -i 's/display_errors = On/display_errors = Off/g' /etc/php.ini

# Set Zend Opcache params
printf "\n[opcache]\nopcache.memory_consumption=512\nopcache.interned_strings_buffer=8\nopcache.max_accelerated_files=16000\nopcache.revalidate_freq=60\nopcache.fast_shutdown=1\nopcache.enable_cli=0\n" >> /etc/php.ini

service php-fpm start
php -v
sleep 10
service php-fpm stop

#################
# install MySQL 5.6 #
#################
cd
wget http://dev.mysql.com/get/mysql-community-release-el6-5.noarch.rpm
yum -y localinstall mysql-community-release-el6-*.noarch.rpm
yum -y install mysql-community-server
chkconfig mysqld on

# Replace / tune the MySQL configuration file
wget https://raw.githubusercontent.com/gabrielPav/centos-lemp/master/conf/mysql/my.cnf -O /etc/my.cnf

service mysqld start
sleep 5

# Secure MySQL installation
yum -y install expect

# Use expect
SECURE_MYSQL=$(expect -c "

set timeout 10
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"$MYSQL\r\"

expect \"Change the root password?\"
send \"y\r\"

expect \"New password:\"
send \"$MYSQL_ROOT_PASSWORD\r\"
 
expect \"Re-enter new password:\"
send \"$MYSQL_ROOT_PASSWORD\r\"

expect \"Remove anonymous users?\"
send \"y\r\"

expect \"Disallow root login remotely?\"
send \"y\r\"

expect \"Reload privilege tables now?\"
send \"y\r\"

expect eof
")

echo "$SECURE_MYSQL"

yum -y remove expect

sleep 5
service mysqld stop


###################
# Install MySQLTuner #
###################
cd
wget --no-check-certificate https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl
chmod +x mysqltuner.pl

###########################
# Install and configure VSFTPD #
###########################

# Install VSFTPD
service iptables stop
service ip6tables stop

yum -y install ftp vsftpd
chkconfig vsftpd on
service vsftpd start

# Configure VSFTPD
sed -i 's/anonymous_enable=YES/anonymous_enable=NO/g' /etc/vsftpd/vsftpd.conf
sed -i 's/local_enable=NO/local_enable=YES/g' /etc/vsftpd/vsftpd.conf
sed -i 's/#chroot_local_user=YES/chroot_local_user=YES/g' /etc/vsftpd/vsftpd.conf

service vsftpd stop
sleep 5
service vsftpd start

service iptables restart
service ip6tables restart


####################
# Create user account #
####################

mkdir -p /home/${DOMAIN_NAME}/public_html

/usr/sbin/groupadd $FTP_GROUP
/usr/sbin/adduser -g $FTP_GROUP -d /home/${DOMAIN_NAME}/public_html $FTP_USERNAME

echo $FTP_USER_PASSWORD | passwd --stdin $FTP_USERNAME

chown -R ${FTP_USERNAME}:${FTP_GROUP} /home/${DOMAIN_NAME}
chmod 775 /home/${DOMAIN_NAME}/public_html

service vsftpd restart

# Limit FTP access only to /public_html directory
usermod --home /home/${DOMAIN_NAME}/public_html $FTP_USERNAME
chown -R ${FTP_USERNAME}:${FTP_GROUP} /home/${DOMAIN_NAME}
chmod 775 /home/${DOMAIN_NAME}/public_html

sleep 5
service vsftpd restart


###################
# Restart key services #
###################
clear
echo "================"
echo  "Start MySQL."
echo "================"
service mysqld start
echo "==============="
echo  "Start Nginx."
echo "==============="
service nginx start
echo "================="
echo  "Start PHP-FPM"
echo "================="
service php-fpm start
sleep 5

# Remove the installation files
rm -rf /root/nginx-1.6.2.tar.gz
rm -rf /root/release-1.9.32.1-beta.zip
rm -rf root/mysql-community-release-el6-5.noarch.rpm

#####################
# Installation completed. #
#####################
clear
echo "========================================"
echo "LNMP Installation Complete!"
echo "========================================"
echo "The configuration is now ready for testing."
echo "========================================"
