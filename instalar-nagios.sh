#!/bin/bash

# Descargar en terminal, permisos y ejecutar
# cd /tmp && wget https://raw.githubusercontent.com/eloysanchez/nagios/main/instalar-nagios.sh && chmod +x instalar-nagios.sh && ./instalar-nagios.sh

nagios_version="4.4.10"
plugins_version="2.4.3"
# nagiosadmin_passwd=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12)
nagiosadmin_passwd="changeme"
mysql_root_passwd="changeme"

# Prerrequisitos y dependencias
preRequisitos (){
  export PATH=$PATH:/usr/sbin     
  apt-get update
  apt-get install -y autoconf gcc libc6 make wget unzip apache2 apache2-utils php libgd-dev openssl libssl-dev
}

# Instalar Nagios Core
instalarNagios (){
  # Descargar
  cd /tmp
  wget -O nagioscore.tar.gz https://github.com/NagiosEnterprises/nagioscore/archive/nagios-$nagios_version.tar.gz
  tar xzf nagioscore.tar.gz
  cd /tmp/nagioscore-nagios-$nagios_version
  # Compilar
  ./configure --with-httpd-conf=/etc/apache2/sites-enabled
  make all
  # Crear usuario y grupo
  make install-groups-users
  usermod -a -G nagios www-data
  # Instalar binarios
  make install
  # Instalar servicio
  make install-daemoninit
  # Instalar commando
  make install-commandmode
  # Instalar ficheros configuracion
  make install-config
  # Instalar configuración Apache
  make install-webconf
  a2enmod rewrite
  a2enmod cgi
  # Crear cuenta nagiosadmin
  htpasswd -bc /usr/local/nagios/etc/htpasswd.users nagiosadmin ${nagiosadmin_passwd}
  # Reiniciar Apache
  systemctl restart apache2.service
  # Iniciar servicio
  systemctl start nagios.service
}

# Instalar Plugins de Nagios
instalarPlugins (){
  # Prerequisitos y dependencias
  apt-get install -y autoconf gcc libc6 libmcrypt-dev make libssl-dev wget bc gawk dc build-essential snmp libnet-snmp-perl gettext
  # Descargar
  cd /tmp
  wget --no-check-certificate -O nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-$plugins_version.tar.gz
  tar zxf nagios-plugins.tar.gz
  # Compilar e instalar
  cd /tmp/nagios-plugins-release-$plugins_version/
  ./tools/setup
  ./configure
  make
  make install
}

# Instalar NagiosQL
instalarNagiosQL (){
  # Prerequisitos y dependencias
  apt update && apt install -y mariadb-server php libapache2-mod-php php-mysql php-ssh2 php-pear php-curl
  # Configurar usuario mysql
  mysql --user=root <<_EOF_
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_passwd}';
flush privileges;
_EOF_
  # Preparar directorios y permisos
  mkdir /etc/nagiosql
  mkdir /etc/nagiosql/hosts
  mkdir /etc/nagiosql/services
  mkdir /etc/nagiosql/backup
  mkdir /etc/nagiosql/backup/hosts
  mkdir /etc/nagiosql/backup/services
  chown -R www-data.nagios /etc/nagiosql
  chown -R www-data.nagios /usr/local/nagios/etc/nagios.cfg
  chown -R www-data.nagios /usr/local/nagios/etc/cgi.cfg
  chown -R www-data.nagios /usr/local/nagios/var/rw/nagios.cmd
  chown -R www-data.nagios /run/nagios.lock     # Comprobar si luego reinicia Nagios
  chmod 640 /usr/local/nagios/etc/nagios.cfg
  chmod 640 /usr/local/nagios/etc/cgi.cfg
  chmod 660 /usr/local/nagios/var/rw/nagios.cmd
  # Configurar timezone
  sed -i 's/^;date.timezone.*/date.timezone = "Europe\/Madrid"/g' /etc/php/7.4/apache2/php.ini
  systemctl restart apache2
  # Instalar NagiosQL
  wget https://gitlab.com/wizonet/nagiosql/-/archive/3.4.1-git2020-01-19/nagiosql-3.4.1-git2020-01-19.tar.gz
  tar zxvf nagiosql-3.4.1-git2020-01-19.tar.gz
  mv nagiosql-3.4.1-git2020-01-19 nagiosql
  mv nagiosql /var/www/html
  chown -R www-data /var/www/html/nagiosql/
  chmod 750 /var/www/html/nagiosql/config
}

# Ejecutar funciones
preRequisitos
instalarNagios
instalarPlugins
instalarNagiosQL

# Mostrar contraseña generada nagiosadmin
echo "La contraseña para nagiosadmin es: ${nagiosadmin_passwd}"