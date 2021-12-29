#!/bin/bash
#Created by Borisov Aleksey on VIM 7.
#Скрипт установки и настройки MySQL сервера (мастер-сервер)

#Проверка от кого запущен скрипт
if ! [[ $(id -u) = 0 ]]
    then
    echo
    echo "Для полноценной работы скрипта, запустите его от пользователя root или с использованием команды sudo !!!"
    echo
    exit 1
fi

# Добавляем репозиторий и включем его
rpm -Uvh https://repo.mysql.com/mysql80-community-release-el7-3.noarch.rpm &> /dev/null
sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/mysql-community.repo

# Устанавливаем MySQL
yum --enablerepo=mysql80-community install -y mysql-community-server &> /dev/null

#Стартуем MySQL
systemctl start mysqld
systemctl enable mysqld &> /dev/null

#Вырубаем firewall
systemctl stop firewalld
systemctl disable firewalld &> /dev/null

#Подчистим MySQl (взял со StackOverflow, каюсь ...)
t_pass=$(grep "A temporary password" /var/log/mysqld.log | awk '{split($0,a,": "); print a[2]}')
#echo $t_pass
n_pass="MegaPassR0ck!"
cat > mysql_secure_install.sql << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY 'MegaPassR0ck!';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
mysql -uroot -p"$t_pass" --connect-expired-password < mysql_secure_install.sql &> /dev/null

#Содаем пользователя для репликации
cat > create_user_for_replica.sql << EOF
CREATE USER replica@'%' IDENTIFIED WITH 'caching_sha2_password' BY 'MegaPassR1sk!';
GRANT REPLICATION SLAVE ON *.* TO replica@'%';
EOF
mysql -uroot -p"$n_pass" --connect-expired-password < create_user_for_replica.sql &> /dev/null

echo
echo "Подчищаем....... "
rm -f ./mysql_secure_install.sql
rm -f ./create_user_for_replica.sql
echo
echo "Мастер-сервер MySQL готов!"
echo

echo "Создаем базу для теста"
cat > test_base_otus.sql << EOF
CREATE DATABASE otusedu;
USE otusedu;
CREATE TABLE otus_table (id int);
INSERT INTO otus_table values (11), (22), (33), (44), (55);
EOF
mysql -uroot -p"$n_pass" --connect-expired-password < test_base_otus.sql &> /dev/null
rm -f ./tets_base_otus.sql
echo
echo "База создана"


