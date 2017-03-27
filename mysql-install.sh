#!/bin/bash
DATACENTER=$1
MASTERVMNAME=$2
MYSQL_PW=$3
echo "datacenter=$1"
echo "masterVmName=$2"
echo "adminUserName=$3"
HOSTPREFIX=${MASTERVMNAME%?}
sudo apt-get update
export DEBIAN_FRONTEND="noninteractive"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_PW"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_PW"
sudo apt-get install -y mysql-server-5.7
#sudo mysql_secure_installation
ADV_ADDR=$(ifconfig | grep -A1 "eth0" | grep -o "inet addr:\S*" | grep -o -e "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*")
sudo sed -i "s/^\(bind-address\s*=\s*\).*\$/\1$ADV_ADDR/" /etc/mysql/mysql.conf.d/mysqld.cnf
sudo bash -c 'echo "innodb_buffer_pool_size = 2G" >> /etc/mysql/mysql.conf.d/mysqld.cnf'
sudo bash -c 'echo "default-time-zone=''+00:00''" >> /etc/mysql/mysql.conf.d/mysqld.cnf'
sudo bash -c 'echo "character-set-server=utf8mb4" >> /etc/mysql/mysql.conf.d/mysqld.cnf'
sudo bash -c 'echo "collation-server=utf8mb4_general_ci" >> /etc/mysql/mysql.conf.d/mysqld.cnf'
sudo systemctl restart mysql
sudo echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' 
    IDENTIFIED BY '$MYSQL_PW' 
    WITH GRANT OPTION; FLUSH PRIVILEGES;" > "mysql-setup.sql"
mysql -u root --password="$MYSQL_PW" < "mysql-setup.sql"
sudo rm mysql-setup.sql
curl -X PUT -d "{\"Datacenter\": \"$DATACENTER\", \"Node\": \"mysql\", \"Address\" : \"$ADV_ADDR\", \"Service\": {\"Service\": \"mysql\", \"Port\": 3306, \"Address\" : \"$ADV_ADDR\"}}" http://$MASTERVMNAME:8500/v1/catalog/register
sudo echo "mysql server created and registered with consul"
