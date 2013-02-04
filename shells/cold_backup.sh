#!/bin/bash
# Script de copias de seguridad (COLD Backup) Base de datos
# Autor = IVAN ACOSTA
export PATH=$PATH:/usr/local/bin:/bin:/usr/bin
echo "***********************************************"
echo "*Backup Database Inicializando    *"
echo "***********************************************"
echo "Fecha:`date "+%Y-%m-%d %k:%M:%S"` ............."
echo "***********************************************"

echo "***********************************************"
echo "* Verifica la disponibilidad  de los SID's    *"
echo "***********************************************"

# Verifica el parametro recibido debe ser igual que el ORACLE_SID
if [[ $# -eq 0 ]]
then
  echo "Database name argument is missing"
  exit 1
fi

export ORA_SID_LOWER=`/bin/echo $1 | /usr/bin/tr "[:upper:]" "[:lower:]"`
export ORA_SID_UPPER=`/bin/echo $1 | /usr/bin/tr "[:lower:]" "[:upper:]" `

export ORA_INSTANCE=$ORA_SID_UPPER

# Verifica la disponibilidad de la Base de datos.

DBVERIFY=`ps -ef | grep ora_pmon_$ORA_SID_UPPER | grep -v 'grep' | wc -l`
if [ $DBVERIFY = "0" ]; then
  echo "Base de datos con nombre $ORA_SID_UPPER no esta arriba"
  exit 1
else
  echo "Base de datos con nombre $ORA_SID_UPPER se encuentra arriba"
fi
echo "================================================"

echo "***********************************************"
echo "* Exporta Variables de Entorno  ............  *"
echo "***********************************************"

export ORAENV_ASK=NO
export ORACLE_SID=$ORA_INSTANCE
echo $ORACLE_SID
export PFILE=$ORACLE_HOME/dbs/init$SID.ora
export FECHA=`date +%Y-%m-%d_%H-%M-%S`
export backup=/u99/oradata/
export destino=/u99/oradata/fast_recovery_area
source /usr/local/bin/oraenv

echo "================================================"
echo "== Bajar Base de Datos ........................="
echo "================================================"
echo "***********************************************"

sqlplus -S '/ as sysdba' <<EOFSQL
set termout off
set pages 0
set lines 120
set feedback off
set trimspool on
spool files_backup.bck

select name from v\$datafile;
select name from v\$controlfile;
select member from v\$logfile;
select '$PFILE' from dual;

spool off
shutdown immediate;
exit;
EOFSQL

echo "================================================"
echo "== Comprimir y Copiar Archivos ................="
echo "================================================"
echo "***********************************************"

tar czPf $backup/backup_$FECHA.tar -T files_backup.bck
scp -P6666 $backup/backup_$FECHA.tar oracle@database.test:$destino

echo "================================================"
echo "== Subir Database   ...........................="
echo "================================================"
echo "***********************************************"

sqlplus -S '/ as sysdba' <<EOFSQL
startup
exit;
EOFSQL

echo "***********************************************"
echo "**Enviando email .............................*"
mutt -s "Cold Backup $" -a $ORACLE_HOME/scripts/cold_backup.log personal@myemail.edu < $ORACLE_HOME/scripts/correo_body.txt
echo "** Proceso Finalizado .....................OK.*"
echo "***********************************************"
echo "================================================"
echo "== Fin del Proceso.............................="
echo "================================================"

