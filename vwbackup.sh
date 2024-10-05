#!/bin/bash

########################################################################################
# VWBACKUP v1.1
# Realiza una copia de seguridad de los datos del contenedor docker de Vaultwarden
# 
# Más información:
#		GitHub: https://github.com/GuruYosh/vwbackup
#		Telegram: https://t.me/vaultwarden_es
# ######################################################################################

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

		# REGISTRO DE OPERACIONES/EVENTOS (LOGS)
		# Si LogFile se deja vacío no se realizará registro. Debe ser accesible y escribible por el script
		# No se crea por defecto
		LogFile="/path_to_directory/vaultwarden/vwbackup.log"

		#Rotación de backup
		MaxNumBackup=0 # 0=No hay rotación n=Rotación de n ficheros


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# FIN DE PARÁMETROS
#
#     No toques a partir de aquí si no sabes :)
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Nombre / Versión del script de backup
readonly ScriptName="vwbackup"
readonly ScriptVersion="1.1" # alfa \u03B1 beta \u03B2

# Algoritmos definidos y usados por el comando tar: gzip, bzip2, xz
# Extensiones según algoritmo usado en comando tar
declare -rA Compressor=(
    ["gzip"]="z gz"
    ["bzip2"]="j bz2"
    ["xc"]="J xz"
)

# Directorios relativos (rel) o Ruta Absoluta (abs)
readonly PathDirList="relativa absoluta"

# Cabecera de los mensajes
readonly msg_init="${ScriptName} | "

# Caracteres especiales
readonly gCheck="\e[32m✔\e[0m" # Check verde
readonly rCross="\e[31m✘\e[0m" # Aspa roja

# Función para loguear en fichero definido
function loggger { echo "$(date +"%F %T")" "$1" >> "$LogFile"; }

# COMPROBACIONES PREVIAS Y ERRORES

# Aplicaciones instaladas obligatorias (requeridas) y opcionales para el funcionamiento del script

readonly cmdRequired=("docker" "tar" "du")  # necesarias
readonly cmdOptional=("gzip" "bzip2" "xz")  # opcionales según elijamos en la configuración

cmdRequiredError=()
cmdOptionalError=()
appError=0

for cmd in "${cmdRequired[@]}"; do
    if ! [ "$(which "${cmd}")" ]; then cmdRequiredError+=("${cmd}"); appError=1; fi
done
for cmd in "${cmdOptional[@]}"; do
    if ! [ "$(which "${cmd}")" ]; then cmdOptionalError+=("${cmd}"); appError=1; fi
done

