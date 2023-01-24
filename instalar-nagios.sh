#!/bin/bash

# Descargar en terminal, permisos y ejecutar
# cd /tmp && wget https://raw.githubusercontent.com/eloysanchez/nagios/main/instalar-nagios.sh && chmod +x instalar-nagios.sh && ./instalar-nagios.sh

nagios_version="4.4.10"
plugins_version="2.4.3"
# nagiosadmin_passwd=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12)
nagiosadmin_passwd="changeme"

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
  htpasswd -bc /usr/local/nagios/etc/htpasswd.users nagiosadmin ${nagiosadmin_passwd}
  #Reiniciar Apache
  systemctl restart apache2.service
  #Iniciar servicio
  systemctl start nagios.service
}

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

preRequisitos
instalarNagios
instalarPlugins

# Mostrar contraseña nagiosadmin
echo "La contraseña para nagiosadmin es: ${nagiosadmin_passwd}"