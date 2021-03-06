#!/bin/bash

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install LEMP"
    exit 1
fi

clear
echo "==========================================================="
echo "LEMP web stack v1.2 for Linux CentOS 6.x, written by GP"
echo "==========================================================="
echo "A tool to auto-compile & install Nginx+MySQL+PHP on Linux "
echo ""
echo "For more information please visit https://makewebfast.com"
echo "==========================================================="


###########################
# Check and update the OS #
###########################
clear
echo "========================"
echo "Updating CentOS System"
echo "========================"
yum -y update


###################
# Create new user #
###################

# FTP and MySQL Credentials
FTP_USERNAME=$1
FTP_GROUP=$1
FTP_USER_PASSWORD=$2
MYSQL_ROOT_PASSWORD=$3

mkdir -p /var/www/html
mkdir -p /var/lib/php/session

/usr/sbin/groupadd $FTP_GROUP
/usr/sbin/adduser -g $FTP_GROUP -d /var/www/html $FTP_USERNAME

echo $FTP_USER_PASSWORD | passwd --stdin $FTP_USERNAME

# Limit FTP access only to /public_html directory
usermod --home /var/www/html $FTP_USERNAME

# Apply file permissions
chmod 755 /var/lib/php/session
chmod 755 /var/www/html

# Apply ownership
chown -R $FTP_USERNAME:$FTP_GROUP /var/lib/php/session
chown -R $FTP_USERNAME:$FTP_GROUP /var/www/html


###################################
# Install Webtatic repo for PHP 7 #
###################################
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm


##################################
# Add the necessary dependencies #
##################################
yum -y install wget zip unzip


###########################################################################
# Install NGINX - build it from oficial source with all necessary modules # 
###########################################################################

# Install dependencies
yum -y install openssl openssl-devel gcc-c++ pcre-dev pcre-devel zlib-devel make

# Download latest ngx_pagespeed module
cd
NPS_VERSION=1.10.33.7
wget https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.zip
unzip release-${NPS_VERSION}-beta.zip
cd ngx_pagespeed-release-${NPS_VERSION}-beta/
wget https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz
tar -xzvf ${NPS_VERSION}.tar.gz

# Download and build nginx with all the necessary modules - check http://nginx.org/en/download.html for the latest version
cd
NGINX_VERSION=1.8.1
wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
tar -xvzf nginx-${NGINX_VERSION}.tar.gz
cd nginx-${NGINX_VERSION}/
./configure --add-module=$HOME/ngx_pagespeed-release-${NPS_VERSION}-beta --with-http_gzip_static_module --with-http_realip_module --with-http_ssl_module
make
make install

# Create / replace the Nginx configuration files
touch /usr/local/nginx/conf/nginx.conf
touch /usr/local/nginx/conf/application.conf
touch /etc/init.d/nginx

wget https://raw.githubusercontent.com/gabrielPav/centos-lemp/master/conf/nginx/nginx.conf -O /usr/local/nginx/conf/nginx.conf
wget https://raw.githubusercontent.com/gabrielPav/centos-lemp/master/conf/nginx/application.conf -O /usr/local/nginx/conf/application.conf
wget https://raw.githubusercontent.com/gabrielPav/centos-lemp/master/conf/nginx/nginx.init.txt -O /etc/init.d/nginx

# Adjust the number of CPU cores: cat /proc/cpuinfo | grep ^processor | wc -l

chmod +x /etc/init.d/nginx
chkconfig nginx on
service nginx start
/etc/init.d/nginx status
/etc/init.d/nginx configtest
sleep 10
service nginx stop


#############################################
# install PHP-FPM with latest PHP 7 version #
#############################################

# Install all necessary PHP modules from Webtatic repo
# Wordpress dependencies: http://goo.gl/zMH3yg
cd
yum -y install php70w-fpm php70w-common php70w-cli php70w-xml php70w-process php70w-gd php70w-mbstring php70w-mysqlnd php70w-mcrypt php70w-pspell php70w-imap php70w-pear php70w-soap php70w-tidy php70w-opcache
chkconfig php-fpm on

# Change the user/group of PHP-FPM processes
sed -i 's/user = apache/user = nobody/g' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = nobody/g' /etc/php-fpm.d/www.conf

# Change some PHP variables
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 512M/g' /etc/php.ini
sed -i 's/display_errors = On/display_errors = Off/g' /etc/php.ini
sed -i 's/;date.timezone =/date.timezone = UTC/g' /etc/php.ini
sed -i 's/;session.save_path = "\/tmp"/session.save_path = "\/var\/lib\/php\/session"/g' /etc/php.ini

service php-fpm start
php -v
sleep 10
service php-fpm stop


#######################
# install MySQL 5.6.x #
#######################
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


######################
# Install MySQLTuner #
######################
cd
wget --no-check-certificate https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl
chmod u+x mysqltuner.pl


################################
# Install and configure VSFTPD #
################################

# Install VSFTPD
yum -y install ftp vsftpd
chkconfig vsftpd on
service vsftpd start

# Configure VSFTPD
sed -i 's/anonymous_enable=YES/anonymous_enable=NO/g' /etc/vsftpd/vsftpd.conf
sed -i 's/local_enable=NO/local_enable=YES/g' /etc/vsftpd/vsftpd.conf
sed -i 's/#chroot_local_user=YES/chroot_local_user=YES/g' /etc/vsftpd/vsftpd.conf

service vsftpd restart


########################
# Restart web services #
########################
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

# Apply ownership
chown -R $FTP_USERNAME:$FTP_GROUP /var/www/html

# Remove the installation files
rm -rf /root/nginx-1.8.1.tar.gz
rm -rf /root/nginx-1.8.1
rm -rf /root/release-1.10.33.7-beta.zip
rm -rf /root/ngx_pagespeed-release-1.10.33.7-beta
rm -rf /root/mysql-community-release-el6-5.noarch.rpm

clear
echo "========================================"
echo "LNMP Installation Complete!"
echo "========================================"
