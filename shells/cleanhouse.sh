#!/bin/bash
#
# Script used to cleanup any Oracle environment.
#
# Cleans:      audit_log_dest
#              background_dump_dest
#              core_dump_dest
#              user_dump_dest
#              Clusterware logs
#
# Rotates:     Alert Logs
#              Listener Logs
#
# Scheduling:  00 00 * * * /export/home/oracle/bin/cleanhouse.sh -d 31 > /tmp/cleanhouse.log 2>&1
#
# Created By:  Shad Rich  2008-09-16
#
# History:     Shad Rich  2009-01-01 - Fixed some bugs to make it compatible with Linux.
#

RM="rm -f"
RMDIR="rm -rf"
LS="ls -l"
MV="mv"
TOUCH="touch"
TESTTOUCH="echo touch"
TESTMV="echo mv"
TESTRM=$LS
TESTRMDIR=$LS

SUCCESS=0
FAILURE=1
TEST=0
HOSTNAME=`hostname`
ORAENV="oraenv"
TODAY=`date +%Y%m%d`
ORIGPATH=/usr/local/bin:$PATH
ORIGLD=$LD_LIBRARY_PATH
export PATH=$ORIGPATH

# Usage function.
f_usage(){
  echo "Usage: `basename $0` -d DAYS [-a DAYS] [-b DAYS] [-c DAYS] [-n DAYS] [-r DAYS] [-u DAYS] [-t] [-h]"
  echo "       -d = Mandatory default number of days to keep log files that are not explicitly passed as parameters."
  echo "       -a = Optional number of days to keep audit logs."
  echo "       -b = Optional number of days to keep background dumps."
  echo "       -c = Optional number of days to keep core dumps."
  echo "       -n = Optional number of days to keep network log files."
  echo "       -r = Optional number of days to keep clusterware log files."
  echo "       -u = Optional number of days to keep user dumps."
  echo "       -h = Optional help mode."
  echo "       -t = Optional test mode. Does not delete any files."
}

if [ $# -lt 1 ]; then
  f_usage
  exit $FAILURE
fi

# Function used to check the validity of days.
f_checkdays(){
  if [ $1 -lt 1 ]; then
    echo "ERROR: Number of days is invalid."
    exit $FAILURE
  fi
  if [ $? -ne 0 ]; then
    echo "ERROR: Number of days is invalid."
    exit $FAILURE
  fi
} 

# Function used to cut log files.
f_cutlog(){

  # Set name of log file.
  LOG_FILE=$1
  CUT_FILE=${LOG_FILE}.${TODAY}
  FILESIZE=`ls -l $LOG_FILE | awk '{print $5}'`

  # Cut the log file if it has not been cut today.
  if [ -f $CUT_FILE ]; then
    echo "Log Already Cut Today: $CUT_FILE"
  elif [ ! -f $LOG_FILE ]; then
    echo "Log File Does Not Exist: $LOG_FILE"
  elif [ $FILESIZE -eq 0 ]; then
    echo "Log File Has Zero Size: $LOG_FILE"
  else
    # Cut file.
    echo "Cutting Log File: $LOG_FILE"
    $MV $LOG_FILE $CUT_FILE
    $TOUCH $LOG_FILE
  fi
}

# Function used to delete log files.
f_deletelog(){

  # Set name of log file.
  CLEAN_LOG=$1

  # Set time limit and confirm it is valid.
  CLEAN_DAYS=$2
  f_checkdays $CLEAN_DAYS
  
  # Delete old log files if they exist.
  find $CLEAN_LOG.[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9] -type f -mtime +$CLEAN_DAYS -exec $RM {} \; 2>/dev/null
}
  
# Function used to get database parameter values.
f_getparameter(){
  if [ -z "$1" ]; then
    return
  fi
  PARAMETER=$1
  sqlplus -s /nolog <<EOF | awk -F= "/^a=/ {print \$2}"
set head off pagesize 0 feedback off linesize 200
whenever sqlerror exit 1
conn / as sysdba
select 'a='||value from v\$parameter where name = '$PARAMETER';
EOF
}

# Function to get unique list of directories.
f_getuniq(){

  if [ -z "$1" ]; then
    return
  fi

  ARRCNT=0
  MATCH=N
  x=0

  for e in `echo $1`; do
    if [ ${#ARRAY[*]} -gt 0 ]; then

      # See if the array element is a duplicate.
      while [ $x -lt  ${#ARRAY[*]} ]; do
        if [ "$e" = "${ARRAY[$x]}" ]; then
          MATCH=Y
        fi
      done
    fi
    if [ "$MATCH" = "N" ]; then
      ARRAY[$ARRCNT]=$e
      ARRCNT=`expr $ARRCNT+1`
    fi
    x=`expr $x + 1`
  done
  echo ${ARRAY[*]}
}

# Parse the command line options.
while getopts a:b:c:d:n:r:u:th OPT; do
  case $OPT in
    a) ADAYS=$OPTARG
       ;;
    b) BDAYS=$OPTARG
       ;;
    c) CDAYS=$OPTARG
       ;;
    d) DDAYS=$OPTARG
       ;;
    n) NDAYS=$OPTARG
       ;;
    r) RDAYS=$OPTARG
       ;;
    u) UDAYS=$OPTARG
       ;;
    t) TEST=1
       ;;
    h) f_usage
       exit 0
       ;;
    *) f_usage
       exit 2
       ;;
  esac
