#!/bin/bash
#check user
CUR_PATH=$(cd `dirname $0`;pwd)
SCRIPT_PATH=$0
IPMC_USER="`stat -c '%U' ${SCRIPT_PATH}`"
export IPMC_USER
CURRENT_USER="`/usr/bin/id -u -n`"
if [ "${IPMC_USER}" != "${CURRENT_USER}" ]
then
    echo "only ${IPMC_USER} can execute this script."
    exit 1
fi

umask 027


# for start debug
# usage:
#   start.sh [debug] [slot_id]
# eg:
#   $ start.sh debug
# or
#   $ start.sh debug 0

__START_DEBUG=0
__SLOT_ID=0

if [ $# -gt 0 ] ; then
    if [ $1 = "debug" ] ; then
        __START_DEBUG=1
    fi
    if [ $# -gt 1 ] ; then
        __SLOT_ID=$2
    fi
fi

if [ $__START_DEBUG = 1 ] ; then
    # import common envs
    while IFS= read -r line
    do
        export "$line"
    done < $(dirname $0)/../envs/env.properties
    if [ -z "$AGENT_CONF_FILE" ]
    then
        echo "missing env AGENT_CONF_FILE"
        exit 1
    fi

    # import microService envs
    while IFS= read -r line
    do
        export "$line"
    done < $(dirname $0)/../envs/HomeNetworkService.properties

    # import process envs
    while IFS= read -r line
    do
        export "$line"
    done < $(dirname $0)/../envs/homenetworkservice.properties

    if [ -z "$PROCESS_NAME" ]
    then
        echo "missing env PROCESS_NAME"
        exit 1
    fi

    # add envs
    NODE_ID=`awk -F"=" '/localnodeid=/ {print $2}' ${AGENT_CONF_FILE} | /usr/bin/tr -d " "`
    export NODE_ID
    export PROCESS_SLOT=$__SLOT_ID
fi

if [ -z "$JAVA_HOME" ]
then
	echo "There is no JAVA_HOME"
	exit 1
fi

if [ -z "$CATALINA_HOME" ]
then
	echo "There is no CATALINA_HOME"
	exit 1
fi

if [ -z "$APP_ROOT" ]
then
	echo "There is no APP_ROOT"
	exit 1
fi

export CATALINA_BASE=$APP_ROOT
export COMPLETE_PROCESS_NAME=$PROCESS_NAME-$NODE_ID-$PROCESS_SLOT
export APP_NAME=HomeNetworkService
LOG_PATH=$_APP_LOG_DIR/$COMPLETE_PROCESS_NAME

#for dmq
export KEY_HOME=${APP_ROOT}/controller/configuration/dmq/middleware-key/key;
export RUNTIME_CENTER_PATH=${APP_ROOT}/controller/configuration/dmq/zookeeper/conf/ssl/zk_config;
export NAAS_HOME=$APP_ROOT/controller

export APP_ROOT
export _APP_LOG_DIR
export OSS_ROOT
export SSL_ROOT

$APP_ROOT/bin/dmq_modify_app_ip.sh
$APP_ROOT/bin/dmq_update_key.sh
$APP_ROOT/bin/dmq_update_cer.sh

JAVA_OPTS="-Dfile.encoding=UTF-8"
JAVA_OPTS="$JAVA_OPTS -Dlog.dir=$LOG_PATH"

JAVA_OPTS_3RD="-Dnet.sf.ehcache.skipUpdateCheck=true -Dorg.terracotta.quartz.skipUpdateCheck=true "
JAVA_OPTS="$JAVA_OPTS -Dorg.apache.catalina.security.SecurityListener.UMASK=`umask` -Dorg.apache.catalina.connector.RECYCLE_FACADES=true"
JAVA_OPTS="$JAVA_OPTS $JAVA_OPTS_3RD"
export COREDUMP_DIR=/opt/oss/log/NCE/coredump/$APP_NAME
mkdir -p $COREDUMP_DIR
export TOMCAT_LOG_DIR=$_APP_LOG_DIR/$COMPLETE_PROCESS_NAME/tomcatlog
mkdir -p $TOMCAT_LOG_DIR
export TOMCAT_WORK_DIR=$_APP_SHARE_DIR/$COMPLETE_PROCESS_NAME/tomcatwork
export CATALINA_OUT=$TOMCAT_LOG_DIR/catalinaout.log
JAVA_OPTS="$JAVA_OPTS -DTOMCAT_LOG_DIR=$TOMCAT_LOG_DIR  -DTOMCAT_WORK_DIR=$TOMCAT_WORK_DIR -DNFW=$COMPLETE_PROCESS_NAME -Dprocname=$COMPLETE_PROCESS_NAME "
JAVA_OPTS="$JAVA_OPTS -Xdebug -Xrunjdwp:transport=dt_socket,address=32045,server=y,suspend=n"

export JAVA_OPTS="$JAVA_OPTS -server -Xss256k -Xms32m -Xmx1024m -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$COREDUMP_DIR -XX:InitialCodeCacheSize=32m -XX:ReservedCodeCacheSize=64m -XX:MetaspaceSize=32m -XX:MaxMetaspaceSize=256m -XX:+DisableExplicitGC -XX:+UseConcMarkSweepGC -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=62 -XX:-UseLargePages -XX:+UseFastAccessorMethods -XX:+CMSClassUnloadingEnabled -Dbsp.app.datasource=homenetworkservicedb"
#export LOGGING_CONFIG="-DNFW=$COMPLETE_PROCESS_NAME -Djava.util.logging.config.file=$CATALINA_BASE/conf/logging.properties"

if [ $__START_DEBUG = 1 ] ; then
    echo Please check ${_APP_LOG_DIR}/start.log
	echo Please check $TOMCAT_LOG_DIR, if you want more infornation.
    $CATALINA_HOME/bin/catalina.sh start 2>&1 > ${_APP_LOG_DIR}/start.log
else
    $CATALINA_HOME/bin/catalina.sh start
fi

result=0;$CUR_PATH/../../../../manager/agent/tools/shscript/syslogutils.sh "$(basename $0)" "$result" "Execute($#):$CUR_PATH/$0 $@";exit $result
