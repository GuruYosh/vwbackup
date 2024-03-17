#!/bin/bash

# DATOS CONTENEDOR Y BACKUP

ContainerName="bitwarden"
ContainerDataDir="/home/pi/docker/bitwarden/data/"
BackupDataDir="/home/pi/backup/"

# EMPAQUETADO Y COMPRESIÓN
# Algoritmos definidos y usados por el comando tar: gzip, bzip2, xz

CompressorList=("gzip" "bzip2" "xz")

CompressionType="xz"  # Patrón por defecto

# Directorios relativos (rel) o Ruta Absoluta (abs)
PathDirList=("rel" "abs")

PathDir="rel"

# ARCHIVO DE REGISTRO

ActiveLog=1  # Activamos el registro en el fichero log definido. 0=No,1=Si
LogFile="/var/log/vwbackup.log"
readonly msg_init="vwbackup | "

function loggger { echo "$(date +"%F %T")" "$1" >> "$LogFile"; }

###################

# COMPROBACIONES PREVIAS

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
