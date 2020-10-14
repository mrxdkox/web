#!/bin/bash
apt update && apt upgrade -y && apt install nginx mariadb-server mariadb-client php-cgi php-common php-fpm php-pear php-mbstring php-zip php-net-socket php-gd php-xml-util php-gettext php-mysql php-bcmath curl -y

# Edit /etc/php/7.*/fpm/php.ini
sed -i 's/post_max_size = .*/post_max_size = 64M/g' /etc/php/7.*/fpm/php.ini
sed -i 's/memory_limit = .*/memory_limit = 256M/g' /etc/php/7.*/fpm/php.ini
sed -i 's/max_execution_time = .*/max_execution_time = 300/g' /etc/php/7.*/fpm/php.ini
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 32M/g' /etc/php/7.*/fpm/php.ini 
systemctl restart php7.*-fpm.service

# Configure nginx for WordPress
mkdir /var/www/wordpress
rm /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/wordpress << 'EOF'
server {
        listen 80;
        root /var/www/wordpress;
        index index.php index.html;
        
        access_log /var/log/nginx/wordpress_access.log;
        error_log /var/log/nginx/wordpress_error.log;
        client_max_body_size 64M;
    	  location = /favicon.ico {
        	log_not_found off;
        	access_log off;
    	  }
    	 location = /robots.txt {
       	allow all;
       	log_not_found off;
       	access_log off;
	  }
        location / {
                try_files $uri $uri/ /index.php?$args;
                }
        location ~ \.php$ {
                try_files $uri =404;
                include /etc/nginx/fastcgi_params;
                fastcgi_read_timeout 3600s;
                fastcgi_buffer_size 128k;
                fastcgi_buffers 4 128k;
                fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                fastcgi_pass unix:/run/php/php7.3-fpm.sock;
                fastcgi_index index.php;
                }
    	  location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        	    expires max;
        	   log_not_found off;
    		}
      }
EOF
nginx -t
ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
systemctl restart nginx.service
systemctl restart php7.*-fpm.service

#Configure WordPress database
#mysql_secure_installation
mysql -e "UPDATE mysql.user SET Password=PASSWORD('root') WHERE User='root';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
#WordPress
mysql -e "CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -e "GRANT ALL ON wordpress.* TO 'wpuser'@'localhost' IDENTIFIED BY 'pass';"
mysql -e "FLUSH PRIVILEGES;"

# Install WordPress
cd /tmp
curl -O https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php
cp -a wordpress/. /var/www/wordpress/
cd -

# Configure WordPress
sed -i 's/database_name_here/wordpress/g' /var/www/wordpress/wp-config.php
sed -i 's/username_here/wpuser/g' /var/www/wordpress/wp-config.php
sed -i 's/password_here/pass/g' /var/www/wordpress/wp-config.php
chown -R www-data:www-data /var/www/wordpress/
systemctl restart nginx
