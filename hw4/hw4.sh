#!/bin/bash
#Created by Aleksey Borisov (alx.tech@yandex.ru) on VIM 7.4

#Проверка синтаксиса (необходимо раскомментировать set -n)
#set -n

#Глобальные переменные
good_1=" Установка прошла успешно! "
bad_1="Что-то пошло не так! Проверьте log-файл!"
red="\033[0;31m"
green="\033[0;32m"
back_col="\033[0m"

#Проверка от кого запущен скрипт
if ! [[ $(id -u) = 0 ]]
    then
	echo
    	echo "Для полноценной работы скрипта, запустите его от пользователя root или с использованием команды sudo!"
    	echo
    	exit 0
fi

#Функция установки Apache
inst_apache () {
	echo
	echo -e  "Подождите, идет установка Apache..."
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

#Отключение firewall & SElinux

off_fire () {
	setenforce 0 &> /dev/null
	systemctl stop firewalld
	systemctl disable firewalld &> /dev/null
}

# Установка Docker
inst_docker () {
	echo
	echo -e "Подождите, идет установка Docker ..."
	yum install -y yum-utils &> /dev/null
	wait
	yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo &> /dev/null
	wait
	yum install -y docker-ce docker-ce-cli contained.io &> docker_install.log
	if [[ `yum list installed | grep "docker-ce.x86_64" | awk '{print$1}'` = "docker-ce.x86_64" ]]
	 then
		echo -e $green $good_1 $back_col
	 else
		echo -e $red $bad_1 $back_col 
		exit 1
	fi	

}

#Качаем образ, подготовливаем и стартуем NGINX
inst_nginx () {
	echo
	echo -e "Подождите, идет подготовка контейнера Nginx ..."
	systemctl start docker
	docker pull nginx &> /dev/null 
	wait
	`mkdir /var/nginx &> /dev/null `
	` yes | cp -i proxy.conf /var/nginx/proxy.conf &> /dev/null `
	wait
	docker run -dit --name otus-nginx --net=host -p 80 -v /var/nginx/proxy.conf:/etc/nginx/conf.d/default.conf nginx 
}
#Подготавливаем Apache
prep_apache () {
	echo
	echo -e "Подождите, идет подготовка сервера Apache ...."
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
	mkdir /var/www/html{1..3} &> /dev/null 
	echo "<html><h1><center><font color="red">***Test port 8080!***</font></center></h1></html>" > /var/www/html1/index.html
	echo "<html><h1><center><font color="green">***Test port 8081!***</font></center></h1></html>" > /var/www/html2/index.html
	echo "<html><h1><center><font color="blue">***Test port 8082!***</font></center></h1></html>"> /var/www/html3/index.html
}

off_fire
wait
inst_docker
wait
inst_nginx
wait
inst_apache
wait
prep_apache
wait
systemctl enable httpd &> /dev/null
systemctl start httpd

echo 
echo -e "$green Установка прошла успешно. До свидания! $back_col" && sleep 3 && exit 0 
echo





