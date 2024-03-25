#!/bin/bash

# PARÁMETROS PARA DEFINIR FUNCIONAMIENTO DEL BACKUP

		# Nombre del contenedor vaultwarden
		ContainerName="vaultwarden"

		# Path del directorio donde se guardan los datos del contenedor
		ContainerDataDir="/path_to_directory/vaultwarden/data/"

		# Path del directorio donde se guardará el backup de los datos
		BackupDataDir="/path_to_directory/backup/"

		# PARÁMETROS OPCIONALES. NO HACE FALTA CONFIGURAR

		# Algoritmo de compresión usado al comprimir el tar
		# Disponibles: gzip, bzip2 o xz
		CompressionType="gzip"

		# Uso de ruta relativa o ruta absoluta al crear en el backup
		# Disponibles: relativa, absoluta
		PathDir="relativa"

		# REGISTRO DE OPERACIONES (LOGS)
		# Activamos el registro en el fichero log definido. 0=No,1=Si
		ActiveLog=0
		# Fichero log existente donde se guardará el registro. Debe ser accesible y escribible por el script
		# No se crea por defecto
		LogFile="/path_to_directory/vaultwarden/vwbackup.log"

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
readonly PathDirList="relativa absoluta"

# Nombre del script de backup
readonly ScriptName="vwbackup"
readonly ScriptVersion="0.99" # alfa \u03B1 beta \u03B1

# Cabecera de los mensajes
readonly msg_init="${ScriptName} | "

# Función para loguear en fichero definido
function loggger { echo "$(date +"%F %T")" "$1" >> "$LogFile"; }

# COMPROBACIONES PREVIAS Y ERRORES

# Modo Debug sólo para ver si todo está "bien" configurado aparentemente

DebugMode=0

[[ "${1}" == "-d" || "${1}" == "--debug" ]] && DebugMode=1

# Recogemos los errores que se encuentren en la configuración
errortype=""

if ! docker inspect --format='{{.Created}}' "${ContainerName}" > /dev/null 2>&1; then errortype+="r"; fi

if ! [[ -d "${ContainerDataDir}" ]]; then errortype+="d"; fi

if ! [[ "${errortype}" =~ "d" ]]; then
	if ! [[ -r "${ContainerDataDir}" ]]; then errortype+="D"; fi
fi

if ! [[ -d "${BackupDataDir}" ]]; then errortype+="b"; fi

if ! [[ "${errortype}" =~ "b" ]]; then
	if ! [[ -w "${BackupDataDir}" ]]; then errortype+="B"; fi
fi

if [[ -z "${CompressorOptions["$CompressionType"]}" ]]; then errortype+="c"; fi

if ! [[ " ${PathDirList} " =~ " ${PathDir} " ]]; then errortype+="p"; fi

if ! [[ "${ActiveLog}" =~ ^[01]$ ]]; then errortype+="a"; fi

if ! [[ "${errortype}" =~ "a" ]]; then
	if [[ ${ActiveLog} -eq 1 ]]; then
		if ! [[ -f "${LogFile}" ]]; then errortype+="l"; fi
		
		if ! [[ "${errortype}" =~ "l" ]]; then
			if ! [[ -w "${LogFile}" ]]; then errortype+="L"; fi
		fi
	fi
fi

if [[ ${DebugMode} -eq 1 || ${#errortype} -ge 1 ]]; then

	msg=""
	gCheck="\e[32m✔\e[0m" # Check verde
	rCross="\e[31m✘\e[0m" # Aspa roja

	echo -e "${ScriptName} | ${ScriptVersion}"

	[[ "${errortype}" =~ "r" ]] && msg+="${rCross} Contenedor: \"${ContainerName}\" no creado\n" || msg+="${gCheck} Contenedor: ${ContainerName}\n"

	[[ "${errortype}" =~ "d" ]] && msg+="${rCross} Directorio de datos: \"${ContainerDataDir}\" no existe" || msg+="${gCheck} Directorio de datos: \"${ContainerDataDir}\""
	[[ "${errortype}" =~ "D" ]] && msg+=" | ${rCross} Sin permisos de lectura\n" || msg+="\n"

	[[ "${errortype}" =~ "b" ]] && msg+="${rCross} Directorio de backup: \"${BackupDataDir}\" no existe" || msg+="${gCheck} Directorio de backup: \"${BackupDataDir}\""
	[[ "${errortype}" =~ "B" ]] && msg+=" | ${rCross} Sin permisos de escritura \n" || msg+="\n"

	[[ "${errortype}" =~ "c" ]] && msg+="${rCross} Tipo de compresión: \"${CompressionType}\" no válido. Tipos válidos: ${!CompressorOptions[*]}\n" || msg+="${gCheck} Tipo de compresión: \"${CompressionType}\"\n"
	[[ "${errortype}" =~ "p" ]] && msg+="${rCross} Tipo de ruta de empaquetado: \"${PathDir}\" no definida. Tipos válidos: ${PathDirList}\n" || msg+="${gCheck} Tipo de ruta de empaquetado: \"${PathDir}\"\n"

	if [[ "${errortype}" =~ "a" ]]; then
		msg+="${rCross} Registro de eventos: Error. Valores válidos: 0 (no), 1 (si)"
	else
		if [[ ${ActiveLog} -eq 1 ]]; then
			msg+="${gCheck} Registro de eventos: Si\n"
			[[ "${errortype}" =~ "l" ]] && msg+="${rCross} Fichero de registro: \"${LogFile}\" no existe" || msg+="${gCheck} Fichero de registro: \"${LogFile}\""
			[[ "${errortype}" =~ "L" ]] && msg+=" | ${rCross} Sin permisos de escritura \n" || msg+="\n"
		elif [[ ${ActiveLog} -eq 0 ]]; then
			msg+="${gCheck} Registro de eventos: No\n"	
		fi
	fi
	echo -e "${msg}"

	if [[ ${#errortype} -eq 0 ]]; then
		echo -e "Parece que la configuración no tiene ningún error aparente :) BACKING UP!!"
		exit 0
	else
		echo -e "La configuración inicial contiene errores (${#errortype})"
		exit 1
	fi
fi


## EN MARCHA !!!!

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

BackupDataFile="${BackupDataDir%%/}/${ContainerName}_$(date +%Y%m%d%H%M%S).${FileExtensions["${CompressionType}"]}"

case "${PathDir}" in
	"relativa")	tar -c"${CompressorOptions["${CompressionType}"]}"f "${BackupDataFile}" -C "${ContainerDataDir%%/}/" . > /dev/null 2>&1
				[[ $? -eq 0 ]] && [[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Backup realizado en ${BackupDataFile}"
				;;
	"absoluta")	tar -c"${CompressorOptions["${CompressionType}"]}"f "${BackupDataFile}" "${ContainerDataDir}" > /dev/null 2>&1
				[[ $? -eq 0 ]] && [[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Backup realizado en ${BackupDataFile}"
				;;
esac

# Arrancamos contenedor si estaba en ejecución

if [ $ContainerWasRunning -eq 1 ]; then
	docker start ${ContainerName} > /dev/null 2>&1
	[[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Arrancando contenedor ${ContainerName}"
fi
