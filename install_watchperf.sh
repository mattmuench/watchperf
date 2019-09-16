#!/bin/bash
# ident: install_watchperf.sh, 2015/03/16, ver 1.5. (C) 2011-2015, Matthias.Muench@alice-dsl.de
#       MacOS X (bash) version
FILEID=install_watchperf.sh
#

#CHANGES:
#	ver 1.1:
#		- added MacOS X support
#		- added command slection for gzip and sleep
#	ver 1.2:
#		- removed README.txt (double effort to maintain not wanted)
#	ver 1.3:
#		- added -D option to disable dtrace on Solaris
#		- added check for proper install-ready files (INSTALL_DIR is set to ####INSTALL_PATH####)
#		- added -I option to run iostat only (no dtrace control with this option)
#	ver 1.4:
#		- added CMD_ZPOOL for zpool iostat data collection
#	ver 1.5:
#		- added space management in output directory

# Default settings for installation directory, output directory, time to run and gzip settings
#
DEFAULT_INSTALL_DIR=/var/tmp/watchperf
DEFAULT_OUTPUT_DIR=/tmp/watchperf
DEFAULT_TIMETORUN=5
DEFAULT_GZIP=-z
DEFAULT_NO_DTRACE=0
DEFAULT_IOSTATONLY=0
DEFAULT_MAXSPACE=1024000

#
#  File lists for files that need to be changed to know the installation path
#       and for files to be copied simply.
#
INSTALLFILES="control-watchperf.sh watchperf-generic.sh wrapper-controlwatchperf.sh"
COPYFILES="install_watchperf.sh INSTALL.txt reads.d seeksize_all.d seeksize_reads.d seeksize_writes.d start_dtrace.sh whoio.d writes.d"

#
# list of commands needed for the tool - all those ones must be discovered or explicitely ignored for a
#       specific OS
#
COMMANDLIST="CMD_ECHO CMD_BASENAME CMD_DATE CMD_EXPR CMD_ID CMD_MKDIR CMD_UNAME CMD_SHOWREV CMD_AWK CMD_VMSTAT CMD_IOSTAT CMD_PS CMD_MPSTAT CMD_IPCS CMD_NETSTAT CMD_LOCKSTAT CMD_GZIP CMD_SLEEP CMD_ZPOOL"

########################
# FUNCTIONS
########################
checkPath () {
        PROGNAME=$1
        # check path to program based on locate command
        if [ -z $PROGNAME ]; then
                echo "$0 - checkPath(): missing argument for function call." >&2
                exit 1
        fi

        PROG_PATH=`which $PROGNAME`
        if [ $? -eq 0 ]; then
                PROGBIN=$PROG_PATH
        else
                BINLIST=`locate -r bin/$PROGNAME\$`
                if [ "XX$BINLIST" != "XX" ]; then
                        for PROGBIN in $BINLIST; do
                                if [ -x $PROGBIN ]; then
                                        break;
                                fi
                        done
                else
                        echo "No reference in any directory ending in 'bin' found for: $PROGNAME" >&2
                        exit 1
                fi
        fi
        echo $PROGBIN
}


usage () {
        echo "usage: $FILEID [-i install_directory] [-o output_directory] [-t minutes] [-DIn] [-s space]"
        echo "       $FILEID -d" 
        echo "       $FILEID -h"
        echo "  -i install_directory    -       installation directory, where all scripts will be"
        echo "                                  copied to and configuration file will be created."
        echo "  -I                      -       only collect iostat data"
        echo "  -o output_directory     -       output directory, where all data will be dropped"
        echo "  -t minutes              -       minutes to run by default for single round"
        echo "  -n                      -       don't gzip files after all"
        echo "  -D                      -       don't activate dtrace even on Solaris"
        echo "  -d                      -       use default settings for installation"
        echo "  -h                      -       show more help info"
        echo "  -s                      -       max space in KB to be used for storage of data files"
}

