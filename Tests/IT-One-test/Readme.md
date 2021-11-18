### Тестовый проект ### 


#### Выполнить разбор файла почтового лога, залить данные в БД и организовать поиск по адресу получателя. ####
Парсинг данных  на вход принимает путь до zip файла с логами.  

[parse.pl](https://github.com/intellicomru/public-examples/blob/main/Tests/IT-One-test/parse.pl )   < путь до zip файла с логами>

Поиск через веб форму:  [itone.pl](https://github.com/intellicomru/public-examples/blob/main/Tests/IT-One-test/cgi-bin/itone.pl )  
  
  http://51.250.20.24/cgi-bin/itone.pl

#### поскольку инфраструктуры не было предоставлено, то процесс был следующий:  ####

Завели виртуалку в облаке яндекса. Для простоты выбрали Дебиан  


![Виртуалка в облаке](https://github.com/intellicomru/public-examples/blob/main/Tests/IT-One-test/cloud.jpg)
 1. Обновим Debian  
apt-get -y update  
apt-get -y upgrade  


apt-get -y install nginx   
systemctl start nginx   
systemctl enable nginx   

apt-get -y install apache2   
sed -i "s/Listen 80/Listen 127.0.0.1:8080/" /etc/apache2/ports.conf  

 Apache2 Real IP  
 ```
vi /etc/apache2/mods-available/remoteip.conf  
<IfModule remoteip_module>
  RemoteIPHeader X-Forwarded-For
  RemoteIPTrustedProxy 127.0.0.1/8
</IfModule>
```

Активируем модуль:  

a2enmod remoteip  

cgi   

vi /etc/apache2/sites-available/000-default.conf  


```
 <VirtualHost *:8080>
ServerName myhost

ServerAdmin webmaster@localhost
DocumentRoot /var/www/html

ErrorLog ${APACHE_LOG_DIR}/error.log
CustomLog ${APACHE_LOG_DIR}/access.log combined

ScriptAlias /cgi-bin/ /var/www/cgi-bin/
<Directory «/var/www/cgi-bin/»>
     AllowOverride None
     Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
     Require all granted
</Directory>

</VirtualHost>
```

a2enmod cgi  
mkdir -p /var/www/cgi-bin/  
systemctl restart apache2    

  конфигурим  nginx   

systemctl restart nginx   

 поставили гит   

cd  /var/www/    
apt-get install git   
git init   
git remote add origin https://github.com/intellicomru/project-otus.git   
git pull origin master    

###### ставим постгрю и модули Perl   ######  

sudo apt-get -y install postgresql    
 pg_lsclusters  
 
 ```
 pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
11  main    5432 online postgres /var/lib/postgresql/11/main /var/log/postgresql/postgresql-11-main.log

```

sudo -u postgres psql  
CREATE ROLE itone LOGIN PASSWORD '1234567890';  
CREATE DATABASE itone;  
 ALTER DATABASE itone OWNER TO itone;  
 \q  
 
 --После этого нужно добавить для этого пользователя строчку в файл   
 /etc/postgresql/11/main/pg_hba.conf   
 local   all             itone                             md5 
 
sudo systemctl stop postgresql@11-main     
sudo systemctl start postgresql@11-main  



 **perl вспомогательные модули. просто для удобства**  
   
```
sudo -s 
apt-get install build-essential
cpan 
install CGI 
install lib::abs
install uni::perl
install DBI
install YAML::XS
install Spreadsheet::Read
install LWP::UserAgent
install JSON

```

#### драйвера для связи перла и базы #### 
sudo apt-get install libpq-dev  
apt-get install libdbd-pg-perl


создаем таблицы

```
psql -U itone -d itone

CREATE TABLE message (  
created TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
id VARCHAR NOT NULL,
int_id CHAR(16) NOT NULL,
str VARCHAR NOT NULL,
status BOOL,
CONSTRAINT message_id_pk PRIMARY KEY(id)
);
CREATE INDEX message_created_idx ON message (created);
CREATE INDEX message_int_id_idx ON message (int_id);


CREATE TABLE log (
       created TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
       int_id CHAR(16) NOT NULL,
       str VARCHAR,
       address VARCHAR
 );
 CREATE INDEX log_address_idx ON log USING hash (address);

```

заполняем данными скриптом из каталога куда все сложили:  
cd /var/www/  
[parse.pl](https://github.com/intellicomru/public-examples/blob/main/Tests/IT-One-test/parse.pl ) [out.zip](https://github.com/intellicomru/public-examples/blob/main/Tests/IT-One-test/out.zip  )   

Все можно пользоваться веб формой для поиска по емайл :  
Например [так](http://51.250.20.24/cgi-bin/itone.pl?search=xmdnwgppabwp%40gmail.com)  




