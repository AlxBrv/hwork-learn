#!/bin/bash
#Created by Aleksey Borisov (alx.tech@yandex.ru) on VIM 7.4

#Проверка на синтаксис (необходимо раскомментировать set -n) 
#set -n

#Глобальные переменные
good_1=" Установка прошла успешно! "
bad_1="Что-то пошло не так! Проверьте log-файл!"
red="\033[0;31m"
green="\033[0;32m"
back_col="\033[0m"

# Help по скрипту
if [[ $1 = "help" ]]
	then
	echo "	Краткая справка по скрипту!"
	echo "Данный скрипт производит установку серверов Nginx и Apache. Настраивает работу Nginx на порту 80,"
	echo "методом подмены другой конфигурации (конфигурация по умолчанию сохраняется с расширением *.bak). Так же"
	echo "настраивает работу Apache на порты отличные от 80 ( будут установлены порты 8080, 8081, 8082), "
	echo "создает виртуальные кофигурации из типовой (virt_conf.conf). Создает каталоги в директории /var/www для теста"
	echo "и помещает в эти каталоги тестовые страницы для проверки. И конечно, на сервер Nginx настраивает upstream "
	echo "для перенаправления обращений на Apache."
	echo "Самое главное - убедитесь что файлы nginx.conf и virt_conf.conf находятся в том же каталоге, что и скрипт! "
	exit 0
fi

#Проверка от кого запущен скрипт
if ! [[ $(id -u) = 0 ]]
	then 
	echo
	echo -e "$red *** $back_col Для полноценной работы скрипта, запустите его от пользователя $green root $back_col или с использованием команды $green sudo $back_col! $red *** $back_col"
	echo
	exit 1
fi 

# Функция установки апач с проверкой установки
inst_apache () {
	echo -e  "Подождите идет установка Apache..."
      	yum install -y httpd &> apache_install.log   
	wait
	if [[ `yum list installed | grep "httpd.x86_64" | awk '{print$1}'` = "httpd.x86_64" ]] 
	 then 
		echo -e $green $good_1 $back_col
	 else 
		echo -e $red $bad_1 $back_col 
		exit 1
      	fi  
}

# Функция установки Nginx с проверкой установки. 
inst_nginx () {
	echo -e "Подождите идет установка Nginx ...."
	yum install -y epel-release &> epel_install.log && yum install -y nginx &> nginx_install.log
	wait
	if [[ `yum list installed | grep "nginx.x86_64" | awk '{print$1}'` = "nginx.x86_64" ]]
	 then
		echo -e $green $good_1 $back_col
	 else
		echo -e $red $bad_1 $back_col 
		exit 1
	fi	
}

# Подготовка сервера Nginx
prep_nginx () {
	#копируем базовую конфигурацию
	cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
	#меняем базовую конфигурацию
	 `yes | cp -i ./nginx.conf /etc/nginx/ &> /dev/null`
}

# Подготовка сервера Apache
prep_apache () {
	#копируем базовую конфигурацию
	cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak
	
	# вносим изменения в базовую конфигурацию
	sed -i "s/Listen 80/#Listen 80/" /etc/httpd/conf/httpd.conf 
		
	#создаем три новые конфигурации
	cp ./virt_conf.conf /etc/httpd/conf.d/virt_conf1.conf
	cp ./virt_conf.conf /etc/httpd/conf.d/virt_conf2.conf
	cp ./virt_conf.conf /etc/httpd/conf.d/virt_conf3.conf
	
	#подредактируем 2 и 3 конфигурации
 	sed -i "s/8080/8081/" /etc/httpd/conf.d/virt_conf2.conf
	sed -i "s/html1/html2/" /etc/httpd/conf.d/virt_conf2.conf 
	sed -i "s/error1/error2/" /etc/httpd/conf.d/virt_conf2.conf
	sed -i "s/access1/access2/" /etc/httpd/conf.d/virt_conf2.conf

	sed -i "s/8080/8082/" /etc/httpd/conf.d/virt_conf3.conf
	sed -i "s/html1/html3/" /etc/httpd/conf.d/virt_conf3.conf
	sed -i "s/error1/error3/" /etc/httpd/conf.d/virt_conf3.conf
	sed -i "s/access1/access3/" /etc/httpd/conf.d/virt_conf3.conf
			
	#создадим каталоги и стартовые страницы для проверки
	mkdir /var/www/html{1..3} 
	echo "<html><h1><center><font color="red">***Test port 8080!***</font></center></h1></html>" > /var/www/html1/index.html
	echo "<html><h1><center><font color="green">***Test port 8081!***</font></center></h1></html>" > /var/www/html2/index.html
	echo "<html><h1><center><font color="blue">***Test port 8082!***</font></center></h1></html>"> /var/www/html3/index.html
}

#Отключение SElinux & Firewall (при необходимости)
off_fire () {
	setenforce 0
	systemctl stop firewalld
}

# Меню для установки
inst_menu () {
while :
	do
	    echo
	    echo -e "$red******$back_col Меню установки $red******$back_col"
	    echo " 1) Установка сервера Nginx "
	    echo " 2) Установка сервера Apache "
	    echo " 3) Подготовка сервера Nginx (настройка портов, настройка upstream) "
	    echo " 4) Подготовка сервера Apache (настройка портов, создание виртуальных конфигураций и тестовых страниц) " 
	    echo " 5) Отключение SElinux и Firewalld "
	    echo " 6) Старт сервера Nginx и добавление его в автозагрузку"
	    echo " 7) Старт сервера Apache и добавление его в автозагрузку"
	    echo " 8) Произвести все настройки сразу"
	    echo " 9) Выход из скрипта "
	    echo
	    echo -e "$green Выберите одно из действий: $back_col"
	    read var_move
	    echo
	    case $var_move in
	    1) inst_nginx
	    ;;
	    2) inst_apache
	    ;;
	    3) prep_nginx
	    ;;
	    4) prep_apache
	    ;;
	    5) off_fire
	    ;;
	    6) `systemctl enable nginx && systemctl start nginx`
	    ;;
	    7) `systemctl enable httpd && systemctl start httpd`
	    ;;
	    8) inst_nginx && inst_apache && prep_nginx && prep_apache && off_fire && systemctl enable nginx httpd && systemctl start nginx httpd 
	    ;;
	    9) echo -e "$green До свидания ! $back_col" && sleep 3 && exit 0
	    ;;
	    *) echo "Выберите действие из меню!"
	    ;;
	    esac
	done
	
}

#Привествие скрипта

echo
echo -e "$green*****************************************************************************************$back_col"
echo -e "Доброго времени суток!"
echo -e "Данный скрипт производит установку сервера Nginx и сервера Apache. Далее, настраивает сервер "
echo -e "Nginx как frontend сервер, а сервер Apache как backend сервер. После установки и настройки "
echo -e "сервер Nginx будет работать на 80 порту, сервер Apache будет работать на портах 8080, 8081, 8082."
echo -e "Также будет произведена настройка upstream на сервере Nginx. Для проверки будут сгенерированы 3 "
echo -e "страницы для проверки работоспособности."
echo -e "Все перечисленные действия можно производить поэтапно через меню."
echo -e "$red ВНИМАНИЕ! $back_col При установке убедитесь что файлы $green nginx.conf $back_col и "
echo -e "$green virt_conf.conf $back_col находятся в том же каталоге, что и скрипт установки."
echo -e "$green*****************************************************************************************$back_col" 
echo

#Вызываем меню
inst_menu