usagehelp () {
        echo ""
        echo ""
        echo "Option -d:"
        echo "       The option specifies to use all default values as layed out below."
        echo "       To use only a subset of default settings one can specify the option"
        echo "       that will modify this specific setting on the command line."
        echo "       NOTE: At least one option must be used to modify one default setting"
        echo "             and begin installation, otherwise -d option must be used to"
        echo "             install the tool set with all defaults applied."
        echo ""
        echo "       The following values are defaults:"
        echo "             install_directory = $DEFAULT_INSTALL_DIR"
        echo "             output_directory  = $DEFAULT_OUTPUT_DIR"
        echo "             minutes           = $DEFAULT_TIMETORUN"
        echo "             gzip files ?      = $DEFAULT_GZIP"

        echo ""
        echo ""
        echo "Option -D:"
        echo "       On Solaris systems dtrace is used to collect IO size and IO offset"
        echo "       distribution. Since on some systems this might place a high load"
        echo "       onto a single core (like for t2 and T3 based CPUs) leading to"
        echo "       data drops for probes. To disable dtrace use this option."

        echo ""
        echo ""
        echo "Option -i:"
        echo "       Directory, where the tools files are dropped into."
        echo ""
        echo "       Default install directory is $DEFAULT_INSTALL_DIR (see -d option)."

        echo ""
        echo ""
        echo "Option -I:"
        echo "       If only iostat data is to be collected use this option to disable"
        echo "       all other probes (like mpstat, vmstat, netstat, etc.). Note, that"
        echo "       dtrace is not controlled by this option and must be disabled"
        echo "       separately with -D option, if needed."

        echo ""
        echo ""
        echo "Option -n:"
        echo "       Data files are tarred together for one time period (see TIME_TO_RUN)."
        echo "       If limited space is available but CPU compute power is not limited"
        echo "       already, one can gzip the tar files additionally."
        echo "       If CPU power is limited, disable gzip with -n option."
        echo ""
        echo "       Default is to use gzip (see -d option)."
        echo ""
        echo ""

        echo "Option -o:"
        echo "       Directory, where data is to be dropped into. The script will create "
        echo "       additional subdirectories therein and will do compression task here "
        echo "       as well."
        echo "       NOTE: remember to have enough free space available, IOPS free and"
        echo "             ensure to move data out of the directory just in time if this"
        echo "             is located on tmpfs file system (aka. /tmp)"
        echo ""
        echo "       Default output directory is $DEFAULT_OUTPUT_DIR (see -d option)."

        echo ""
        echo ""
        echo "Option -s:"
        echo "       The amount of data can become big if running longer or with complex"
        echo "       systems (more CPUs, cores, disks). In this case the user should watch"
        echo "       for limiting the usage of disk space in the output directory to avoid"
        echo "       exhausting the file system space. Limiting can be with specifying "
        echo "       a lot of space if free space is not an issue - even several GB."
        echo "       Remember to specify space limitation in KB: 1 MB = 1024, 100 MB = 102400"
        echo "       5 GB = 5242880, for instance. Default setting is 1 GB = 1024000"

        echo ""
        echo ""
        echo "Option -t:"
        echo "       If havy load is expected, with this you can throttle the load"
        echo "       generated to few minutes only and control next start (regular run is"
        echo "       recommended) via crond."
        echo "       Best is to use 5 minutes and run it every 5 minutes via crond to avoid"
        echo "       prolonged run time for tar and compression."
        echo ""
        echo "       However, one should run this for at least 24 hrs to collect the data"
        echo "       from a whole period (day). For tracking backup or end-of-quarter"
        echo "       activity, one should run it over the weekend, for 7 days before and"
        echo "       2 days after quarter end, or whatever covers the pre-, high load and"
        echo "       post-period."
        echo ""
        echo "       However, don't use longer run times for this script than 24 hrs in one"
        echo "       rush (not a problem to run it multiple times as layed out above). So,"
        echo "       using TIME_TO_RUN > 1439 is deprecated."
        echo ""
        echo "       Default is $DEFAULT_TIMETORUN minutes (see -d option)."


}

#######################
#   MAIN
#######################

#
# set all values to defaults initially
#
INSTALL_DIR=$DEFAULT_INSTALL_DIR
OUTPUT_DIR=$DEFAULT_OUTPUT_DIR
TIMETORUN=$DEFAULT_TIMETORUN
GZIP=$DEFAULT_GZIP
NO_DTRACE=$DEFAULT_NO_DTRACE
IOSTATONLY=$DEFAULT_IOSTATONLY
MAXSPACE=$DEFAULT_MAXSPACE