done
shift $(($OPTIND - 1))

# Ensure the default number of days is passed.
if [ -z "$DDAYS" ]; then
  echo "ERROR: The default days parameter is mandatory."
  f_usage
  exit $FAILURE
fi
f_checkdays $DDAYS

echo "`basename $0` Started `date`."

# Use test mode if specified.
if [ $TEST -eq 1 ]
then
  RM=$TESTRM
  RMDIR=$TESTRMDIR
  MV=$TESTMV
  TOUCH=$TESTTOUCH
  echo "Running in TEST mode."
fi

# Set the number of days to the default if not explicitly set.
ADAYS=${ADAYS:-$DDAYS}; echo "Keeping audit logs for $ADAYS days."; f_checkdays $ADAYS
BDAYS=${BDAYS:-$DDAYS}; echo "Keeping background logs for $BDAYS days."; f_checkdays $BDAYS
CDAYS=${CDAYS:-$DDAYS}; echo "Keeping core dumps for $CDAYS days."; f_checkdays $CDAYS
NDAYS=${NDAYS:-$DDAYS}; echo "Keeping network logs for $NDAYS days."; f_checkdays $NDAYS
RDAYS=${RDAYS:-$DDAYS}; echo "Keeping clusterware logs for $RDAYS days."; f_checkdays $RDAYS
UDAYS=${UDAYS:-$DDAYS}; echo "Keeping user logs for $UDAYS days."; f_checkdays $UDAYS

# Check for the oratab file.
if [ -f /var/opt/oracle/oratab ]; then
  ORATAB=/var/opt/oracle/oratab
elif [ -f /etc/oratab ]; then
  ORATAB=/etc/oratab
else
  echo "ERROR: Could not find oratab file."
  exit $FAILURE
fi

# Build list of distinct Oracle Home directories.
OH=`egrep -i ":Y|:N" $ORATAB | grep -v "^#" | grep -v "\*" | cut -d":" -f2 | sort | uniq`

# Exit if there are not Oracle Home directories.
if [ -z "$OH" ]; then
  echo "No Oracle Home directories to clean."
  exit $SUCCESS
fi

# Get the list of running databases.
SIDS=`ps -e -o args | grep pmon | grep -v grep | awk -F_ '{print $3}' | sort`

# Gather information for each running database.
for ORACLE_SID in `echo $SIDS`
do

  # Set the Oracle environment.
  ORAENV_ASK=NO
  export ORACLE_SID
  . $ORAENV

  if [ $? -ne 0 ]; then
    echo "Could not set Oracle environment for $ORACLE_SID."
  else
    export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$ORIGLD

    ORAENV_ASK=YES

    echo "ORACLE_SID: $ORACLE_SID"

    # Get the audit_dump_dest.
    ADUMPDEST=`f_getparameter audit_dump_dest`
    if [ ! -z "$ADUMPDEST" ] && [ -d "$ADUMPDEST" 2>/dev/null ]; then
      echo "  Audit Dump Dest: $ADUMPDEST"
      ADUMPDIRS="$ADUMPDIRS $ADUMPDEST"
    fi

    # Get the background_dump_dest.
    BDUMPDEST=`f_getparameter background_dump_dest`
    echo "  Background Dump Dest: $BDUMPDEST"
    if [ ! -z "$BDUMPDEST" ] && [ -d "$BDUMPDEST" ]; then
      BDUMPDIRS="$BDUMPDIRS $BDUMPDEST"
    fi

    # Get the core_dump_dest.
    CDUMPDEST=`f_getparameter core_dump_dest`
    echo "  Core Dump Dest: $CDUMPDEST"
    if [ ! -z "$CDUMPDEST" ] && [ -d "$CDUMPDEST" ]; then
      CDUMPDIRS="$CDUMPDIRS $CDUMPDEST"
    fi

    # Get the user_dump_dest.
    UDUMPDEST=`f_getparameter user_dump_dest`
    echo "  User Dump Dest: $UDUMPDEST"
    if [ ! -z "$UDUMPDEST" ] && [ -d "$UDUMPDEST" ]; then
      UDUMPDIRS="$UDUMPDIRS $UDUMPDEST"
    fi
  fi