if [[ $appError -eq 1 ]]; then
	echo -e "${ScriptName} | ${ScriptVersion}" 
	echo "ERRORES DE DEPENDENCIA"
	[[ ${#cmdRequiredError[@]} -ne 0 ]] && echo -e "${rCross} Aplicaciones REQUERIDAS: ${cmdRequiredError[@]} (\e[31mInstálelas según su OS\e[0m)" || echo -e "${gCheck} Aplicaciones REQUERIDAS: ${cmdRequired[@]} (\e[32mNo se requiere acción\e[0m)"
	[[ ${#cmdOptionalError[@]} -ne 0 ]] && echo -e "${rCross} Aplicaciones OPCIONALES: ${cmdOptionalError[@]} (\e[31mRevise e instale si son necesarias para su configuración\e[0m)" || echo -e "${gCheck} Aplicaciones OPCIONALES: ${cmdOptional[@]} (\e[32mNo se requiere acción\e[0m)"

	echo -e "\nLa ejecución del script no seguirá hasta haber resuelto los errores de dependencia de las aplicaciones REQUERIDAS."
	echo -e "> > > > > > > \e[31mFIX IT & ENJOY !!\e[0m"
	exit 100
fi

# Modo Debug sólo para ver si todo está "bien" configurado aparentemente

DebugMode=0

[[ "${1}" == "-d" || "${1}" == "--debug" ]] && DebugMode=1

# Registro de Eventos
if [[ -z "${LogFile}" ]]; then ActiveLog=0; else ActiveLog=1; fi

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

if [[ -z "${Compressor["$CompressionType"]}" ]]; then errortype+="c"; fi

if ! [[ " ${PathDirList} " =~ " ${PathDir} " ]]; then errortype+="p"; fi

if [[ ${ActiveLog} -eq 1 ]]; then
	if ! [[ -f "${LogFile}" ]]; then errortype+="l"; fi
	
	if ! [[ "${errortype}" =~ "l" ]]; then
		if ! [[ -w "${LogFile}" ]]; then errortype+="L"; fi
	fi
fi

if ! [[ "$MaxNumBackup" =~ ^(0|[1-9][0-9]*)$ && "$MaxNumBackup" -ge 0 ]]; then errortype+="n"; fi

if [[ ${DebugMode} -eq 1 || ${#errortype} -ge 1 ]]; then

	msg=""

	echo -e "${ScriptName} | ${ScriptVersion}"

	[[ "${errortype}" =~ "r" ]] && msg+="${rCross} Contenedor: \"${ContainerName}\" no creado\n" || msg+="${gCheck} Contenedor: ${ContainerName}\n"

	[[ "${errortype}" =~ "d" ]] && msg+="${rCross} Directorio de datos: \"${ContainerDataDir}\" no existe" || msg+="${gCheck} Directorio de datos: \"${ContainerDataDir}\""
	[[ "${errortype}" =~ "D" ]] && msg+=" | ${rCross} Sin permisos de lectura\n" || msg+="\n"

	[[ "${errortype}" =~ "b" ]] && msg+="${rCross} Directorio de backup: \"${BackupDataDir}\" no existe" || msg+="${gCheck} Directorio de backup: \"${BackupDataDir}\""
	[[ "${errortype}" =~ "B" ]] && msg+=" | ${rCross} Sin permisos de escritura \n" || msg+="\n"

	[[ "${errortype}" =~ "c" ]] && msg+="${rCross} Tipo de compresión: \"${CompressionType}\" no válido. Tipos válidos: ${!Compressor[*]}\n" || msg+="${gCheck} Tipo de compresión: \"${CompressionType}\"\n"
	[[ "${errortype}" =~ "p" ]] && msg+="${rCross} Tipo de ruta de empaquetado: \"${PathDir}\" no definida. Tipos válidos: ${PathDirList}\n" || msg+="${gCheck} Tipo de ruta de empaquetado: \"${PathDir}\"\n"

	if [[ "${errortype}" =~ "n" ]]; then
		msg+="${rCross} Rotación de backups: Parámetro \"${MaxNumBackup}\" erróneo. Debe ser 0 (sin rotación) o un valor positivo\n"
	else
		msg+="${gCheck} Rotación de backups: "
		[[ "${MaxNumBackup}" -eq 0 ]] &&  msg+="No\n" || msg+="Si. Núm. de Ficheros: ${MaxNumBackup}\n"
	fi


	if [[ ${ActiveLog} -eq 1 ]]; then
		msg+="${gCheck} Registro de eventos: Si\n"
		[[ "${errortype}" =~ "l" ]] && msg+="${rCross} Fichero de registro: \"${LogFile}\" no existe o no es un archivo" || msg+="${gCheck} Fichero de registro: \"${LogFile}\""
		[[ "${errortype}" =~ "L" ]] && msg+=" | ${rCross} Sin permisos de escritura \n" || msg+="\n"
	elif [[ ${ActiveLog} -eq 0 ]]; then
		msg+="${gCheck} Registro de eventos: No\n"	
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
	if docker stop "${ContainerName}" > /dev/null 2>&1; then
		ContainerWasRunning=1
		[[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Contenedor ${ContainerName} parado"
	else
		[[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Error al parar contenedor ${ContainerName}"
	fi
else
	[[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}El contenedor ${ContainerName} no está corriendo"
fi

# Empaquetamos y comprimimos directorio

# Características para lanzar tar
CompressionMod="${Compressor["${CompressionType}"]%% *}"
CompressionExt="${Compressor["${CompressionType}"]##* }"

# Nombre del fichero con el backup
BackupDataFile="${BackupDataDir%%/}/${ContainerName}_$(date +%Y%m%d%H%M%S).tar.${CompressionExt}"

PathRelMod=""  # Modificador de path relativo
PathRelDir=""  # "." para todos los ficheros del path relativo

if [[ "${PathDir}" == "relativa" ]]; then PathRelMod="-C"; PathRelDir="."; fi

if tar -c"${CompressionMod}"f "${BackupDataFile}" ${PathRelMod} "${ContainerDataDir%%/}/" "${PathRelDir}" > /dev/null 2>&1; then
	if [[ "${ActiveLog}" -eq 1 ]]; then
		loggger "${msg_init}Backup realizado correctamente en ${BackupDataFile}"
		# Tamaño del fichero
		DiskSpaceFile=$(du -sh "${BackupDataFile}" | cut -f1 )
		loggger "${msg_init}Tamaño del respaldo: ${DiskSpaceFile}"
	fi
else 
	[[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Error al realizar backup en ${BackupDataFile}"
fi

# Rotación de backups. Se dejan los últimos MaxNumBackup ficheros si > 0

if [[ "${MaxNumBackup}" -ge 1 ]]; then
	if cd "${BackupDataDir}" > /dev/null 2>&1; then
		#rm $(ls -t ${ContainerName}_*.* | awk "NR>${MaxNumBackup}")
		BackupFiles=$(ls -t ${ContainerName}_*.*)
		Files2Delete=$(echo "${BackupFiles}" | awk "NR>${MaxNumBackup}")
		NumFilesDeleted=$(echo "$Files2Delete" | wc -w)
		if [[ ${NumFilesDeleted} -ge 1 ]]; then
			if rm --interactive=never ${Files2Delete} > /dev/null 2>&1; then
				[[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Rotación de backup: ${NumFilesDeleted} fichero/s borrado/s"
			else
				[[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Error al borrar ficheros en rotación de backups"
			fi
		fi
	else
		[[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Error al moverse a ${BackupDataDir}"
	fi
fi

# Logueamos espacio del directorio de backup

if [[ "${ActiveLog}" -eq 1 ]]; then
	DU_output=$(du -ch ${BackupDataDir}/${ContainerName}_*)
	DiskSpaceDir=$(echo "${DU_output}" | grep total | cut -f1)
	NumFilesInBackup=$(echo "${DU_output}" | grep -c ${ContainerName})
	loggger "${msg_init}Tamaño de ${BackupDataDir}: ${DiskSpaceDir} - ${NumFilesInBackup} archivos (Rotación: ${MaxNumBackup})"
fi

# Arrancamos contenedor si estaba en ejecución

if [[ ${ContainerWasRunning} -eq 1 ]]; then
	if docker start ${ContainerName} > /dev/null 2>&1; then
		[[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Arrancando contenedor ${ContainerName}"
	else
		[[ "${ActiveLog}" -eq 1 ]] && loggger "${msg_init}Error al arrancar contenedor ${ContainerName}"
	fi
fi