#
# parse command line options and arguments
#
dflag=0
Dflag=0
hflag=0
iflag=0
Iflag=0
nflag=0
oflag=0
sflag=0
tflag=0
while getopts "dDhIni:o:s:t:\?" ARGS ; do
        case $ARGS in
                d)      # set all options to defaults
                        dflag=1
			;;
                D)      # disable dtrace for Solaris
                        Dflag=1
			NO_DTRACE=1
			;;
                i)      # install directory
                        iflag=1
			INSTALL_DIR=$OPTARG
			;;
                I)      # only collect iostat data
                        Iflag=1
			IOSTATONLY=1
			;;
                h)      usage
                        usagehelp
                        exit 0
                        ;;
                n)      # disable gzip
                        nflag=1
                        GZIP=
                        ;;
                o)      # output directory
                        oflag=1
			OUTPUT_DIR=$OPTARG
			;;
                s)      # max space to be used
                        sflag=1
			MAXSPACE=$OPTARG
			;;
                t)      # time to run
                        tflag=1
			TIMETORUN=$OPTARG
			;;
                \?)     usage
                        exit 0
                        ;;
                *)      # unknown option
                        echo "$0 - FATAL: unknown option used."
                        usage
                        exit 1
        esac
done

# check the other options to set correct values
if [ $iflag -ne 1 -a $oflag -ne 1 -a $tflag -ne 1 -a $sflag -ne 1 -a $nflag -ne 1 -a $Dflag -ne 1 -a $Iflag -ne 1 ]; then
        if [ $dflag -ne 1 ]; then
                echo "$0 - ERROR: at least one option needs to be specified - use -h to get help."
                usage
                exit 1
        else
                # set all to defaults
                INSTALL_DIR=$DEFAULT_INSTALL_DIR
                OUTPUT_DIR=$DEFAULT_OUTPUT_DIR
                TIMETORUN=$DEFAULT_TIMETORUN
                GZIP=$DEFAULT_GZIP
		NO_DTRACE=$DEFAULT_NO_DTRACE
		IOSTATONLY=$DEFAULT_IOSTATONLY
		MAXSPACE=$DEFAULT_MAXSPACE
        fi
else
        if [ $dflag -eq 1 ]; then
                echo "$0 - ERROR: -d option cannot be used together with any other option - use -h to get help."
                usage
                exit 1
        fi
fi

#
# setup correct binary path for used commands according to OS used
#
PROG_FAIL=0
CMD_UNAME=`checkPath uname`
if [ $? -ne 0 ]; then
        echo "$0 - FATAL: unable to locate uname command"
        exit 1
else
        OSINFO=`uname -s`
        case $OSINFO in
                Linux)  # set paths to programs - use checkPath function locate proper path
                        CMD_ECHO=`checkPath echo`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_BASENAME=`checkPath basename`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_DATE=`checkPath date`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_EXPR=`checkPath expr`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_ID=`checkPath id`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_MKDIR=`checkPath mkdir`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_UNAME=`checkPath uname`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        ### CMD_SHOWREV=`checkPath showrev`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_AWK=`checkPath awk`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_VMSTAT=`checkPath vmstat`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_IOSTAT=`checkPath iostat`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_PS=`checkPath ps`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_MPSTAT=`checkPath mpstat`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_IPCS=`checkPath ipcs`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_NETSTAT=`checkPath netstat`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_GZIP=`checkPath gzip`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        CMD_SLEEP=`checkPath sleep`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        ### CMD_LOCKSTAT=`checkPath lockstat`; if [ $? -ne 0 ]; then PROG_FAIL=1; fi
                        if [ $PROG_FAIL -eq 1 ]; then
                                echo "$0 - ERROR: unable to determine path for some commands - exiting."
                                exit 1
                        fi
                        ;;

                SunOS)  # set paths according to list:

                        CMD_ECHO=/bin/echo
                        CMD_BASENAME=/bin/basename
                        CMD_DATE=/usr/bin/date
                        CMD_EXPR=/usr/bin/expr
                        CMD_ID=/bin/id
                        CMD_MKDIR=/usr/bin/mkdir
                        CMD_UNAME=/usr/bin/uname
                        CMD_SHOWREV=/usr/bin/showrev
                        CMD_AWK=/usr/bin/awk
                        CMD_VMSTAT=/usr/bin/vmstat
                        CMD_IOSTAT=/usr/bin/iostat
                        CMD_ZPOOL=/usr/sbin/zpool
                        CMD_PS=/usr/bin/ps
                        CMD_MPSTAT=/usr/bin/mpstat
                        CMD_IPCS=/usr/bin/ipcs
                        CMD_NETSTAT=/usr/bin/netstat
                        CMD_LOCKSTAT=/usr/sbin/lockstat
			CMD_GZIP=/usr/bin/gzip
			CMD_SLEEP=/usr/bin/sleep
                        ;;

                Darwin)  # set paths according to list:

                        CMD_ECHO=/bin/echo
                        CMD_BASENAME=/usr/bin/basename
                        CMD_DATE=/bin/date
                        CMD_EXPR=/bin/expr
                        CMD_ID=/usr/bin/id
                        CMD_MKDIR=/bin/mkdir
                        CMD_UNAME=/usr/bin/uname
                        CMD_AWK=/usr/bin/awk
                        CMD_VMSTAT=/usr/bin/vmstat
                        CMD_IOSTAT=/usr/sbin/iostat
                        CMD_PS=/bin/ps
                        # CMD_MPSTAT=/usr/bin/mpstat
                        CMD_IPCS=/usr/bin/ipcs
                        CMD_NETSTAT=/usr/sbin/netstat
                        # CMD_LOCKSTAT=/usr/sbin/lockstat
			CMD_GZIP=/usr/bin/gzip
			CMD_SLEEP=/bin/sleep
                        ;;

                *)      # unknown OS
                        echo "$0 - ERROR: unknown OS - cannot locate program bin paths."
                        exit 1
        esac
