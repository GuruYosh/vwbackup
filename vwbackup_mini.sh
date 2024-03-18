#!/bin/bash

# PARÁMETROS PARA DEFINIR FUNCIONAMIENTO DEL BACKUP

# Nombre del contenedor vaultwarden
ContainerName="bitwarden"

# Path del directorio donde se guardan los datos del contenedor
ContainerDataDir="/home/pi/docker/bitwarden/data/"

# Path del directorio donde se guardará el backup de los datos
BackupDataDir="/home/pi/backup/"

# PARÁMETROS OPCIONALES. NO HACE FALTA CONFIGURAR

# Algoritmo de compresión usado al comprimir el tar
CompressionType="gzip"  # Disponibles: gzip, bzip2 o xz

# Uso de directorios relativos o path absoluto en el backup
# Disponibles: rel (relativo) o abs (absoluto)
PathDir="rel"

# REGISTRO DE OPERACIONES (LOGS)
# Activamos el registro en el fichero log definido. 0=No,1=Si
ActiveLog=0
# Fichero log donde se guardará el registro. Debe ser accesible y escribible por el script
LogFile="/var/log/vwbackup.log"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# FIN DE PARÁMETROS
#
#     No toques a partir de aquí si no sabes :)
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Algoritmos definidos y usados por el comando tar: gzip, bzip2, xz
readonly CompressorList=("gzip" "bzip2" "xz")

# Directorios relativos (rel) o Ruta Absoluta (abs)
readonly PathDirList=("rel" "abs")

# Cabecera de los mensajes
readonly msg_init="vwbackup | "

# Función para loguear en fichero definido
function loggger { echo "$(date +"%F %T")" "$1" >> "$LogFile"; }

# COMPROBACIONES PREVIAS Y ERRORES

error=0

if ! docker inspect --format='{{.Created}}' "${ContainerName}" > /dev/null 2>&1; then
	echo "${msg_init}El contenedor ${ContainerName} no está creado"
	((error++))
fi

! [[ -d "${ContainerDataDir}" ]] &&  echo "${msg_init}${ContainerDataDir} no existe" && ((error++))
! [[ -r "${ContainerDataDir}" ]] &&  echo "${msg_init}${ContainerDataDir} ::: no tiene permiso de lectura" && ((error++))
! [[ -d "${BackupDataDir}" ]] &&  echo "${msg_init}${BackupDataDir} no existe" && ((error++))
! [[ -w "${BackupDataDir}" ]] &&  echo "${msg_init}${BackupDataDir} ::: no tiene permisos de escritura" && ((error++))

! [[ " ${CompressorList[*]} " =~ " ${CompressionType} " ]] && echo "${msg_init}Error. \"${CompressionType}\" no es un tipo de compresión válido. Tipos válidos: ${CompressorList[*]}" && ((error++))
! [[ " ${PathDirList[*]} " =~ " ${PathDir} " ]] && echo "${msg_init}Error. \"${PathDir}\" no es un tipo definido de uso de rutas al empaquetar. Tipos válidos: ${PathDirList[*]}"  && ((error++))

if [[ "${ActiveLog}" -eq 1 ]]; then
	! [[ -e "${LogFile}" ]] &&  echo "${msg_init}${LogFile} no existe" && ((error++))
	! [[ -w "${LogFile}" ]] &&  echo "${msg_init}${LogFile} ::: no tiene permisos de escritura" && ((error++))
fi

[[ ${error} -ge 1 ]] && ( echo "Se han producido uno o más errores en la configuración de datos iniciales (${error})"; exit 1 )

# Controla si el contenedor estaba en ejecución antes del backup para pararlo y arracarlo posteriormente
ContainerWasRunning=0

# Paramos contenedor si estuviera ejecutándose

if docker ps  --format '{{.Names}}' | grep -q "^${ContainerName}\$"; then
	docker stop "${ContainerName}" > /dev/null 2>&1
	ContainerWasRunning=1
fi

# Empaquetamos y comprimimos directorio

case "${CompressionType}" in
	"gzip") 	CompressionOption="z"; FileExtension="tgz";;
	"bzip2")	CompressionOption="j"; FileExtension="tbz";;
	"xz")		CompressionOption="J"; FileExtension="txz";;
esac

# Nombre que tendrá el fichero con el backup
BackupDataFile="${BackupDataDir}${ContainerName}_`date +%Y%m%d%H%M%S`.${FileExtension}"

case "${PathDir}" in
	"rel")	tar -c"${CompressionOption}"f "${BackupDataFile}" -C "${ContainerDataDir}" . > /dev/null 2>&1;;
	"abs")	tar -c"${CompressionOption}"f "${BackupDataFile}" "${ContainerDataDir}" > /dev/null 2>&1;;
esac

#[ $? ] && echo "tar.gz sin errores"

# Arrancamos contenedor si estaba en ejecución

if [ $ContainerWasRunning -eq 1 ]; then
	docker start ${ContainerName} > /dev/null 2>&1
fi
