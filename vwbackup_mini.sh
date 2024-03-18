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
CompressionType="xz"  # Disponibles: gzip, bzip2 o xz

# Uso de directorios relativos o path absoluto en el backup
# Disponibles: rel (relativo) o abs (absoluto)
PathDir="abs"

# REGISTRO DE OPERACIONES (LOGS)
# Activamos el registro en el fichero log definido. 0=No,1=Si
ActiveLog=1
# Fichero log donde se guardará el registro. Debe ser accesible y escribible por el script
LogFile="/var/log/vwbackup.log"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# FIN DE PARÁMETROS
#
#     No toques a partir de aquí si no sabes :)
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Algoritmos definidos y usados por el comando tar: gzip, bzip2, xz
declare -A CompressorOptions=(
	["gzip"]="z"
	["bzip2"]="j"
	["xz"]="J"
)

# Extensiones según algoritmo usado en comando tar
declare -A FileExtensions=(
    ["gzip"]="tar.gz"
	["bzip2"]="tar.bz2"
	["xz"]="tar.xz"
)

# Directorios relativos (rel) o Ruta Absoluta (abs)
readonly PathDirList="rel abs"

# Nombre del script de backup
readonly ScriptName="vwbackup"

# Cabecera de los mensajes
readonly msg_init="${ScriptName} | "

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

[[ -z "${CompressorOptions["$CompressionType"]}" ]] && echo "${msg_init}Error. \"${CompressionType}\" no es un tipo de compresión válido. Tipos válidos: ${!CompressorOptions[*]}" && ((error++))
! [[ " ${PathDirList} " =~ " ${PathDir} " ]] && echo "${msg_init}Error. \"${PathDir}\" no es un tipo definido de uso de rutas al empaquetar. Tipos válidos: ${PathDirList}"  && ((error++))

if [[ "${ActiveLog}" -eq 1 ]]; then
	! [[ -e "${LogFile}" ]] &&  echo "${msg_init}${LogFile} no existe" && ((error++))
	! [[ -w "${LogFile}" ]] &&  echo "${msg_init}${LogFile} ::: no tiene permisos de escritura" && ((error++))
fi

[[ ${error} -ge 1 ]] && ( echo "Se han producido uno o más errores en la configuración de datos iniciales (${error})"; exit 1 )


[[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Comenzado backup de ${ContainerName}"

# Controla si el contenedor estaba en ejecución antes del backup para pararlo y arracarlo posteriormente
ContainerWasRunning=0

# Paramos contenedor si estuviera ejecutándose

if docker ps  --format '{{.Names}}' | grep -q "^${ContainerName}\$"; then
	docker stop "${ContainerName}" > /dev/null 2>&1	
	ContainerWasRunning=1
	[[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Parando contenedor ${ContainerName}"
fi

# Empaquetamos y comprimimos directorio


# Nombre que tendrá el fichero con el backup
BackupDataFile="${BackupDataDir}${ContainerName}_$(date +%Y%m%d%H%M%S).${FileExtensions["${CompressionType}"]}"

case "${PathDir}" in
	"rel")	tar -c"${CompressorOptions["${CompressionType}"]}"f "${BackupDataFile}" -C "${ContainerDataDir}" . > /dev/null 2>&1
			[[ $? -eq 0 ]] && [[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Backup realizado en ${BackupDataFile}"
			;;
	"abs")	tar -c"${CompressorOptions["${CompressionType}"]}"f "${BackupDataFile}" "${ContainerDataDir}" > /dev/null 2>&1
			[[ $? -eq 0 ]] && [[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Backup realizado en ${BackupDataFile}"
			;;
esac

#[ $? ] && echo "tar.gz sin errores"

# Arrancamos contenedor si estaba en ejecución

if [ $ContainerWasRunning -eq 1 ]; then
	docker start ${ContainerName} > /dev/null 2>&1
	[[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Arrancando contenedor ${ContainerName}"
fi
