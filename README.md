![](https://github.com/GuruYosh/vwbackup/blob/main/resource/vwbackup_logo.png?raw=true)
# VWBackup

Realiza fácilmente una copia de seguridad de los datos del contenedor docker de [Vaultwarden](https://github.com/dani-garcia/vaultwarden).

:arrow_forward: Actualmente sólo soporta la instalación con SQLite :arrow_backward:

Es un script realizado en shell de *Bash* que, para su automatización, debería ejecutarse de manera periódica mediante una tarea en *cron* por ejemplo para posteriormente integrarlo en su sistema de copias de seguridad. Está diseñado únicamente para cumplir con mis propios requisitos de respaldo y como un mero ejercicio de programación de scripts en shell de Bash :relaxed:.

### Metodología

Para hacer una copia de seguridad de tu *vaultwarden* se sigue uno de los procedimientos explicados en su wiki "[Backing up your vault](https://github.com/dani-garcia/vaultwarden/wiki/Backing-up-your-vault)". Básicamente hay dos procedimientos según tengamos la base de datos sobre SQLite u otro gestor como MySQL o PostgreSQL. Copiar toda la carpeta de datos o bien copiar los datos excepto la base de datos y hacer un volcado de los datos de la base de datos junto con su estructura, sea SQLite, MySQL o PostgreSQL.

### Instalación de Vaultwarden con SQLite

En la instalación que nos ocupa los procedimientos posibles serían:
 1. Copiar toda la carpeta "**data**" con los datos que está montada como *volumen* de nuestro contenedor desplegado incluyendo los ficheros de SQLite. Por defecto son `db.sqlite3`, `db.sqlite3-shm` y `db.sqlite3-wal` y asegurarse de que la base de datos no esté en uso. Lo mejor para ello, parar temporalmente el contenedor.
 2. La otra opción es copiar igualmente la carpeta "**data**" sin los ficheros correspondientes a SQLite y hacer una copia de seguridad de la base de datos mediante el comando `.backup` del CLI de SQLite (`sqlite3`), recomendando igualmente que la base de datos no esté activa aunque 

En principio se usa la **opción 1** para realizar la copia de seguridad de todos los datos.

Características que permite el script:

 - Definición del nombre del contenedor, directorio donde están los datos de vaultwarden y directorio donde se guardarán las copias de seguridad.
 - Realiza compresión del archivo tar creado. Se admite compresión gzip, bzip2 y xz
 - Elegir entre una copia de datos relativa al directorio de datos o absoluta al directorio raiz (/)
 - Rotación de ficheros en el directorio de backups con el fin de mantener un número limitado de copias
 - Registro de eventos del script en un fichero determinado.

Futuro: podría elegirse si se quiere añadir un volcado de la base de datos a la carpeta donde se guardan los backup.

## Uso de VWBackup
El script contiene dos partes. Una de configuración previa y otra operacional del propio backup. Por otro lado, el script tiene un modo depuración que nos servirá para chequear los parámetros sin realizar el backup propiamente.
### Descarga
 - Descarga el script del repositorio.
```shell
wget https://raw.githubusercontent.com/GuruYosh/vwbackup/refs/heads/main/vwbackup.sh
```
 - Dale permisos de ejecución al script:
```shell
chmod u+x vwbackup.sh
```
> 4 -rw**x**r--r--  1 user group  485 mar 16 18:35 vwbackup.sh

 - Edita el script. Al comienzo del mismo tienes los parámetros que debes proporcionar.
 - Ejecuta el script con el modo depuración activado para evaluar los parámetros (-d o --debug)
 - Con cada ejecución del script se evaluan las dependecias obligatorias y opcionales del mismo para poder funcionar correctamente
 - Prueba que el script funciona y verifica el resultado.
 - Automatiza la ejecución del mismo mediante una tarea en cron, por ejemplo.
 

### **1. Configuración previa al backup**
Al comienzo del script existen una serie de parámetros obligatorios y opcionales. Edita el fichero `vwbackup.sh` con tu editor favorito y modifica los parámetros según tu instalación y necesidades.

| Parámetro | Nota | Ejemplo |
| -------------------|---------------------------------|-------------|
| ContainerName | Nombre del contenedor de Vaultwarden | vaultwarden |
| ContainerDataDir | Path del directorio donde están los datos del vaultwarden. El usuario que lanza el script debe tener permisos de lectura | "tu_directorio_docker/vaultwarden/data/"|
| BackupDataDir | Path del directorio donde se guardarán los ficheros del backup. El usuario que lanza el script debe tener permisos de escritura |"/home/user/backup/"|
|CompressionType|Algoritmo de compresión utilizado para comprimir el empaquetado de los ficheros de tar. Disponibles: gzip, bzip2 y xz| Por defecto se utiliza gzip|
|PathDir| Uso de ruta relativa o ruta absoluta al crear el backup *| Por defecto se utiliza la ruta relativa|
|LogFile| Ruta completa del fichero donde se hará el registro de eventos. El fichero debe estar creado y el usuario que lanza el script debe tener permisos de escritura. Si está vacío no hay registro de eventos.|/path_directorio_docker/vaultwarden/vwbackup.log/". Por defecto LogFile=""|
|MaxNumBackup|Rotación de backups. Mantiene un número determinado de ficheros en la carpeta de backups. El valor 0 se utilizará para no realizar rotación.|Por defecto será 0|

> **Ruta absoluta**: ruta completa de un archivo o directorio desde el directorio raíz.
> **Ruta relativa**: ruta de un archivo o directorio en relación con el directorio definido. Depende del directorio desde el cual se está ejecutando el comando.

### **2. Dependencias del script**

De igual manera y dado que para la ejecución correcta del script son necesarias ciertas aplicaciones/comandos accesibles en el sistema, estos se evalúan siempre al comienzo, dando un aviso y parando el script antes de continuar. Por su uso existen dos tipos. Las ***obligatorias*** o **requeridas** y las ***opcionales***.

**Aplicaciones requeridas**

: Es muy probable que ya estén instaladas en el sistema, pero nunca está de más revisarlo. Instálelas si faltasen. Dependiendo de la distribución Linux usada se hará de una u otra manera. Se indica como se llama el paquete a instalar

|Aplicación|Acción|Paquete| Enlace|
|--|--|--|--|
|docker|crear y gestionar contenedores y la virtualización|docker, docker-ce, docker.io|[https://www.docker.com/](https://www.docker.com/)|
|tar|empaquetado de archivos y directorios|tar|[https://www.gnu.org/software/tar/](https://www.gnu.org/software/tar/)|
|du|uso de disco|coreutils|[https://www.gnu.org/software/coreutils/manual/coreutils.html#du-invocation](https://www.gnu.org/software/coreutils/manual/coreutils.html#du-invocation)|

**Aplicaciones opcionales**
No son obligatorias, pero si necesarias para el funcionamiento del script. Ya que son las utilidades de compresión que se van a utilizar para comprimir el fichero *tar* deberán estar instaladas según desee configurar el script. En la mayoría de las distribuciones están instaladas. Si necesita instalar alguna el paquete necesario está indicado.

|Aplicación|Acción|Paquete| Enlace|
|--|--|--|--|
|OPCIONALES|Compresión de ficheros||
|gzip|-|gzip|[https://www.gnu.org/software/gzip/](https://www.gnu.org/software/gzip/)|
|bzip2|-|bzip2|[https://sourceforge.net/projects/bzip2/](https://sourceforge.net/projects/bzip2/)|
|xz|-|xz-utils|[https://tukaani.org/xz/](https://tukaani.org/xz/)|

### **2. Acceso al modo depuración o modo debug**

Para usar el modo depuración sólo hay que añadir el parámetro -d o --debug en la ejecución del script,

```shell
./vwbackup.sh --debug
```

Se evaluará la idoneidad de los parámetros, pero no se realizará el backup.

**Ejemplos**

Verificación sin errores

    pi@rpi4:~/scripts/backup $./vwbackup.sh  --debug
    vwbackup | 0.99
    ✔ Contenedor: vaultwarden
    ✔ Directorio de datos: "/home/pi/docker/vaultwarden/data/"
    ✔ Directorio de backup: "/home/pi/backup/"
    ✔ Tipo de compresión: "gzip"
    ✔ Tipo de ruta de empaquetado: "relativa"
    ✔ Rotación de backups: Si. Núm. de Ficheros: 3
    ✔ Registro de eventos: Si
    ✔ Fichero de registro: "/home/pi/docker/vaultwarden/vwbackup.log"

    Parece que la configuración no tiene ningún error aparente :) BACKING UP!!
    
Verificación con varios errores:

    pi@rpi4:~/scripts/backup $./vwbackup.sh  -d
    vwbackup | 0.99
    ✘ Contenedor: "vaultwwwarden" no creado
    ✘ Directorio de datos: "/home/pi/docker/vaultwarden/datos/" no existe
    ✔ Directorio de backup: "/home/pi/backup/" | ✘ Sin permisos de escritura 
    ✔ Tipo de compresión: "gzip"
    ✘ Tipo de ruta de empaquetado: "relativa3" no definida. Tipos válidos: relativa absoluta
    ✔ Rotación de backups: No
    ✔ Registro de eventos: No
    
    La configuración inicial contiene errores (4)

### **3. Ejecución del script**

Una vez revisados los parámetros proporcionados se realiza la copia de seguridad. Los pasos para realizarlo son los siguientes:

 1. Parar el contenedor de *vaultwarden* si este está en ejecución en el sistema.
 2. Se realiza el *empaquetado* y *compresión* de los ficheros que intervienen en el mismo (*ContainerDataDir*) mediante el comando *tar*, se comprime con el compresor elegido y se lleva al directorio elegido (*BackupDataDir*). Por defecto se utiliza *gzip* por ser el más común. Elige en los parámetros el que quieras de entre los disponibles.
 3. Arranca nuevamente el contenedor de *vaultwarden* si estuvo en ejecución.

### **4. Automatización del script y de las copias de seguridad**

Forma parte del mantenimiento de tu sistema. Puedes automatizar la ejecución diaria del mismo (*cron*) y mantener, por ejemplo, las últimas 7 copias y de la misma forma incluir tu copia de seguridad de *vaultwarden* en tu sistema de respaldos. Ya sabes la regla 3 ... 2 ... 1 :bomb::collision: ( [G](https://www.google.com/search?q=regla%203%202%201%20backup) [B](https://www.bing.com/search?q=regla%203%202%201%20backup) [D](https://duckduckgo.com/?t=ffab&q=regla+3+2+1+backup) )

### **5. Restauración de una copia de seguridad**
- Este es un ejemplo que asume que estas usando *gzip* por ser el más común.
#### Extracción
- Solo debes ejecutar este comando
```shell
tar -xvf archivo.tar.gz -C /ruta/data
```
- donde:
> `archivo.tar.gz` es el nombre del archivo del backup, y `/ruta/data` es la carpeta destino donde se va a depositar el contenido
- Ejemplo:
```shell
tar -xvf vaultwarden_20240929201852.tar.gz -C ../test/
```
#### Visualizar contenido
Si deseas visualizar el contenido de un respaldo, sin tener que extraer el contenido, puedes hacerlo de la sigueinte manera:
```shell
tar -tf vaultwarden_20240929201852.tar.gz
```

## Contacto

Si prefieres charlar, normalmente estamos en Telegram en el grupo **[Vaultwarden ES](https://t.me/vaultwarden_es)**. ¡Únete a nosotros!

Una pregunta, sugerencias o nuevas funciones o para obtener ayuda[ \[Discusiones de GitHub\]](https://github.com/GuruYosh/vwbackup/discussions).

Si detectas algún error o fallo en VWBackup, [abre una incidencia](https://github.com/GuruYosh/vwbackup/issues) (Issues).
