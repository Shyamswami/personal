#!/bin/bash
# Script de Startup Automatico para Grid Control
# Autor by  IVAN ACOSTA
export PATH=$PATH:/usr/local/bin:/bin:/usr/bin

echo "***********************************************"
echo      "* Inicializa el proceso de Startup    *"
echo "***********************************************"
echo "Fecha:`date "+%Y-%m-%d %H:%M:%S"` ............."
echo "***********************************************"

ORACLE_MWHOME=/u01/app/oracle/Middleware/oms11g
ORACLE_AGENT=/u01/app/oracle/Middleware/agent11g

echo "***********************************************"
echo          "* Levantando Servicios ... *"
echo "***********************************************"

echo "Starting up Oms ..."
$ORACLE_MWHOME/bin/emctl start oms
echo "Starting up Agent..."
$ORACLE_AGENT/bin/emctl start agent
echo "Starting up OMS Detail..."
$ORACLE_MWHOME/bin/emctl status oms -detail

echo "***********************************************"
echo "**Enviando email .............................*"
echo "** Proceso Finalizado .....................OK.*"
echo "***********************************************"
