#!/bin/bash

# Descargar en terminal, permisos y ejecutar
# cd /tmp && wget https://raw.githubusercontent.com/eloysanchez/nagios/main/instalar-nagios.sh && chmod +x instalar-nagios.sh && ./instalar-nagios.sh

NAGIOS_VERSION="4.4.10"
PLUGINS_VERSION="2.4.3"
# NAGIOSADMIN_PASSWD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12)
NAGIOSADMIN_PASSWD="changeme"
MYSQL_ROOT_PASSWD="changeme"

# Prerrequisitos y dependencias
instalar_prerrequisitos (){
  export PATH=$PATH:/usr/sbin     
  apt-get update
  apt-get install -y autoconf gcc libc6 make wget unzip apache2 apache2-utils php libgd-dev openssl libssl-dev
}

# Instalar Nagios Core
instalar_nagios (){
  # Descargar
  cd /tmp || return
  wget -O nagioscore.tar.gz https://github.com/NagiosEnterprises/nagioscore/archive/nagios-$NAGIOS_VERSION.tar.gz
  tar xzf nagioscore.tar.gz
  cd /tmp/nagioscore-nagios-$NAGIOS_VERSION || return
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
  htpasswd -bc /usr/local/nagios/etc/htpasswd.users nagiosadmin $NAGIOSADMIN_PASSWD
  # Reiniciar Apache
  systemctl restart apache2.service
  # Iniciar servicio
  systemctl start nagios.service
}

# Instalar Plugins de Nagios
instalar_plugins (){
  # Prerequisitos y dependencias
  apt-get install -y autoconf gcc libc6 libmcrypt-dev make libssl-dev wget bc gawk dc build-essential snmp libnet-snmp-perl gettext
  # Descargar
  cd /tmp || return
  wget --no-check-certificate -O nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-$PLUGINS_VERSION.tar.gz
  tar zxf nagios-plugins.tar.gz
  # Compilar e instalar
  cd /tmp/nagios-plugins-release-$PLUGINS_VERSION/ || return
  ./tools/setup
  ./configure
  make
  make install
}

# Instalar pnp4nagios
instalar_pnp4nagios () {
  # Prerequisitos y dependencias
  apt update && apt install -y rrdtool librrds-perl php-gd php-xml
  # Instalar pnp4nagios
  cd /tmp || return
  wget http://downloads.sourceforge.net/project/pnp4nagios/PNP-0.6/pnp4nagios-0.6.26.tar.gz
  tar xzvf pnp4nagios-0.6.26.tar.gz
  cd pnp4nagios-0.6.26 || return
  ./configure --with-httpd-conf=/etc/apache2/sites-available
  make all
  make fullinstall
  a2ensite pnp4nagios
  systemctl reload apache2
  update-rc.d npcd defaults
  service npcd start
  service npcd status
  mv /usr/local/pnp4nagios/share/install.php /usr/local/pnp4nagios/share/install.php.bak

  # Configurar process_performance
  cp /usr/local/nagios/etc/nagios.cfg /usr/local/nagios/etc/nagios.cfg.bak
  sed -i "s/process_performance_data=0/process_performance_data=1/g" /usr/local/nagios/etc/nagios.cfg

  # Generar configuracion para nagios.cfg
  cat << 'EOF' > nagios_file.txt
# Bulk / NPCD mode
# *** the template definition differs from the one in the original nagios.cfg
#
service_perfdata_file=/usr/local/pnp4nagios/var/service-perfdata
service_perfdata_file_template=DATATYPE::SERVICEPERFDATA\tTIMET::$TIMET$\tHOSTNAME::$HOSTNAME$\tSERVICEDESC::$SERVICEDESC$\tSERVICEPERFDATA::$SERVICEPERFDATA$\tSERVICECHECKCOMMAND::$SERVICECHECKCOMMAND$\tHOSTSTATE::$HOSTSTATE$\tHOSTSTATETYPE::$HOSTSTATETYPE$\tSERVICESTATE::$SERVICESTATE$\tSERVICESTATETYPE::$SERVICESTATETYPE$
service_perfdata_file_mode=a
service_perfdata_file_processing_interval=15
service_perfdata_file_processing_command=process-service-perfdata-file

# *** the template definition differs from the one in the original nagios.cfg
#
host_perfdata_file=/usr/local/pnp4nagios/var/host-perfdata
host_perfdata_file_template=DATATYPE::HOSTPERFDATA\tTIMET::$TIMET$\tHOSTNAME::$HOSTNAME$\tHOSTPERFDATA::$HOSTPERFDATA$\tHOSTCHECKCOMMAND::$HOSTCHECKCOMMAND$\tHOSTSTATE::$HOSTSTATE$\tHOSTSTATETYPE::$HOSTSTATETYPE$
host_perfdata_file_mode=a
host_perfdata_file_processing_interval=15
host_perfdata_file_processing_command=process-host-perfdata-file
EOF
  cat nagios_file.txt >> /usr/local/nagios/etc/nagios.cfg

  # Generar configuracion a commands.cfg
  cp /usr/local/nagios/etc/objects/commands.cfg /usr/local/nagios/etc/objects/commands.cfg.bak
  cat << 'EOF' > commands_file.txt
# Bulk with NPCD mode
#define command {
       command_name    process-service-perfdata-file
       command_line    /bin/mv /usr/local/pnp4nagios/var/service-perfdata /usr/local/pnp4nagios/var/spool/service-perfdata.$TIMET$
}
#define command {
       command_name    process-host-perfdata-file
       command_line    /bin/mv /usr/local/pnp4nagios/var/host-perfdata /usr/local/pnp4nagios/var/spool/host-perfdata.$TIMET$
}
EOF
  cat commands_file.txt >> /usr/local/nagios/etc/objects/commands.cfg

  # Generar configuracion a templates.cfg
  cp /usr/local/nagios/etc/objects/templates.cfg /usr/local/nagios/etc/objects/templates.cfg.bak
  cat << 'EOF' > template_file.txt