done

# Do cleanup for each Oracle Home.
for ORAHOME in `f_getuniq "$OH"`
do

  # Get the standard audit directory if present.
  if [ -d $ORAHOME/rdbms/audit ]; then
     ADUMPDIRS="$ADUMPDIRS $ORAHOME/rdbms/audit"
  fi

  # Get the Cluster Ready Services Daemon (crsd) log directory if present.
  if [ -d $ORAHOME/log/$HOSTNAME/crsd ]; then
    CRSLOGDIRS="$CRSLOGDIRS $ORAHOME/log/$HOSTNAME/crsd"
  fi

  # Get the  Oracle Cluster Registry (OCR) log directory if present.
  if [ -d $ORAHOME/log/$HOSTNAME/client ]; then
    OCRLOGDIRS="$OCRLOGDIRS $ORAHOME/log/$HOSTNAME/client"
  fi

  # Get the Cluster Synchronization Services (CSS) log directory if present.
  if [ -d $ORAHOME/log/$HOSTNAME/cssd ]; then
    CSSLOGDIRS="$CSSLOGDIRS $ORAHOME/log/$HOSTNAME/cssd"
  fi
 
  # Get the Event Manager (EVM) log directory if present.
  if [ -d $ORAHOME/log/$HOSTNAME/evmd ]; then
    EVMLOGDIRS="$EVMLOGDIRS $ORAHOME/log/$HOSTNAME/evmd"
  fi

  # Get the RACG log directory if present.
  if [ -d $ORAHOME/log/$HOSTNAME/racg ]; then
    RACGLOGDIRS="$RACGLOGDIRS $ORAHOME/log/$HOSTNAME/racg"
  fi

done

# Clean the audit_dump_dest directories.
if [ ! -z "$ADUMPDIRS" ]; then
  for DIR in `f_getuniq "$ADUMPDIRS"`; do
    if [ -d $DIR ]; then
      echo "Cleaning Audit Dump Directory: $DIR"
      find $DIR -type f -name "*.aud" -mtime +$ADAYS -exec $RM {} \; 2>/dev/null
    fi
  done
fi

# Clean the background_dump_dest directories.
if [ ! -z "$BDUMPDIRS" ]; then
  for DIR in `f_getuniq "$BDUMPDIRS"`; do
    if [ -d $DIR ]; then
      echo "Cleaning Background Dump Destination Directory: $DIR"
      # Clean up old trace files.
      find $DIR -type f -name "*.tr[c,m]" -mtime +$BDAYS -exec $RM {} \; 2>/dev/null
      find $DIR -type d -name "cdmp*" -mtime +$BDAYS -exec $RMDIR {} \; 2>/dev/null
    fi
  
    if [ -d $DIR ]; then
      # Cut the alert log and clean old ones.
      for f in `find $DIR -type f -name "alert\_*.log" ! -name "alert_[0-9A-Z]*.[0-9]*.log" 2>/dev/null`; do
        echo "Alert Log: $f"
        f_cutlog $f
        f_deletelog $f $BDAYS
      done
    fi
  done
fi

# Clean the core_dump_dest directories.
if [ ! -z "$CDUMPDIRS" ]; then
  for DIR in `f_getuniq "$CDUMPDIRS"`; do
    if [ -d $DIR ]; then
      echo "Cleaning Core Dump Destination: $DIR"
      find $DIR -type d -name "core*" -mtime +$CDAYS -exec $RMDIR {} \; 2>/dev/null
    fi
  done
fi

# Clean the user_dump_dest directories.
if [ ! -z "$UDUMPDIRS" ]; then
  for DIR in `f_getuniq "$UDUMPDIRS"`; do
    if [ -d $DIR ]; then
      echo "Cleaning User Dump Destination: $DIR"
      find $DIR -type f -name "*.trc" -mtime +$UDAYS -exec $RM {} \; 2>/dev/null
    fi
  done
fi

