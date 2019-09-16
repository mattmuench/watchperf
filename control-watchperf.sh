#!/bin/bash
# ident: control-watchperf.sh, ver 1.5, 2015/03/16. (C) 2011-2015,matthias.muench@alice-dsl.de
# control watchperf script in time: kill after timespan is over
#       - to allow use in cron over a limited time
##set -x

# CHANGES
#
# ver 1.1:
#       - changed control of child processes to kill only those that still running and recheck for it after killing
# ver 1.2:
#       - use of generel watchperf script
#       - allow switch based gzip of tar files
# ver 1.3:
#       - added generic install path recognition during installation
# ver 1.4:
#       - added MacOS X (Darwin) support
#	- added use of .watchperf_settings script to use proper commands
#	- changed to /bin/bash for comamnd interpreter (MacOS doesn't have a Bourne-Shell)
#	- changed default output dir to /tmp/watchperf
# ver 1.5:
#	- added space management in output directory




INSTALL_DIR=####INSTALL_PATH####
WATCH_SCRIPT=$INSTALL_DIR/watchperf-generic.sh
. $INSTALL_DIR/.watchperf_settings



CURR_DIR=`pwd`
if [ $? -ne 0 ]; then
        echo "$0 - FATAL: failed to get current working directory"
        exit 1
fi



# read arguments
oflag=0
tflag=0
zflag=0
while getopts zo:t: name; do
        case $name in
                o)      oflag=1
                        OUTDIR="$OPTARG";;

                t)      tflag=1
                        TIME_TO_RUN="$OPTARG";;

                z)      zflag=1;;

                ?)      echo "Usage: $0: [-o output_directory] [-t timespan] [-z]\n"                        echo "       -o output_directory - base output directory (subdirs marked with timestamp)"                   
                        echo "       -t timespan - time in minutes after which the script will stop" 
                        echo "       -z          - gzip tar file after all (needs additional compute power)"
                        exit 2;;
        esac
done

if [ $tflag -ne 1 ]; then 
        echo "$0 - ERROR: -t option must be set"
        exit 2
fi

DATE_START=`date '+%Y%m%d-%H%M%S'`

if [ $oflag -eq 0 ]; then
        DATA_DIR=/tmp/watchperf
else    
        DATA_DIR=$OUTDIR
fi
BASE_DATA_DIR=$DATA_DIR/watchperf-$DATE_START
if [ ! -d $BASE_DATA_DIR ]; then
        mkdir -p $BASE_DATA_DIR
        if [ $? -ne 0 ]; then
                echo "$0 - FATAL: unable to create data output directory"
                exit 12
        fi
fi

# 
# time in seconds we'll need
#
SLEEP_TIME=`expr $TIME_TO_RUN \* 60`

# 
# kick off the watchperf script
#
trap 'kill -HUP $WATCH_PID; echo killed watchperf script; exit 0' 1 2 5 10 15
$WATCH_SCRIPT -o $BASE_DATA_DIR -t $SLEEP_TIME &

WATCH_PID=$!
$CMD_SLEEP $SLEEP_TIME
$CMD_SLEEP 5

