#!/bin/bash

# ident: watchperf-generic.sh, v4.0

#
#
# Revision History:
#
# Copyright (c) 2011 by Matthias.Muench@alice-dsl.de
# 3.0   2011/08/18 MM   - total rewrite, adjust timing and add dtrace,
#                       - added time control
# 3.1   2011/11/25 MM   - changed dtrace sources to come with the packet
# 3.2   2011/12/06 MM   - added use of config file (setup by configure_watchperf.sh)
#                       - added Linux support (minor)
#                       - added OS type string to timestamp header
#                       - added generic installation directory recognition during install
# 3.3   2013/01/24 MM   - learned some missing options on older RHEL versions
# 3.4   2013/04/23 MM   - added basic MacOS X support (Darwin version 8.11.1 tested)
#			- added `uname -a` output to timestamp - to identify results
#			- changed dtrace control totally (now really stops dtrace scripts)
#			- added signal control
# 3.5	2013/12/03 MM	- added capture of dtrace errors thrown if dtrace cannot cope with
#			- probe data due to resource limitation on CPU cores (as seen on T5220)
#			- added disable of dtrace for Solaris (per config or cmd line option)
#			- added disable of all but iostat (iostat only - except dtrace)
# 3.6	2014/01/28 MM	- changed standard output file name for mpstat -P ALL for Linux into mpstat.out
# 3.7	2014/09/18 MM	- added ZFS iostat support for Solaris
# 3.8	2015/03/16 MM	- added -kn as options to see NFS shares as well and generic support of any switches to
#			  iostat determined by the usage line of iostat: want to see: iostat -xcknNt 1 55
#			- added collection of static device mapper information on the system for disks (device links)
# 3.9	2018/04/23 MM	- added lsblk output for Linux
#			- disabled device links for Linux
# 4.0 2019/09/16 MM - minor cleanups
# 4.1 2019/09/18 MM - added OS_RELEASE to distinguish different Linux distributions (currently, added RHEL only)

#
#
#
####################
# SETTINGS
####################
#SOLARIS_D_LIST="writes.d reads.d seeksize_reads.d seeksize_writes.d whoio.d"
SOLARIS_D_LIST="writes.d reads.d seeksize_reads.d seeksize_writes.d"

PHYS_DEV_HDD=sdd


# read config values from config file in installation directory
INSTALL_DIR=####INSTALL_PATH####
. $INSTALL_DIR/.watchperf_settings


###DEBUG
DEBUG_PROCS=

#
# create a new timestamp
#
timestamp() {
        $CMD_ECHO "watchperf timestamp `$CMD_DATE +%d.%m.%Y-%H:%M:%S` $OSVERSION $OS_RELEASE"
}


###########################################################################
# 
# start of the main part
#
###########################################################################
usage() {
        echo "Usage: $0: [-o output_directory] [-t timespan]\n"
        echo "       -o output_directory - base output directory (subdirs marked with timestamp)"
        echo "       -t timespan - time in seconds to run"
}


#
# check arguments
#
# read arguments
oflag=0
tflag=0
while getopts o:t: name; do
        case $name in
                o)      oflag=1
                        DEST_PATH="$OPTARG";;

                t)      tflag=1
                        SLEEPTIME="$OPTARG";;

                ?)      usage
                        exit 2;;
        esac
done

if [ $tflag -ne 1 ]; then
        echo "$0 - ERROR: -t option must be set"
        usage
        exit 2
fi

if [ $oflag -eq 0 ]; then
        echo "$0 - ERROR: -o option must be set"
fi


CMD_BASE=$INSTALL_DIR
if [ ! -x $CMD_BASE/start_dtrace.sh ]; then
        echo "FATAL: please check - tools not installed into $CMD_BASE, permissions to directory are wrong or start_dtrace.sh is not executable - aborting."
        exit 1
fi

# 
# check if output dir exists (create if not)
#
if [ ! -d "$DEST_PATH" ]; then
        $CMD_MKDIR -p "$DEST_PATH"
        if [ ! -d "$DEST_PATH" ]; then
                $CMD_ECHO "unable to create output dir $DEST_PATH" 1>&2
                exit 13
        fi