# PNP4NAGIOS #
define host {
name          host-pnp
action_url    /pnp4nagios/index.php/graph?host=$HOSTNAME$&srv=_HOST_' class='tips' rel='/pnp4nagios/index.php/popup?host=$HOSTNAME$&srv=_HOST 
register      0
}
define service {
name          srv-pnp
action_url    /pnp4nagios/index.php/graph?host=$HOSTNAME$&srv=$SERVICEDESC$' class='tips' rel='/pnp4nagios/index.php/popup?host=$HOSTNAME$&srv=$SERVICEDESC$ 
register      0
}
EOF
  cat template_file.txt >> /usr/local/nagios/etc/objects/templates.cfg

  # Crear fichero ssi para popup
  cat << 'EOF' > /usr/local/nagios/share/ssi/status-header.ssi
<script src="/pnp4nagios/media/js/jquery-min.js" type="text/javascript"></script>
<script src="/pnp4nagios/media/js/jquery.cluetip.js" type="text/javascript"></script>
<script type="text/javascript">
jQuery.noConflict();
jQuery(document).ready(function() {
  jQuery('a.tips').cluetip({ajaxCache: false, dropShadow: false,showTitle: false });
});
</script>
EOF

  # Corregir error magic_quotes
  cp /usr/local/pnp4nagios/lib/kohana/system/libraries/Input.php /usr/local/pnp4nagios/lib/kohana/system/libraries/Input.php.bak
  sed -i '/magic_quotes_runtime is enabled/a /**' /usr/local/pnp4nagios/lib/kohana/system/libraries/Input.php
  sed -i '/register_globals is enabled/i */' /usr/local/pnp4nagios/lib/kohana/system/libraries/Input.php
  # Corregir error sizeof()
  cp /usr/local/pnp4nagios/share/application/models/data.php /usr/local/pnp4nagios/share/application/models/data.php.bak
  sed -i 's/if(sizeof(\$pages) > 0 ){/if(is_array(\$pages) \&\& sizeof(\$pages) > 0 ){/' /usr/local/pnp4nagios/share/application/models/data.php

  # Reiniciar servicios
  service apache2 restart && service nagios restart && service npcd restart
}

# Instalar NagiosQL
instalar_nagiosql (){
  # Prerequisitos y dependencias
  apt update && apt install -y mariadb-server php libapache2-mod-php php-mysql php-ssh2 php-pear php-curl
  # Configurar usuario mysql
  mysql --user=root <<_EOF_
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWD}';
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
instalar_prerrequisitos
instalar_nagios
instalar_plugins
instalar_nagiosql

# Mostrar contraseña generada nagiosadmin
echo "La contraseña para nagiosadmin es: ${NAGIOSADMIN_PASSWD}"