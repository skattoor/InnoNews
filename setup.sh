#! /bin/sh

# Most used actions for InnoNews management
# author : Stephane Kattoor

ES_SERVER='localhost'
ES_API="http://${ES_SERVER}:9200"
ES_PIDFILE="/tmp/elastic.pid"

INDEX=news

HOMEDIR=/home/skattoor/InnoNews
FEEDS=${HOMEDIR}/feeds
EMAILS=${HOMEDIR}/emails
DEBUG=${HOMEDIR}/debug
TMP_DIRS="FEEDS DEBUG EMAILS"

echo "Using ES API :" $ES_API
echo

# curl -XGET $ES_API/_cat?pretty
case "$1" in
	setup)
		# Installs default mapping and create directories #HELP
		echo "Installing default mapping"
		curl -XPUT $ES_API/_template/news_template_1?pretty -d @news-template.json
		for i in ${TMP_DIRS}
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
		# Drops indices, empty directories (except if file is prefixed by manual- #HELP
		echo "Dropping indices"
		curl -XDELETE ${ES_API}/${INDEX}'*'?pretty
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
		echo "Stopping Elasticsearch"
		if [ -r ${ES_PIDFILE} ]
		then
			sudo kill -TERM `cat ${ES_PIDFILE}`
			i=0
			while [ -e ${ES_PIDFILE} -a \( $i -lt 10 \) ]
			do
				echo "Waiting for Elasticsearch to stop..."
				i=`expr $i + 1`
				sleep 1
			done
			if [ -e ${ES_PIDFILE} ]
			then
				echo "Failed : Didn't stop in a timely manner"
				ls -l ${ES_PIDFILE}
				exit 1
			else
				echo Success
			fi
		else
			echo "Failed : No PIDFILE in ${ES_PIDFILE}."
		fi
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
		cat $0 | grep -E ')|#HELP' | sed -e 's/)$/:/' -e 's/#HELP//' -e 's/# //' | grep -Fv 's/#HELP//'
		;;
esac
