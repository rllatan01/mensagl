#!/bin/bash

######## Verificar si el script esta siendo ejecutado por el usuario root
if [ "$EUID" -ne 0 ]; then
  echo "Este script debe ser ejecutado como root."
  exit 1  # Salir con un codigo de error
else
echo "Eres root. Ejecutando el comando..."


########## Actualizar el sistema
apt update


######### INSTALACION MATRIX SYNAPSE
apt install -y lsb-release wget apt-transport-https

# Anadir la clave y repositorio de Matrix Synapse
wget -O /usr/share/keyrings/matrix-org-archive-keyring.gpg https://packages.matrix.org/debian/matrix-org-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/matrix-org-archive-keyring.gpg] https://packages.matrix.org/debian $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/matrix-org.list

# Actualizar e instalar Matrix Synapse
apt update
apt install -y matrix-synapse-py3
clear
echo "Matrix se ha instalado correctamente"


####### Configuracion matrix:
# Hacer una copia de seguridad del archivo de configuracion de Matrix
mv /etc/matrix-synapse/homeserver.yaml /etc/matrix-synapse/homeserver.yaml.back


# Solicitar el dominio y la contrasena al usuario
echo "Por favor, introduce tu dominio completo (e.g. matrix.example.com):"
read DOMINIO

echo "Por favor, introduce la contrasena del usuario de la base de datos synapse_user:"
read -s CONTRASENA

echo "Por favor, introduce la ip privada del servidor postgresql:"
read SERVIDOR


# Crear un nuevo archivo de configuracion de Matrix Synapse con los datos proporcionados
cat << EOF > /etc/matrix-synapse/homeserver.yaml
# Configuration file for Synapse
#
# This is a YAML file: see [1] for a quick introduction. Note in particular
# that *indentation is important*: all the elements of a list or dictionary
# should have the same indentation.
#
# [1] https://docs.ansible.com/ansible/latest/reference_appendices/YAMLSyntax.html
#
# For more information on how to configure Synapse, including a complete accounting of
# each option, go to docs/usage/configuration/config_documentation.md or
# https://element-hq.github.io/synapse/latest/usage/configuration/config_documentation.html
#
# This is set in /etc/matrix-synapse/conf.d/server_name.yaml for Debian installations.
# server_name: "SERVERNAME"
pid_file: "/var/run/matrix-synapse.pid"
listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    bind_addresses: ['::1', '0.0.0.0']
    resources:
      - names: [client, federation]
        compress: false
database:
  name: psycopg2
  args:
    user: synapse_user
    password: ${CONTRASENA}
    dbname: synapse
    host: ${SERVIDOR}
    cp_min: 5
    cp_max: 10
log_config: "/etc/matrix-synapse/log.yaml"
media_store_path: /var/lib/matrix-synapse/media
signing_key_path: "/etc/matrix-synapse/homeserver.signing.key"
trusted_key_servers:
  - server_name: "${DOMINIO}"
registration_shared_secret: "ynUUfPx3K7dCUtdm5KFcXAIRm64UlXan"
EOF


# Reiniciar Matrix Synapse para aplicar la configuracion
systemctl restart matrix-synapse
echo "El archivo de configuracion de Matrix Synapse se ha creado correctamente y el servicio ha sido reiniciado."


###### Creacion de usuarios dentro de matrix
# Bucle infinito que se detiene si el usuario responde "no"
while true; do
  # Aqui puedes colocar el comando que quieres ejecutar
  echo "Creacion de usuarios matrix"
  register_new_matrix_user -c /etc/matrix-synapse/homeserver.yaml https://rufinomatrix.duckdns.org

  # Pregunta al usuario si desea continuar
  read -p "¿Quieres seguir ejecutando el comando? (si/no): " respuesta

  # Evaluamos la respuesta
  if [ "$respuesta" == "no" ]; then
    echo "Saliendo del script..."
    break  # Sale del bucle y termina el script
  elif [ "$respuesta" == "si" ]; then
    echo "Repitiendo el comando..."
    clear
  else
    echo "Respuesta no valida. Por favor, responde 'si' o 'no'."
  fi
done




######### Finalizamos el script
fi