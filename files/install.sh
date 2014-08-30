#!/bin/bash

echo "Installing some basic utilies, Java, easy_install, etc"
yum install -y nano nc wget htop lsof java-1.7.0-openjdk.x86_64 python-setuptools

echo "Installing Kafka"
wget -q http://apache.mirrors.hoobly.com/kafka/0.8.1.1/kafka_2.9.2-0.8.1.1.tgz
tar xzf kafka_2.9.2-0.8.1.1.tgz
mv kafka_2.9.2-0.8.1.1 /kafka
adduser kafka
mkdir /kafka/logs/server{1,2,3} -p
echo 'kafka    soft    nofile    98304' >> /etc/security/limits.conf
echo 'kafka    hard    nofile    98304' >> /etc/security/limits.conf

echo "Setting up cluster config for kafka instances"
cp /kafka/config/server.properties /kafka/config/server1.properties
cp /kafka/config/server.properties /kafka/config/server2.properties
cp /kafka/config/server.properties /kafka/config/server3.properties

sed 's/broker.id=0/broker.id=1/' -i /kafka/config/server1.properties
sed 's/broker.id=0/broker.id=2/' -i /kafka/config/server2.properties
sed 's/broker.id=0/broker.id=3/' -i /kafka/config/server3.properties

sed 's/port=9092/port=9991/' -i /kafka/config/server1.properties
sed 's/port=9092/port=9992/' -i /kafka/config/server2.properties
sed 's/port=9092/port=9993/' -i /kafka/config/server3.properties

sed 's#log.dirs=/tmp/kafka-logs#log.dirs=/kafka/logs/server1#' -i /kafka/config/server1.properties
sed 's#log.dirs=/tmp/kafka-logs#log.dirs=/kafka/logs/server2#' -i /kafka/config/server2.properties
sed 's#log.dirs=/tmp/kafka-logs#log.dirs=/kafka/logs/server3#' -i /kafka/config/server3.properties

# Last step here, correct ownership
chown kafka /kafka -R


echo "Installing Supervisor"
easy_install supervisor

echo '#!/bin/bash
#
# Startup script for the Supervisor server
#
# Tested with Red Hat Enterprise Linux Server release 5.5
#
# chkconfig: 2345 85 15
# description: Supervisor is a client/server system that allows its users to \
#          monitor and control a number of processes on UNIX-like \
#          operating systems.
#
# processname: supervisord
# pidfile: /var/run/supervisord.pid

# Source function library.
. /etc/rc.d/init.d/functions

RETVAL=0
prog="supervisord"
SUPERVISORD=/usr/bin/supervisord
PID_FILE=/var/run/supervisord.pid

start()
{
    echo -n $"Starting $prog: "
    $SUPERVISORD -c /etc/supervisord.conf --pidfile $PID_FILE && success || failure
    RETVAL=$?
    echo
    return $RETVAL
}

stop()
{
    echo -n $"Stopping $prog: "
    killproc -p $PID_FILE -d 10 $SUPERVISORD
    RETVAL=$?
    echo
}

reload()
{
    echo -n $"Reloading $prog: "
    if [ -n "`pidfileofproc $SUPERVISORD`" ] ; then
        killproc $SUPERVISORD -HUP
    else
        # Fails if the pid file does not exist BEFORE the reload
        failure $"Reloading $prog"
    fi
    sleep 1
    if [ ! -e $PID_FILE ] ; then
        # Fails if the pid file does not exist AFTER the reload
        failure $"Reloading $prog"
    fi
    RETVAL=$?
    echo
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    reload)
        reload
        ;;
    status)
        status -p $PID_FILE $SUPERVISORD
        RETVAL=$?
        ;;
    *)
        echo $"Usage: $0 {start|stop|restart|reload|status}"
        RETVAL=1
esac
exit $RETVAL
' > /etc/init.d/supervisord

chmod +x /etc/init.d/supervisord

echo '
[unix_http_server]
file=/tmp/supervisor.sock   ; (the path to the socket file)

[supervisord]
logfile=/var/log/supervisord.log ; (main log file;default $CWD/supervisord.log)
logfile_maxbytes=50MB        ; (max main logfile bytes b4 rotation;default 50MB)
logfile_backups=10           ; (num of main logfile rotation backups;default 10)
loglevel=info                ; (log level;default info; others: debug,warn,trace)
pidfile=/tmp/supervisord.pid ; (supervisord pidfile;default supervisord.pid)
nodaemon=false               ; (start in foreground if true;default false)
minfds=1024                  ; (min. avail startup file descriptors;default 1024)
minprocs=200                 ; (min. avail process descriptors;default 200)

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock ; use a unix:// URL  for a unix socket

[program:zookeeper]
command=/kafka/bin/zookeeper-server-start.sh /kafka/config/zookeeper.properties
user=kafka
autorestart=true
stopsignal=KILL
stdout_logfile=/kafka/logs/zookeeper.stdout.log
stderr_logfile=/kafka/logs/zookeeper.stderr.log
priority=10

[program:kafka1]
command=/kafka/bin/kafka-server-start.sh /kafka/config/server1.properties
user=kafka
autorestart=true
stopsignal=KILL
stdout_logfile=/kafka/logs/server1/stdout.log
stderr_logfile=/kafka/logs/server1/stderr.log
priority=20

[program:kafka2]
command=/kafka/bin/kafka-server-start.sh /kafka/config/server2.properties
user=kafka
autorestart=true
stopsignal=KILL
stdout_logfile=/kafka/logs/server2/stdout.log
stderr_logfile=/kafka/logs/server2/stderr.log
priority=20

[program:kafka3]
command=/kafka/bin/kafka-server-start.sh /kafka/config/server3.properties
user=kafka
autorestart=true
stopsignal=KILL
stdout_logfile=/kafka/logs/server3/stdout.log
stderr_logfile=/kafka/logs/server3/stderr.log
priority=20

' > /etc/supervisord.conf

chkconfig supervisord on

echo "Starting ZK and Kafka"
/etc/init.d/supervisord start

echo "Done, login, cd /kafka and try some of the demo producers/consumers under the bin folder"
echo "Example:
    /kafka/bin/kafka-topics.sh --zookeeper=localhost:2181 --create --topic test --partitions 3 --replication-factor 2
    /kafka/bin/kafka-console-producer.sh --broker-list localhost:9991,localhost:9992,localhost:9993 --topic test
    /kafka/bin/kafka-console-consumer.sh --zookeeper localhost:2181 --topic test --from-beginning
"
