# VWBackup

Realiza fácilmente una copia de seguridad de los datos del contenedor docker de [Vaultwarden](https://github.com/dani-garcia/vaultwarden)

Para hacer una copia de seguridad de tu vaultwarden se sigue uno de los procedimientos explicados en su wiki "[Backing up your vault](https://github.com/dani-garcia/vaultwarden/wiki/Backing-up-your-vault)". Básicamente hay dos procedimientos según tengamos la base de datos sobre SQLite u otro gestor como MySQL o PostgreSQL.

## Instalación de Vaultwarden con SQLite

Los procedimientos posibles serían:
 1. Copiar toda la carpeta "**data**" con los datos que está montada como *volumen* de nuestro contenedor desplegado incluyendo los ficheros de SQLite. Por defecto son `db.sqlite3`, `db.sqlite3-shm` y `db.sqlite3-wal` y asegurarse de que la base de datos no esté en uso. Lo mejor para ello, parar temporalmente el contenedor.
 2. La otra opción es copiar igualmente la carpeta "**data**" sin los ficheros correspondientes a SQLite y hacer una copia de seguridad de la base de datos mediante el comando `.backup` del CLI de SQLite (`sqlite3`), recomendando igualmente que la base de datos no esté activa aunque 
