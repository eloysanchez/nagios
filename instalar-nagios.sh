#!/bin/bash

nagios_version="4.4.10"
plugins_version="2.4.3"

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
  #Crear cuenta nagiosadmin
  htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin
  #Reiniciar Apache
  systemctl restart apache2.service
  #Iniciar servicio
  systemctl start nagios.service
}

preRequisitos
instalarNagios

