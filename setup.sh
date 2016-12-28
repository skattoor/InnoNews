#! /bin/sh

ES_SERVER='localhost'
ES_API="http://${ES_SERVER}:9200"
ES_PIDFILE="/tmp/elastic.pid"

INDEX=news

echo "Using ES API :" $ES_API
echo

# curl -XGET $ES_API/_cat?pretty
case "$1" in
	setup)
		# Will install default mapping #HELP
		echo "Installing default mapping"
		curl -XPUT $ES_API/_template/news_template_1?pretty -d @news-template.json
		;;
	cleanup)
		# Will drop indices #HELP
		echo "Dropping indices"
		curl -XDELETE ${ES_API}/${INDEX}'*'?pretty
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
		# shows status of Elasticsearch, Kibana, NiFi #HELP
		ps waux | grep -Ei 'elastic|node|nifi' --color='auto'
		;;
	*|help)
		# Prints this help #HELP
		echo "Use one of the following actions :"
		cat $0 | grep -E ')|#HELP' | sed -e 's/)$/:/' -e 's/#HELP//' -e 's/# //' | grep -Fv 's/#HELP//'
		;;
esac