# Cluster Ready Services Daemon (crsd) Log Files
for DIR in `f_getuniq "$CRSLOGDIRS $OCRLOGDIRS $CSSLOGDIRS $EVMLOGDIRS $RACGLOGDIRS"`; do
  if [ -d $DIR ]; then
    echo "Cleaning Clusterware Directory: $DIR"
    find $DIR -type f -name "*.log" -mtime +$RDAYS -exec $RM {} \; 2>/dev/null
  fi
done

# Clean Listener Log Files.
# Get the list of running listeners. It is assumed that if the listener is not running, the log file does not need to be cut.
ps -e -o args | grep tnslsnr | grep -v grep | while read LSNR; do

  # Derive the lsnrctl path from the tnslsnr process path.
  TNSLSNR=`echo $LSNR | awk '{print $1}'`
  ORACLE_PATH=`dirname $TNSLSNR`
  ORACLE_HOME=`dirname $ORACLE_PATH`
  PATH=$ORACLE_PATH:$ORIGPATH
  LD_LIBRARY_PATH=$ORACLE_HOME/lib:$ORIGLD
  LSNRCTL=$ORACLE_PATH/lsnrctl
  echo "Listener Control Command: $LSNRCTL"
  
  # Derive the listener name from the running process.
  LSNRNAME=`echo $LSNR | awk '{print $2}' | tr "[:upper:]" "[:lower:]"`
  echo "Listener Name: $LSNRNAME"
  
  # Get the listener version.
  LSNRVER=`$LSNRCTL version | grep "LSNRCTL" | grep "Version" | awk '{print $5}' | awk -F. '{print $1}'`
  echo "Listener Version: $LSNRVER"

  # Get the TNS_ADMIN variable.
  echo "Initial TNS_ADMIN: $TNS_ADMIN"
  unset TNS_ADMIN
  TNS_ADMIN=`$LSNRCTL status $LSNRNAME | grep "Listener Parameter File" | awk '{print $4}'`
  if [ ! -z $TNS_ADMIN ]; then
    export TNS_ADMIN=`dirname $TNS_ADMIN`
  else
    export TNS_ADMIN=$ORACLE_HOME/network/admin
  fi
  echo "Network Admin Directory: $TNS_ADMIN"

  # If the listener is 11g, get the diagnostic dest, etc...
  if [ $LSNRVER -ge 11 ]; then
    
    # Get the listener log file directory. 
    LSNRDIAG=`$LSNRCTL<<EOF | grep log_directory | awk '{print $6}'
set current_listener $LSNRNAME
show log_directory
EOF`
    echo "Listener Diagnostic Directory: $LSNRDIAG"

    # Get the listener trace file name.
    LSNRLOG=`lsnrctl<<EOF | grep trc_directory | awk '{print $6"/"$1".log"}'
set current_listener $LSNRNAME
show trc_directory
EOF`
    echo "Listener Log File: $LSNRLOG"

  # If 10g or lower, do not use diagnostic dest.
  else
    # Get the listener log file location.
    LSNRLOG=`$LSNRCTL status $LSNRNAME | grep "Listener Log File" | awk '{print $4}'`
  fi


  # See if the listener is logging.
  if [ -z "$LSNRLOG" ]; then
    echo "Listener Logging is OFF. Not rotating the listener log."
  # See if the listener log exists.
  elif  [ ! -r "$LSNRLOG" ]; then
    echo "Listener Log Does Not Exist: $LSNRLOG"
  # See if the listener log has been cut today.
  elif [ -f $LSNRLOG.$TODAY ]; then
    echo "Listener Log Already Cut Today: $LSNRLOG.$TODAY"
  # Cut the listener log if the previous two conditions were not met.
  else

    # Remove old 11g+ listener log XML files.
    if [ ! -z "$LSNRDIAG" ] && [ -d "$LSNRDIAG" ]; then
      echo "Cleaning Listener Diagnostic Dest: $LSNRDIAG"
      find $LSNRDIAG -type f -name "log\_[0-9]*.xml" -mtime +$NDAYS -exec $RM {} \; 2>/dev/null
    fi
    
    # Disable logging.
    $LSNRCTL <<EOF
set current_listener $LSNRNAME
set log_status off
EOF

    # Cut the listener log file.
    f_cutlog $LSNRLOG

    # Enable logging.
    $LSNRCTL <<EOF
set current_listener $LSNRNAME
set log_status on
EOF

    # Delete old listener logs.
    f_deletelog $LSNRLOG $NDAYS

  fi
done

echo "`basename $0` Finished `date`."

exit
