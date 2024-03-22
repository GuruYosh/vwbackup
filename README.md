

# VWBackup

Realiza fácilmente una copia de seguridad de los datos del contenedor docker de [Vaultwarden](https://github.com/dani-garcia/vaultwarden).
:arrow_forward: Actualmente sólo soporta la instalación con SQLite :arrow_backward:
Para hacer una copia de seguridad de tu vaultwarden se sigue uno de los procedimientos explicados en su wiki "[Backing up your vault](https://github.com/dani-garcia/vaultwarden/wiki/Backing-up-your-vault)". Básicamente hay dos procedimientos según tengamos la base de datos sobre SQLite u otro gestor como MySQL o PostgreSQL. Copiar toda la carpeta de datos o bien copiar los datos excepto la base de datos y hacer un volcado de los datos de la base de datos junto con su estructura, sea SQLite, MySQL o PostgreSQL.

## Instalación de Vaultwarden con SQLite

Los procedimientos posibles serían:
 1. Copiar toda la carpeta "**data**" con los datos que está montada como *volumen* de nuestro contenedor desplegado incluyendo los ficheros de SQLite. Por defecto son `db.sqlite3`, `db.sqlite3-shm` y `db.sqlite3-wal` y asegurarse de que la base de datos no esté en uso. Lo mejor para ello, parar temporalmente el contenedor.
 2. La otra opción es copiar igualmente la carpeta "**data**" sin los ficheros correspondientes a SQLite y hacer una copia de seguridad de la base de datos mediante el comando `.backup` del CLI de SQLite (`sqlite3`), recomendando igualmente que la base de datos no esté activa aunque 

En principio se usa la **opción 1** para realizar la copia de seguridad de todos los datos. Próximamente se podrá elegir si se quiere añadir un volcado de la base de datos a la carpeta donde se guardan los backup.

## Uso de VWBackup
El script contiene dos partes. Una de configuración previa y otra operacional del propio backup. Por otro lado, el script tiene un modo depuración que nos servirá para chequear los parámetros sin realizar el backup propiamente.

Una vez descargado el script recuerda darle permisos de ejecución:

> chmod u+x vwbackup.sh
> 4 -rw**x**r--r--  1 user group  485 mar 16 18:35 vwbackup.sh


**1. Configuración previa del backup**.  Al comienzo del script existen una serie de parámetros obligatorios y opcionales. Edita el fichero `vwbackup.sh` con tu editor favorito y modifica los parámetros según tu instalación y necesidades.

| Parámetro | Nota | Ejemplo |
| -------------------|---------------------------------|-------------|
| ContainerName | Nombre del contenedor de Vaultwarden | vaultwarden |
| ContainerDataDir | Path del directorio donde están los datos del vaultwarden | "tu_directorio_docker/vaultwarden/data/"|
| BackupDataDir | Path del directorio donde se guardarán los ficheros del backup |"/home/user/backup/"|
|CompressionType|Algoritmo de compresión utilizado para comprimir el empaquetado de los ficheros de tar. Disponibles: gzip, bzip2 y xz| Por defecto se utiliza gzip|
|PathDir| Uso de ruta relativa o ruta absoluta al crear en el backup| Por defecto se utiliza la ruta relativa|
|ActiveLog|Si queremos registro de eventos en un fichero log definido (LogFile). Parámetros disponible 0=No,1=Si| Por defecto será 0|
|LogFile| Ruta completa del fichero donde se hará el registro de eventos. El fichero debe estar creado y el usuario que lanza el script debe tener permisos de escritura. Si ActiveLog=0 no se necesita y puede estar vacío.| "/path_directorio_docker/vaultwarden/vwbackup.log/"|

**2. Acceso al modo depuración o modo debug**
Para usar el modo depuración sólo hay que añadir el parámetro -d o --debug en la ejecución del script

> ./vwbackup.sh --debug

Se evaluará la idoneidad de los parámetros, pero no se realizará el backup. De igual manera en cada ejecución sin modo debug también se evaluan los parámetros. 
