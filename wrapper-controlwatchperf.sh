#!/bin/bash

# ident: wrapper-controlwatchperf.sh, v1.1, 2011/12/07 - (C)2011,Matthias.Muench@alice-dsl.de

# Changes:
#       ver 1.1:
#               added generic installation directory recognition during install


# read config from config file in the installation directory
INSTALL_DIR=####INSTALL_PATH####
. $INSTALL_DIR/.watchperf_settings

CURR_DIR=`pwd`
if [ "XX$CURR_DIR" = "XX" ]; then
        echo "Unable to determine current working directory - will not return after finish to that directory !"
        NO_RETURN=1
else
        NO_RETURN=0
fi
cd $CMD_DIR
$CMD_DIR/control-watchperf.sh -o $OUTPUT_DIR -t $TIME_TO_RUN $GZIP
if [ $NO_RETURN -eq 1 ]; then
        echo "WARNING: finished script but now you are in directory $CMD_DIR !"
else
        cd $CURR_DIR
        if [ "XX`pwd`" != "XX$CURR_DIR" ]; then
                echo "WARNING: finished script but now you are in directory $CMD_DIR - unable to change back to previous CWD !"
        fi
fi

#Done.
