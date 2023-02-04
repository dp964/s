#!/bin/bash

SERVERNAME=$(cat /etc/hostname) # in case we haven't rebooted the box after updating the hostname

### Installing Packages
echo ">>> INSTALLING REQUIRED PACKAGES"

# Install Dev Tools
yum groupinstall -y 'Development Tools'
yum install -y nano
dnf makecache --refresh
dnf config-manager --set-enabled crb

# Install Mongo DB
rm -f /etc/yum.repos.d/mongodb-org-6.0.repo
cat << @EOF > /etc/yum.repos.d/mongodb-org-6.0.repo
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
@EOF

yum install -y mongodb-org
systemctl enable mongod
systemctl start mongod

# Install PHP
yum install -y php
systemctl enable php-fpm
systemctl start php-fpm

# Install Apache
yum install -y httpd
systemctl enable httpd
systemctl start httpd

# Install OpenSSL FIPS

cd ~/
wget https://www.openssl.org/source/openssl-1.1.1s.tar.gz
tar -xzvf openssl-1.0.2e.tar.gz
cd ~/openssl-1.0.2e
./config fips 
make depend
make 	
make install

# Install Development Packages
dnf install -y wget
dnf install -y libevent
dnf install -y libevent-devel
dnf install -y meson

dnf install -y python3-pip
dnf install -y augeas-libs
dnf install -y mod_ssl
dnf install -y cmake
dnf install -y libmicrohttpd-devel
dnf install -y jansson-devel
dnf install -y openssl-devel


dnf install -y libsrtp-devel
dnf install -y glib2-devel
dnf install -y opus-devel
dnf install -y libogg-devel
dnf install -y libcurl-devel
dnf install -y pkgconfig
dnf install -y libconfig-devel
dnf install -y libtool
dnf install -y autoconf
dnf install -y automake
dnf install -y libsrtp-devel

# Install Libnice
git clone https://gitlab.freedesktop.org/libnice/libnice
cd ~/libnice
meson --prefix=/usr build && ninja -C build && sudo ninja -C build install
cd ~/

# Install UsrSctp
git clone https://github.com/sctplab/usrsctp
cd ~/usrsctp
./bootstrap
./configure
make
make install
cd ~/

# Install Sofia

git clone https://github.com/freeswitch/sofia-sip.git
cd ~/sofia-sip
sh autogen.sh
./configure
make
make install
cd ~/

# Other packages
yum install -y doxygen
yum install -y graphviz

# Install Certbot
dnf config-manager --set-enabled crb
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-9.noarch.rpm
#dnf list|grep snapd
dnf install -y snapd
systemctl enable snapd
systemctl start snapd
systemctl status snapd
snap install -y core
ln -s /var/lib/snapd/snap /snap
snap install --classic -y certbot
ln -s /snap/bin/certbot /usr/bin/certbot
systemctl list-timers

#### Configuring Virtual Hosts
echo $SERVERNAME
cat << @EOF > /etc/httpd/conf/${SERVERNAME}.conf
<VirtualHost *:80>
    ServerName ${SERVERNAME}
    DocumentRoot /var/www/html
    ServerAlias ${SERVERNAME}
RewriteEngine on
RewriteCond %{SERVER_NAME} =${SERVERNAME}
RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>

<IfModule mod_ssl.c>
<VirtualHost *:443>
        ServerName ${SERVERNAME}
        DocumentRoot /var/www/html
        ServerAlias ${SERVERNAME}

        SSLCertificateFile /etc/letsencrypt/live/${SERVERNAME}/fullchain.pem
        SSLCertificateKeyFile /etc/letsencrypt/live/${SERVERNAME}/privkey.pem
        Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
</IfModule>
@EOF

cat << @EOF > /etc/httpd/conf/api.${SERVERNAME}.conf
Listen 80
Listen 443
<VirtualHost *:80>
        ServerName api.${SERVERNAME}
        DocumentRoot /var/www/html/api
        ServerAlias api.${SERVERNAME}
        RewriteEngine on
        RewriteCond %{SERVER_NAME} =api.${SERVERNAME}
        RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>

<IfModule mod_ssl.c>
<VirtualHost *:443>
        ServerName api.${SERVERNAME}
        DocumentRoot /var/www/html/api
        ServerAlias api.${SERVERNAME}

        SSLCertificateFile /etc/letsencrypt/live/api.${SERVERNAME}/fullchain.pem
        SSLCertificateKeyFile /etc/letsencrypt/live/api.${SERVERNAME}/privkey.pem
        Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
</IfModule>
@EOF

### Configuring Certbot
certbot certonly -d ${SERVERNAME} -d www.${SERVERNAME}
certbot certonly -d api.${SERVERNAME} -d www.api.${SERVERNAME}

systemctl restart httpd

## Rollback OpenSSL to known working version and install compat layer
yum downgrade openssl-3.0.1-41.el9
dnf install compat-openssl11

systemctl restart httpd

### Configuring Coturn

wget https://coturn.net/turnserver/v4.5.2/turnserver-4.5.2.tar.gz
tar -xf turnserver-4.5.2.tar.gz
mv turnserver-4.5.2 coturn
cd ~/coturn
./configure
make
make install
cd ~/