#!/bin/bash
# Shell para Mantimiento de Procesos para BannerDB
# Autor = IVAN ACOSTA
export PATH=$PATH:/usr/local/bin:/bin:/usr/bin
source /home/oracle/.bashrc
echo "***********************************************"
echo "*Mantenimiento de Procesos de Banner DB       *"
echo "***********************************************"
echo "Fecha:`date "+%Y-%m-%d %k:%M:%S"` ............."
echo "***********************************************"

echo "***********************************************"
echo "* Verifica la disponibilidad  de los SID's    *"
echo "***********************************************"

# Verifica el parametro recibido debe ser igual que el ORACLE_SID
if [[ $# -eq 0 ]]
then
  echo "El argumento de Base de Datos no aparece"
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



#sqlplus '/as sysdba' << EOF
sqlplus -S '/ as sysdba' << EOF
spool depura_datos.log
define LESS_THAN_DD_MON_YYYY=sysdate

PROMPT =======================
PROMPT Truncatemiento de Tabla
PROMPT =======================
truncate table general.gjbprun;

PROMPT 'Espera..................'

BEGIN
DBMS_LOCK.SLEEP(100);
END;
/

PROMPT '============================'
PROMPT 'Script de Borrado...Sungard'
PROMPT '============================'
@gdeloutp.sql
spool off
EOF

echo "***********************************************"
echo "**Enviando email .............................*"
mutt -s "Depueracion de Datos BANNERDB" -a $ORACLE_HOME/scripts/depura_datos.log my@email.edu < $ORACLE_HOME/scripts/correo_body.txt
echo "** Proceso Finalizado .....................OK.*"
echo "***********************************************"
echo "================================================"
echo "== Fin del Proceso.............................="
echo "================================================"
