#! /bin/sh

# Most used actions for InnoNews management
# author : Stephane Kattoor

ES_SERVER='localhost'
ES_API="http://${ES_SERVER}:9200"
ES_PIDFILE="/tmp/elastic.pid"
ES_INDEX=news

KIBANA_PIDFILE="/tmp/kibana.pid"
KIBANA_LOG="/home/data/elk/logs/kibana/kibana.log"
KIBANA_ERR="/home/data/elk/logs/kibana/kibana.err"

LOGSTASH_PIDFILE="/tmp/logstash.pid"
LOGSTASH_LOG="/home/data/elk/logs/logstash/logstash.log"
LOGSTASH_ERR="/home/data/elk/logs/logstash/logstash.err"


HOMEDIR=/home/data/elk/data/innonews
FEEDS=${HOMEDIR}/feeds
EMAILS=${HOMEDIR}/emails
EMAILBODIES=${HOMEDIR}/emailBodies
DEBUG=${HOMEDIR}/debug
WEBSITEFAILED=${HOMEDIR}/websitesFailed
WEBSITETOIMPORT=${HOMEDIR}/websitesToImport
TMP_DIRS="FEEDS DEBUG EMAILS WEBSITEFAILED"
ALL_DIRS="${TMP_DIRS} EMAILBODIES WEBSITETOIMPORT"

echo "Using ES API :" $ES_API
echo

stopDaemon() {
	soft=$1
	pidfile=$2

	echo "Stopping $soft"
	if [ -r $pidfile ]
	then
		sudo kill -TERM `cat $pidfile`
		i=0
		while [ -d /proc/`cat $pidfile` -a \( $i -lt 10 \) ]
		do
			echo "Waiting for $soft to stop..."
			i=`expr $i + 1`
			sleep 1
		done
		if [ -d /proc/`cat $pidfile` ]
		then
			echo "Failed : $soft didn't stop in a timely manner"
			ls -l $pidfile
			exit 1
		else
			echo Success
		fi
	else
		echo "Failed : No PIDFILE in $pidfile."
	fi
}

# curl -XGET $ES_API/_cat?pretty
case "$1" in
	setup)
		# Installs default mapping and create directories #HELP
		echo "Installing default mapping"
		curl -XPUT $ES_API/_template/news_template_1?pretty -d @news-template.json
		for i in ${ALL_DIRS}
		do
			echo Creating $i
			if mkdir ${!i}
			then
				echo Successully created ${!i}
			else
				echo Failed to create ${!i}, check by yourself
			fi
		done
		;;
	cleanup)
		# Drops indices, empty directories (except if file is prefixed by manual-) #HELP
		# ATTENTION : Use it and you WILL lose data #HELP
		# "Now I am become Death, the destroyer of worlds"
		
		echo "Dropping indices"
		curl -XDELETE ${ES_API}/${ES_INDEX}'*'?pretty
		echo "Cleaning up directories"
		for i in ${TMP_DIRS}
		do
			echo Purging $i
			if find ${!i} -type f -not -name "manual*" -print0 | xargs -0 rm -f
			then
				echo Successully purged ${!i}
			else
				echo Failed to purge ${!i}, check by yourself
			fi
		done
		;;
	startES)
		# Starts local Elasticsearch node #HELP
		if [ -e ${ES_PIDFILE} ]
		then
			echo "Failed : ES seems to be already started"
			ls -l ${ES_PIDFILE}
			exit 1
		else
			echo "Starting the Elasticsearch as a daemon"
			sudo su - elasticsearch -c "/opt/elasticsearch/bin/elasticsearch -d -p ${ES_PIDFILE}"
		fi
		;;
	stopES)
		# Stops local Elasticsearch node #HELP
		stopDaemon "Elasticsearch" ${ES_PIDFILE}
		;;
	
	startNiFi)
		# Starts NiFi #HELP
		/opt/nifi/bin/nifi.sh start
		;;
	stopNiFi)
		# Stops NiFi #HELP
		/opt/nifi/bin/nifi.sh stop
		;;
	startLogstash)
		# Starts Logstash #HELP
		nohup /opt/logstash/bin/logstash -f /home/data/elk/config/logstash/ >> $LOGSTASH_LOG 2>> $LOGSTASH_ERR &
		echo $! > ${LOGSTASH_PIDFILE}
		;;
	stopLogstash)
		# Stops Logstash #HELP
		stopDaemon "Logstash" ${LOGSTASH_PIDFILE}
		;;
	startKibana)
		# Starts Kibana #HELP
		nohup /opt/kibana/bin/kibana -c /home/data/elk/config/kibana/kibana.yml >> $KIBANA_LOG 2>> $KIBANA_ERR &
		echo $! > ${KIBANA_PIDFILE}
		;;
	stopKibana)
		# Stops Kibana #HELP
		stopDaemon "Kibana" ${KIBANA_PIDFILE}
		;;
	start)
		# Starts the whole stack #HELP
		startES
		startKibana
		startNiFi
		startLogstash
		;;
	stop)
		# Stops the whole stack #HELP
		stopLogstash
		stopNiFi
		stopKibana
		stopES
		;;
	status)
		# Shows status of Elasticsearch, Kibana, NiFi #HELP
		ps waux | grep -Ei 'elastic|node|nifi' --color='auto'
		;;
	statusES)
		# Shows ES indices #HELP
		curl -XGET ${ES_API}/_cat/indices
		;;
	*|help)
		# Prints this help #HELP
		echo "Use one of the following actions :"
		cat $0 | grep -E '[a-zA-Z]\)|#HELP' | sed -e 's/)$/:/' -e 's/#HELP//' -e 's/# //' | grep -Fv 's/#HELP//'
		;;
esac
