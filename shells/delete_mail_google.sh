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


#SELECT SWBTPAC_EXTERNAL_USER||'@uniminuto.edu.co'
#FROM SPRIDEN,SWBTPAC,SFRSTCR
#WHERE SPRIDEN_CHANGE_IND IS NULL
#AND SPRIDEN_PIDM      = SFRSTCR_PIDM
#AND SWBTPAC_PIDM                   = SPRIDEN_PIDM
#AND SPRIDEN_PIDM NOT IN (SELECT sibinst_PIDM FROM sibinst)
#AND SFRSTCR_TERM_CODE LIKE TO_CHAR(SYSDATE - 720, 'RRRR')||'%'
#GROUP BY SPRIDEN_ID,SWBTPAC_EXTERNAL_USER||'@uniminuto.edu.co';

echo "================================================"
echo "      Suspencion de Email para Estudiantes      "
echo "================================================"

sqlplus -S '/ as sysdba' << EOF
set pages 0
set long 9999999
set feedback off 
whenever sqlerror exit
spool estudiantes.txt

SELECT GOREMAL_EMAIL_ADDRESS
FROM SPRIDEN, GOREMAL
WHERE SPRIDEN_CHANGE_IND IS NULL
AND GOREMAL_PIDM = SPRIDEN_PIDM
AND GOREMAL_STATUS_IND !='I'
AND GOREMAL_EMAIL_ADDRESS LIKE '%uniminuto.edu.co'
AND SPRIDEN_PIDM NOT IN (SELECT sibinst_PIDM FROM sibinst)
AND (SELECT MAX(substr(A.SFRSTCR_TERM_CODE,1,4))  FROM SFRSTCR A 
      WHERE A.SFRSTCR_PIDM=SPRIDEN_PIDM ) <= TO_CHAR(SYSDATE - 720 , 'RRRR')
ORDER BY 1;

spool off

UPDATE GOREMAL SET GOREMAL_STATUS_IND='I', GOREMAL_ACTIVITY_DATE=SYSDATE, GOREMAL_COMMENT ='Cuenta Suspendida en Google'
WHERE 
GOREMAL_EMAIL_ADDRESS LIKE '%uniminuto.edu.co' AND
GOREMAL_STATUS_IND !='I' AND
GOREMAL_PIDM IN (
              SELECT SPRIDEN_PIDM
              FROM SPRIDEN, GOREMAL
              WHERE SPRIDEN_CHANGE_IND IS NULL
              AND GOREMAL_PIDM = SPRIDEN_PIDM
              AND GOREMAL_STATUS_IND !='I'
              AND GOREMAL_EMAIL_ADDRESS LIKE '%uniminuto.edu.co'
              AND SPRIDEN_PIDM NOT IN (SELECT SIBINST_PIDM FROM SIBINST)
              AND (SELECT MAX(SUBSTR(A.SFRSTCR_TERM_CODE,1,4))  FROM SFRSTCR A 
                    WHERE A.SFRSTCR_PIDM=SPRIDEN_PIDM ) <= TO_CHAR(SYSDATE - 720 , 'RRRR'));

commit;
exit
EOF

echo "================================================"
echo "      Suspencion de Email para Docentes         "
echo "================================================"


sqlplus -S '/ as sysdba' << EOF
set pages 0
set long 9999999
set feedback off 
whenever sqlerror exit
spool docentes.txt

SELECT DISTINCT GOREMAL_EMAIL_ADDRESS
FROM SPRIDEN, GOREMAL, SIBINST
WHERE SPRIDEN_CHANGE_IND IS NULL
AND GOREMAL_PIDM = SPRIDEN_PIDM
AND GOREMAL_STATUS_IND !='I'
AND GOREMAL_EMAIL_ADDRESS LIKE '%uniminuto.edu.co'
AND SPRIDEN_PIDM = SIBINST_PIDM
AND (SELECT MAX(SUBSTR(A.SIRASGN_TERM_CODE,1,4))  FROM SIRASGN A
      WHERE A.sirasgn_PIDM=SPRIDEN_PIDM ) < TO_CHAR(SYSDATE - 365 , 'RRRR');

spool off

UPDATE GOREMAL SET GOREMAL_STATUS_IND='I', GOREMAL_COMMENT='Cuenta Suspendida en Google', GOREMAL_ACTIVITY_DATE=SYSDATE
WHERE 
GOREMAL_EMAIL_ADDRESS LIKE '%uniminuto.edu.co' AND
GOREMAL_STATUS_IND !='I' AND
GOREMAL_PIDM IN (
           SELECT DISTINCT GOREMAL_PIDM
           FROM SPRIDEN, GOREMAL, SIBINST
           WHERE SPRIDEN_CHANGE_IND IS NULL
           AND GOREMAL_PIDM = SPRIDEN_PIDM
           AND GOREMAL_STATUS_IND !='I'
           AND GOREMAL_EMAIL_ADDRESS LIKE '%uniminuto.edu.co'
           AND SPRIDEN_PIDM = SIBINST_PIDM
           AND (SELECT MAX(SUBSTR(A.SIRASGN_TERM_CODE,1,4))  FROM SIRASGN A
                 WHERE A.sirasgn_PIDM=SPRIDEN_PIDM ) < TO_CHAR(SYSDATE - 365 , 'RRRR'));

commit;
exit
EOF

#scp estudiantes.txt docentes.txt banner@estudiantes.uniminuto.edu:/opt/GoogleAppsManager/files

echo "***********************************************"
echo "**Enviando email .............................*"
mutt -s "Depueracion Email Estudiantes Google" -a $ORACLE_HOME/scripts/estudiantes.txt iacosta@uniminuto.edu < $ORACLE_HOME/scripts/correo_body.txt
mutt -s "Depueracion Email Docentes Google" -a $ORACLE_HOME/scripts/docentes.txt iacosta@uniminuto.edu < $ORACLE_HOME/scripts/correo_body.txt
echo "** Proceso Finalizado .....................OK.*"
echo "***********************************************"
echo "================================================"
echo "== Fin del Proceso.............................="
echo "================================================"

