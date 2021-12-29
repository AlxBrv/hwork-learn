#!/bin/bash
#Created by Borisov Aleksey on VIM 7.
#Скрипт установки и настройки MySQl сервера (реплика-сервер)

#Проверка от кого запущен скрипт.
if ! [[ $(id -u) = 0 ]]
    then
    echo
    echo "Для полноценной работы скрипта, запустите его от пользователя root или с использованием команды sudo !!!"
    echo
    exit 1
fi
 
#Добавляем репозиторий и включаем его
rpm -Uvh https://repo.mysql.com/mysql80-community-release-el7-3.noarch.rpm &> /dev/null
sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/mysql-community.repo

# Устанавливаем MySQL
yum --enablerepo=mysql80-community install -y mysql-community-server &> /dev/null

# Стартуем MySQl и ставим в автозагрузку
systemctl start mysqld
systemctl enable mysqld &> /dev/null

# Вырубаем firewall
systemctl stop firewalld
systemctl disable firewalld &> /dev/null

# Подчистим MySQL (взял со StackOverflow, каюсь...)
t_pass=$(grep "A temporary password" /var/log/mysqld.log | awk '{split($0,a,": "); print a[2]}')
#echo $t_pass 
n_pass="MegaPassMeta11!"
cat > mysql_secure_install.sql << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY 'MegaPassMeta11!';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
mysql -uroot -p"$t_pass" --connect-expired-password < mysql_secure_install.sql &> /dev/null
rm -f ./mysql_secure_install.sql

# Меняем server UUID
rm -f /var/lib/mysql/auto.cnf
systemctl restart mysqld

# Меняем сервер Id
cp /etc/my.cnf /etc/my.cnf.bak
echo "server_id = 2" >> /etc/my.cnf
systemctl restart mysqld

#Формируем запрос для подключения к мастеру
echo
echo "Ввведите IP адрес мастер-сервера MySQL:"
read ip_master
echo "Введите имя пользователя для репликации (созданный на мастере пользователь replica):  "
read usr_master
echo "Укажите пароль данного пользователя (созданный на мастере MegaPassR1sk!): "
read pass_master
echo "Укажите файл binlog (можно посмотреть из консоли MySQL на мастере командой SHOW MASTER STATUS;): "
read binlog_file
echo "Укажите позицию binlog (можно посмотреть из консоли MySQL на мастере командой SHOW MASTER STATUS;): "
read binlog_pos

#Исполняем запрос к MySQL
cat > change_master.sql << EOF
STOP SLAVE;
CHANGE MASTER TO MASTER_HOST='$ip_master', MASTER_USER='$usr_master', MASTER_PASSWORD='$pass_master', MASTER_LOG_FILE='$binlog_file', MASTER_LOG_POS=$binlog_pos, GET_MASTER_PUBLIC_KEY=1;
START SLAVE;
EOF
mysql -uroot -p"$n_pass" --connect-expired-password < change_master.sql &> /dev/null 
 
rm -f ./change_master.sql
echo
echo "Сервер-реплика MySQL для $ip_master готов!"
echo