fi 
if [ ! -w "$DEST_PATH" ]; then
        $CMD_ECHO "output directory $DEST_PATH not writable" 1>&2
        exit 13
fi

# 
# init some vars we might use later
#
OSVERSION=`$CMD_UNAME -a`
OS=`$CMD_UNAME -s`
case $OS in
        SunOS)  # Solaris supported only
                if [ "$OS" = "SunOS" ]; then
                        OS_REVISION=`$CMD_UNAME -r`
                        if [ `$CMD_EXPR "$OS_REVISION" : '\(.\)\..*'` != 5 ]; then
                                $CMD_ECHO "sorry, this script is for Solaris 2.x only" 1>&2
                                exit 48
                        fi
                        OS_MINOR=`$CMD_EXPR "$OS_REVISION" : '5.\(.*\)'`
                        
                        # 
                        # check for patch 106429-01 if we're running on Solaris 2.6
                        #
                        if [ $OS_MINOR -eq 6 ]; then
                                if [ -z "`$CMD_SHOWREV -p | $CMD_AWK '{print $2}' | grep 106429`" ]; then
                                        echo "please install patch 106429 before running this script" 1>&2
                                        echo "this is necessary to avoid a possible hang" 1>&2
                                        echo "exiting..." 1>&2
                                        exit 65
                                fi
                        fi
                fi
		# 
		# since we do invoke adb on the live kernel we need root privs
		#
		if [ `$CMD_EXPR "\`$CMD_ID\`" : 'uid=\([^(]*\).*'` != 0 ]; then
		        echo "this script requires root privileges" 1>&2
		        exit 1
		fi

		#
		# check for dtrace scripts and add all names found to the list
		#
		if [ $NO_DTRACE -eq 0 ] ; then
			SOL_DLIST=
			for DSCRIPT in `echo $SOLARIS_D_LIST`; do
		                if [ -r $CMD_BASE/$DSCRIPT ]; then
					SOL_DLIST="$SOL_DLIST $DSCRIPT"
				fi
			done
		fi
                ;;

        Linux)  # supported currently all Linux - not distinguished yet
		# Test iostat supported switches: -xcnNt would be nice, else -xct, -xcnt or -xcNt
		LX_IOSTAT_SWITCHES=`iostat -\? 2>&1|grep '\] \['|grep -v device|grep -v iostat|tr -d '[]|\-'|tr '[:blank:]' '\n'|grep [xcknNt]|tr -d '\n'`
		if [ -r /etc/redhat-release ]; then
			OS_RELEASE=RHEL
		fi
                ;;

        Darwin) # basic MacOS X support
                ;;

        *)      # unsupported OS
                echo "$0 - FATAL: unsupported OS - giving up."
                exit 1
                ;;
esac

# 
# here we do start with the actual work
#
cd $DEST_PATH

