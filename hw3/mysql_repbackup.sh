#!/bin/bash
#Created by Borisov Aleksey on VIM 7.


#Проверка от кого запущен скрипт
if ! [[ $(id -u) = 0 ]]
    then
    echo
    echo "Для полноценной работы скрипта, запустите его от пользователя root или с использованием команды sudo !!!"
    echo
    exit 1
fi
#Блок переменных
time_stamp=$(date +"%F_%T")
backup_dir="/var/backup/$time_stamp"
mysql_usr="root"
mysql_pass="MegaPassMeta11!"
mysql=/usr/bin/mysql
mysql_dump=/usr/bin/mysqldump
echo
echo "Снимаем dump баз потаблично......."
echo

#Переберем все базы и архивируем таблицы
mkdir -p "$backup_dir"
dt_bases=`$mysql --user=$mysql_usr -p$mysql_pass --skip-column-names -e "SHOW DATABASES;" 2> /dev/null`
for dt in $dt_bases;
    do
        dt_table=`$mysql --user=$mysql_usr -p$mysql_pass --skip-column-names -e "USE $dt;SHOW TABLES;" 2> /dev/null`
        for tt in $dt_table;
	    do
		`$mysql_dump --user=$mysql_usr -hlocalhost -p$mysql_pass --add-drop-table --add-locks --create-options --disable-keys --extended-insert --single-transaction --quick --set-charset --events --routines --triggers $dt $tt  2> /dev/null | gzip > $backup_dir/$dt--$tt.sql.gz ` 
 
	    done
    done
echo
echo "Все готово! Архивы таблиц находятся в /var/backup/время создания."
echo

