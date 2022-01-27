# Rinodesync

Rinodesync se utiliza para sincronizar archivos entre dos equipos, utilizando *ssh*, teniendo en cuenta la modificación de nombres e inodos en el destino local.

El script `rinodesync.sh` crea un archivho `.shadow_sync`en donde mantiene una tabla con el nombre del archivo, el inodo remoto y el inodo local. De esta manera puede verificar si el archivo fue renombrado en el equipo remoto y renombrarlo localmente para que al momento de utilizar `rsync` no se modifique el numero de inodo local. Esto es util para que aplicaciones *harvester* como *Filebeat* puedan leer los archivos y controlar la rotación de estos basándose en su numero de inodo, sin generar duplicados ni perdida de información entre la rotación y la sincronización. 


### Uso: 
El script se ejecuta manualmente, pero es recomendable configurar un cron para generar una actualización de logs con la frecuencia necesaria.

#### Archivos
 
- rindosync.sh: Script de sincronización.
- rinodesync.conf: Configuraciones de conexión y paths. 
- files.lst: Lista de archivos que serán sincronizados.

<div style="page-break-after: always;"></div>

### Ejemplo:

Variables 

* Inodo R = inodo remoto
* Inodo L = inodo local
* FLIST = Lista de archivos (`app.log`,`app-1.log`,`app-2.log`)
* SSHKEY = llave ssh
* RUSER = usuario remoto
* RHOST = servidor remoto
* RPATH = Path remoto
* SCRIPTPATH = Path del script en donde se copiaran los logs

1. Se ejecuta el script por primera ves y genera el `.shadow_sync` utilizando `stat -c '%i' ` para luego correr `rsync -avt --inplace --files-from=$FLIST -e "ssh -q -T -i $SSHKEY" $RUSER@$RHOST:$RPATH/ $SCRIPTPATH/`. El `.shadow_sync`: 

	| Nombre    | Indodo R | Inodo L |
	|:---------:|:--------:|:-------:|
	| app.log   | 2003     | 100     |
	| app-1.log | 2004     | 101     |
	| app-2.log | 2005     | 102     |

2. Se ejecuta nuevamente, no hay rotación, solo se actualiza `app.log` utilizando `rsync`. El `.shadow_sync`: 

	| Nombre    | Indodo R | Inodo L |
	|:---------:|:--------:|:-------:|
	| app.log   | 2003     | 100     |
	| app-1.log | 2004     | 101     |
	| app-2.log | 2005     | 102     |

3. Se ejecuta nuevamente y se encuentra, verificando `.shadow_sync`, la rotación: `app.log => app-1.log`, `app-1.log => app-2.log`, `app-2.log => app-3.log`.
Realiza la modificación de nombres de manera local utilizando `mv` para modificar el nombre y no el numero de inodo y actualiza el `.shadow_sync`:

	| Nombre    | Indodo R | Inodo L |
	|:---------:|:--------:|:-------:|
	| app.log   | 2006     | 103     |
	| app-1.log | 2003     | 100     |
	| app-2.log | 2004     | 101     |
Vuelve a ejecutar el rsync con los mismos parámetros en donde se genera el nuevo archivo `app.log` y se actualiza con la ultima información faltante `app-1.log`. (El archivo `app-2.log` local es sobrescrito con el anterior `app-1.log`)