fi


#
# set cfg file location to installation directory
#
CFGFILE=$INSTALL_DIR/.watchperf_settings

#
# create directories and set permissions
#
if [ -d $INSTALL_DIR ]; then
        echo "$0 - ERROR: install directory $INSTALL_DIR already exists. Free it up manually, if desired, or choose another one."
        exit 2
else
        $CMD_MKDIR -p $INSTALL_DIR
        if [ $? -ne 0 ]; then
                echo "$0 - ERROR: unable to create install dir $INSTALL_DIR. Giving up."
                exit 1
        fi
fi

if [ -d $OUTPUT_DIR ]; then
        echo "$0 - ERROR: output directory $OUTPUT_DIR already exists. Free it up manually, if desired, or choose another one."
        exit 2
else
        $CMD_MKDIR -p $OUTPUT_DIR
        if [ $? -ne 0 ]; then
                echo "$0 - ERROR: unable to create output dir $OUTPUT_DIR. Giving up."
                exit 1
        fi
fi

############################
# WRITING CONFIGFILE
############################
#
# if all paths are known, setup .watchperf_settings in destination directory
#

# cleanup first
if [ -f $CFGFILE ]; then
        rm -f $CFGFILE
        if [ $? -ne 0 ]; then
                echo "$0 - FATAL: unable to cleanup existing config file ($CFGFILE). Giving up."
                exit 3
        fi
fi

#
# write all command path settings out into config file
#
for CMDS in `echo $COMMANDLIST`; do
        eval eval echo "$CMDS='$'$CMDS" >>$CFGFILE
done

#
# store directory settings in config file
#
echo "CMD_DIR=$INSTALL_DIR" >>$CFGFILE
echo "OUTPUT_DIR=$OUTPUT_DIR" >>$CFGFILE
echo "TIME_TO_RUN=$TIMETORUN" >>$CFGFILE
echo "GZIP=$GZIP" >>$CFGFILE
echo "NO_DTRACE=$NO_DTRACE" >>$CFGFILE
echo "IOSTATONLY=$IOSTATONLY" >>$CFGFILE
echo "MAXSPACE=$MAXSPACE" >>$CFGFILE

echo "Configuration file created as $CFGFILE."

#######
# Install all files into installation directory
#######

#
# First, install the scripts with native install dir knowledge and install those.
#
for TXFILE in `echo $INSTALLFILES`; do
	if [ "XX`grep '####INSTALL_PATH####' $TXFILE`" = "XX" ]; then
		echo "$0 - FATAL: cannot install files properly; missing generic install path signature."
		echo "$0          Please get back to source to get proper crafted installation pack."
		exit 1
	fi
        TT=`echo $INSTALL_DIR |sed 's/\//\\\\\//g'`
        cat $TXFILE |sed 's/####INSTALL_PATH####/'$TT/g > $INSTALL_DIR/$TXFILE
        chmod 755 $INSTALL_DIR/$TXFILE
done

#
#  transfer files to be copied only
#
cp -r $COPYFILES $INSTALL_DIR
if [ $? -ne 0 ]; then
        echo "$0 - FATAL: failed to copy files into $INSTALL_DIR."
        exit 1
fi

echo "Installation completed."
#Done.

