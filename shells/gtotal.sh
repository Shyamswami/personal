#! /bin/bash
#
# oracle Start/Stop the Databases...By Ivan Acosta
#
# chkconfig: - 99 10 
# description: oracle upstart
# processname: oracle
# config: /etc/oratab
# pidfile: /var/run/oracle.pid
 
# Source function library.
. /etc/init.d/functions
 
RETVAL=0
ORA_OWNER="oracle"
ORA_HOME="/u01/app/oracle/product/11.2.0"
ORACLE_AGENT="/u01/app/oracle/Middleware/agent11g"
ORACLE_MWHOME="/u01/app/oracle/Middleware/oms11g"
 
# See how we were called.
 
prog="oracle"
 
start() {
echo -n $"Starting up DBs ... $prog: "
su - $ORA_OWNER -c "$ORA_HOME/bin/dbstart" 
echo -n $"Starting up Listener ... $prog: "
su - $ORA_OWNER -c "$ORA_HOME/bin/lsnrctl start"
echo -n $"Starting up Oms ... $prog: "
su - $ORA_OWNER -c "$ORACLE_MWHOME/bin/emctl start oms"
echo -n $"Starting up Agent... $prog: "
su - $ORA_OWNER -c "$ORACLE_AGENT/bin/emctl start agent"
echo "Funciona correctamente..!"
RETVAL=$?
echo
[ $RETVAL -eq 0 ] && touch /home/oracle/bin/start_service.out
return $RETVAL
}
 
status() {
echo -n $"Status Listener ... $prog: "
su - $ORA_OWNER -c "$ORA_HOME/bin/lsnrctl status"
echo -n $"Status Oms ... $prog: "
su - $ORA_OWNER -c "$ORACLE_MWHOME/bin/emctl status oms -detail"
echo -n $"Starting up Agent... $prog: "
su - $ORA_OWNER -c "$ORACLE_AGENT/bin/emctl status agent"
echo "Funciona correctamente..!"
RETVAL=$?
echo
[ $RETVAL -eq 0 ] && touch /home/oracle/bin/status_service.out
return $RETVAL
}
 
stop() {
echo -n $"Stoping  DBs ... $prog: "
su - $ORA_OWNER -c "$ORA_HOME/bin/dbshut"
echo -n $"Stoping Listener ... $prog: "
su - $ORA_OWNER -c "$ORA_HOME/bin/lsnrctl stop"
echo -n $"Stoping Oms ... $prog: "
su - $ORA_OWNER -c "$ORACLE_MWHOME/bin/emctl stop oms -all"
echo -n $"Stoping Agent... $prog: "
su - $ORA_OWNER -c "$ORACLE_AGENT/bin/emctl stop agent"
echo "Funciona correctamente..!"
RETVAL=$?
echo
[ $RETVAL -eq 0 ] && touch /home/oracle/bin/stop_service.out
return $RETVAL
} 
 
restart() {
stop
start
} 
 
case "$1" in
start)
start
;;
status)
status
;;
stop)
stop
;;
restart)
restart
;;
*)
echo $"Usage: $0 {start|status|stop|restart}"
exit 1
esac
exit $?
