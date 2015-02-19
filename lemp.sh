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


# Webtatic for PHP 5.5
rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm

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
NPS_VERSION=1.9.32.3
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
# install PHP-FPM with latest PHP 5.5 version #
######################################

# Install all necessary PHP modules from Webtatic repo
cd
yum -y install php55w-fpm php55w-common php55w-cli php55w-gd php55w-imap php55w-mysqlnd php55w-odbc php55w-pdo php55w-xml php55w-mbstring php55w-mcrypt php55w-soap php55w-tidy php55w-ldap php55w-process php55w-snmp php55w-devel php55w-pear php55w-pecl-memcache libmcrypt-devel 

chkconfig php-fpm on

# Change the user/group of PHP-FPM processes
sed -i 's/user = apache/user = makewebfast/g' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = makewebfast/g' /etc/php-fpm.d/www.conf

# Change some PHP variables
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 90/g' /etc/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/g' /etc/php.ini
sed -i 's/display_errors = On/display_errors = Off/g' /etc/php.ini
sed -i 's/;session.save_path = "\/tmp"/session.save_path = "\/var\/lib\/php\/session"/g' /etc/php.ini

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

mkdir -p /var/www/html

/usr/sbin/groupadd $FTP_GROUP
/usr/sbin/adduser -g $FTP_GROUP -d /var/www/html $FTP_USERNAME

echo $FTP_USER_PASSWORD | passwd --stdin $FTP_USERNAME

chown -R ${FTP_USERNAME}:${FTP_GROUP} /var/www
chmod 775 /var/www/html

service vsftpd restart

# Limit FTP access only to /public_html directory
usermod --home /var/www/html $FTP_USERNAME
chown -R ${FTP_USERNAME}:${FTP_GROUP} /var/www
chmod 775 /var/www/html

# Create session pool
mkdir -p /var/lib/php/session
chown -R $FTP_USERNAME:$FTP_USERNAME /var/lib/php/session
chmod 775 /var/lib/php/session

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
rm -rf /root/nginx-1.6.2
rm -rf /root/release-1.9.32.3-beta.zip
rm -rf /root/ngx_pagespeed-release-1.9.32.3-beta
rm -rf /root/mysql-community-release-el6-5.noarch.rpm

#####################
# Installation completed. #
#####################
clear
echo "========================================"
echo "LNMP Installation Complete!"
echo "========================================"
echo "The configuration is now ready for testing."
echo "========================================"