MYUNAME=`$CMD_UNAME -s`
case $MYUNAME in
	SunOS|Linux)	# support ps -ef an ps -p system V style arguments
			ps -p $WATCH_PID >/dev/null
			if [ $? -eq 0 ]; then
			        # watchperf script is still running - let's kill it
			        #       - first kill all childs of the watchperf script
			        CHILDS=`ps -ef|grep $WATCH_PID|grep -v grep|awk '{print $2":"$3}'|grep -v $WATCH_PID:|cut -d: -f1`
			        for WATCH_CHILD in `echo $CHILDS`; do
			                ps -p $WATCH_CHILD >/dev/null
			                if [ $? -eq 0 ]; then
			                        kill -HUP $WATCH_CHILD
			                        sleep 1
			                        ps -p $WATCH_CHILD >/dev/null
			                        if [ $? -eq 0 ]; then                                echo "$0 - WARNING: cannot kill some of childs of watchperf script - process: $WATCH_CHILD"      
			                        fi
			                fi
			        done
			        
			        ps -p $WATCH_PID >/dev/null
			        if [ $? -eq 0 ]; then
			                kill -HUP $WATCH_PID
			                sleep 1
			                ps -p $WATCH_PID >/dev/null
			                if [ $? -eq 0 ]; then
			                        echo "$0 - FATAL: cannot kill watchperf script"
			                        exit 10
			                fi
			        fi
			fi
			;;

	Darwin)		# support only BSD style arguments - ps ax, etc.
			PID_LOOKUP=`ps -p $WATCH_PID|grep -v PID|grep -v "TIME COMMAND"|grep -v TT` >/dev/null
			if [ "XX$PID_LOOKUP" != "XX" ]; then
			        # watchperf script is still running - let's kill it
			        #       - first kill all childs of the watchsystem script
			        CHILDS=`ps -alx|grep $WATCH_PID|grep -v grep|awk '{print $2":"$3}'|grep -v $WATCH_PID:|cut -d: -f1`
			        for WATCH_CHILD in `echo $CHILDS`; do
					WPID_LOOKUP=`ps -p $WATCH_CHILD|grep -v PID|grep -v "TIME COMMAND"|grep -v TT` >/dev/null
					if [ "XX$WPID_LOOKUP" != "XX" ]; then
			                        kill -HUP $WATCH_CHILD
			                        sleep 1
						WPID_LOOKUP=`ps -p $WATCH_CHILD|grep -v PID|grep -v "TIME COMMAND"|grep -v TT` >/dev/null
						if [ "XX$WPID_LOOKUP" != "XX" ]; then
			                        	echo "$0 - WARNING: cannot kill some of childs of watchsystem script - process: $WATCH_CHILD"      
			                        fi
			                fi
			        done
			        
			        # watchperf script is still running - let's kill it
				PID_LOOKUP=`ps -p $WATCH_PID|grep -v PID|grep -v "TIME COMMAND"|grep -v TT` >/dev/null
				if [ "XX$PID_LOOKUP" != "XX" ]; then
			                kill -HUP $WATCH_PID
			                sleep 1
					PID_LOOKUP=`ps -p $WATCH_PID|grep -v PID|grep -v "TIME COMMAND"|grep -v TT` >/dev/null
					if [ "XX$PID_LOOKUP" != "XX" ]; then
			                        echo "$0 - FATAL: cannot kill watchperf script"
			                        exit 10
			                fi
			        fi
			fi
			;;

	*)		# unsupported OS
			echo "$0 - FATAL: unsupported OS - giving up."
			echo "Please kill remaining childs manually !"
			exit 1
			;;
esac


# tar all current snapshot's data together and name the tar after the date/time started at
cd $DATA_DIR

tar cf watchperf-$DATE_START.tar watchperf-$DATE_START
if [ $zflag -eq 1 ]; then
        # gzip it
        $CMD_GZIP watchperf-$DATE_START.tar
fi
         
# remove all old files
rm -r watchperf-$DATE_START
if [ $? -ne 0 ]; then
        echo "$0 - cannot remove old files in directory $DATA_DIR/watchperf-$DATE_START"
        exit 1
fi
# NG: watch for keeping the data directory within set limits - if more space is consumed remove the oldest file until reached the limit again
if [ $MAXSPACE -ne 0 ]; then
	CURR_SPACE=`du -sk $DATA_DIR|awk '{print $1}'`
#	if [ $CURR_SPACE -gt $MAXSPACE ]; then
#		LIMIT_REACHED=1
#	else
#		LIMIT_REACHED=0
#	fi
#	while [ $LIMIT_REACHED ]; do
	while [ $CURR_SPACE -gt $MAXSPACE ]; do
		OLDEST_FILE=`ls -t $DATA_DIR|tail -1`
		rm -rf $DATA_DIR/$OLDEST_FILE
		CURR_SPACE=`du -sk $DATA_DIR|awk '{print $1}'`
	done
fi
trap 1 2 5 10 15
#Done.