trap 'echo "$0: caught signal stopping processes";kill -HUP $DEBUG_PROCS $CHILDS 2>/dev/null; exit 0' 1 2 5 10 15 
RUNS=`expr $SLEEPTIME / 60`
CURRRUNS=0
while [ $CURRRUNS -lt $RUNS ] ; do
        
        case $OS in 
                SunOS)  # Solaris systems
                        timestamp >> iostat.out
                        $CMD_IOSTAT -Xxcn 1 55 >> iostat.out &
                        DEBUG_PROCS="$DEBUG_PROCS $!"
                        # timestamp >> iostat-z.out
                        # $CMD_IOSTAT -Xxzcn 1 55 >> iostat-z.out &
                        # DEBUG_PROCS="$DEBUG_PROCS $!"
                        timestamp >> iostat-xnz.out
                        $CMD_IOSTAT -xnz 1 55 >> iostat-xnz.out &
                        DEBUG_PROCS="$DEBUG_PROCS $!"

			# In case zfs is used: additional information from zpools wanted with io statistics
			if [ "XX`zpool list|grep 'no pools available'`" = "XX" ]; then
				# zpools found
	                        timestamp >> zpool-iostat.out
				$CMD_ZPOOL iostat -v 1 55 >> zpool-iostat.out &
	                        DEBUG_PROCS="$DEBUG_PROCS $!"
			else
				echo "no zpools found currently in the system" >> zpool-iostat.err
			fi
                        
			if [ $IOSTATONLY -eq 0 ]; then 
	                        timestamp >> netstat.out
	                        $CMD_NETSTAT -in >> netstat.out &
	                        DEBUG_PROCS="$DEBUG_PROCS $!"
	                        
	                        timestamp >> ipcs.out
	                        $CMD_IPCS -a >> ipcs.out &
	                        DEBUG_PROCS="$DEBUG_PROCS $!"
	                        
	                        timestamp >> vmstat.out
	                        $CMD_VMSTAT 1 55 >> vmstat.out &
	                        DEBUG_PROCS="$DEBUG_PROCS $!"
	                        
	                        timestamp >> mpstat.out
	                        $CMD_MPSTAT 1 55 >> mpstat.out &
	                        DEBUG_PROCS="$DEBUG_PROCS $!"
	                        
	                        #timestamp >> netstatk.out
	                        #$CMD_NETSTAT -k >> netstatk.out &
	                        #DEBUG_PROCS="$DEBUG_PROCS $!"
	                        
	                        if [ $OS_MINOR -gt 5 ]; then
	
	                                # timestamp >> dispq.out
	                                # /usr/bin/echo dispq | /usr/sbin/crash >> dispq.out &
	                                # DEBUG_PROCS="$DEBUG_PROCS $!"
	                                
	                                timestamp >> lockstat.out 
	                                $CMD_LOCKSTAT -w -p sleep 55 >> lockstat.out &
	                                DEBUG_PROCS="$DEBUG_PROCS $!"
	                        
	                        fi
			fi
			
			# use dtrace if not disabled
			if [ $NO_DTRACE -eq 0 ]; then
	                        # 
	                        # very special stuff at the end - Solaris only for now (MacOS may be future)
	                        #
	                        CHILDS=
				for D_SCRIPT in `echo $SOL_DLIST`; do
	       	                        timestamp >> $D_SCRIPT.out
					# /usr/sbin/dtrace -s $CMD_BASE/$D_SCRIPT & 2>&1 >/dev/null
					# KCHILD=$!
	
	                                $CMD_BASE/start_dtrace.sh $CMD_BASE/$D_SCRIPT 55 $D_SCRIPT.out 2>$D_SCRIPT.err &
					NCHILD=$!
					CHILDS="$CHILDS $NCHILD"
				done
				# echo "CHILDS=$CHILDS"
			fi

			sleep 55

			#
			# for vxvm installed and running:
			#
			if [ $IOSTATONLY -eq 0 ]; then 
	                        if `/usr/sbin/modinfo | /usr/xpg4/bin/grep -sqiw vxio` ; then
					timestamp >> vxiomem.out
					/usr/bin/echo 'voliomem_kvmap_size/X;voliomem_max_memory/X;vol_mem_allocated/X;vol_mem_needed/' |  /usr/bin/adb -k /dev/ksyms /dev/mem >> vxiomem.out 2>&1 &
       	                         DEBUG_PROCS="$DEBUG_PROCS $!"
				fi
			fi

			# kill all remaining dtrace childs
			if [ $NO_DTRACE -eq 0 ]; then
				kill $CHILDS 2>/dev/null

				sleep 1
				for i in `echo $CHILDS`; do
					# check for alive childs
					ps -p $i > /dev/null 2>&1
					if [ $? -eq 0 ]; then
						echo "still alive child  $i"
					fi
				done
			fi
                        
                        ;;
                
                Linux)  # any LINUX based system - not distinguished yet
                        timestamp >> iostat.out
                        timestamp LX_IOSTAT_OPTIONS=$LX_IOSTAT_SWITCHES >> iostat.err
			## ls -lR /dev/disk > dev_disk.out
                        timestamp >> lsblk.out
			lsblk >> lsblk.out
                        ## $CMD_IOSTAT -${LX_IOSTAT_SWITCHES} -p $PHYS_DEV_SDD 1 55 >> iostat.out &
                        $CMD_IOSTAT -${LX_IOSTAT_SWITCHES} 1 55 >> iostat.out &
                        DEBUG_PROCS="$DEBUG_PROCS $!"
                        # timestamp >> iostat-z.out 
                        # $CMD_IOSTAT -xzcN 1 55 >> iostat-z.out &
                        # DEBUG_PROCS="$DEBUG_PROCS $!"
                        ## changed to avoid -z option - some Linunx variants don't' use it
                        ## timestamp >> iostat-xNz.out
                        ## $CMD_IOSTAT -xNz 1 55 >> iostat-xNz.out &
                        ## DEBUG_PROCS="$DEBUG_PROCS $!"

                        
			if [ $IOSTATONLY -eq 0 ]; then 
	                        ### standard mpstat
	                        timestamp >> mpstat.out                        
				## changed to avoid -u option - it should be default anyway and older RHEL versions don't' have it         
	                        ## $CMD_MPSTAT -P ALL 1 55 >> mpstat.out &
	                        $CMD_MPSTAT -P ALL 1 55 >> mpstat.out &
	                        DEBUG_PROCS="$DEBUG_PROCS $!"
	
	                        ### only for performance troubleshooting
	                        # timestamp >> mpstat-A.out
	                        # $CMD_MPSTAT -A 1 55 >> mpstat-A.out &
	                        # DEBUG_PROCS="$DEBUG_PROCS $!"
	
	                        timestamp >> vmstat.out
	                        $CMD_VMSTAT -an 1 55 >> vmstat.out &
	                        DEBUG_PROCS="$DEBUG_PROCS $!"
	
	                        timestamp >> netstat.out
	                        $CMD_NETSTAT -in >> netstat.out &
	                        DEBUG_PROCS="$DEBUG_PROCS $!"
	
	                        timestamp >> ipcs.out
	                        $CMD_IPCS -a >> ipcs.out &
	                        DEBUG_PROCS="$DEBUG_PROCS $!"
			fi

                        sleep 60
                        ;;

                Darwin) # basic MacOS X
                        timestamp >> iostat.out
                        $CMD_IOSTAT -K -w 1 -c 55 >> iostat.out &
                        DEBUG_PROCS="$DEBUG_PROCS $!"
                        # timestamp >> iostat-z.out
                        # $CMD_IOSTAT -xzcN 1 55 >> iostat-z.out &
                        # DEBUG_PROCS="$DEBUG_PROCS $!"


			if [ $IOSTATONLY -eq 0 ]; then 
	                        ### standard mpstat
	                        ## timestamp >> mpstat.out
	                        ## $CMD_MPSTAT -P ALL 1 55 >> mpstat.out &
	                        ## DEBUG_PROCS="$DEBUG_PROCS $!"
	                        ### only for performance troubleshooting
	                        timestamp >> mpstat-A.out
	                        $CMD_MPSTAT -A 1 55 >> mpstat-A.out &
	                        DEBUG_PROCS="$DEBUG_PROCS $!"
	                        
	                        ### since vm_stat is useless because it cannot stop after a number of iterations we'll skip it too          
	                        ### only supported argument to vm_stat is interval (in seconds)
	                        ## timestamp >> vmstat.out
	                        ## $CMD_VMSTAT -an 1 55 >> vmstat.out &
	                        ## DEBUG_PROCS="$DEBUG_PROCS $!"
	
	                        timestamp >> netstat.out
	                        $CMD_NETSTAT -in >> netstat.out &
	                        DEBUG_PROCS="$DEBUG_PROCS $!"
	
	                        timestamp >> ipcs.out
	                        $CMD_IPCS -a >> ipcs.out &
	                        DEBUG_PROCS="$DEBUG_PROCS $!"
			fi

                        sleep 60
                        ;;
        esac
                
#       echo "PROCLIST kicked off= $DEBUG_PROCS"
#       for PROCID in `echo $DEBUG_PROCS`; do
#               PRCS=`ps -fp $PROCID|grep -v STIME`
#               if [ "XX$PRCS" != "XX" ]; then
#                       timestamp
#                       echo "  -- WARNING - Still running: $PRCS"
#               fi
#       done            
        #               
        # count up for next round
        #               
        CURRRUNS=` expr $CURRRUNS + 1`
done
trap 1 2 5 10 15       
                        
#Done.
