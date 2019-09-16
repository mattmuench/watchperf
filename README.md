README of watchperf package: - ver 1.9.0, 2019/09/04
-----------------------------------------------
NOTES:

- This package must be installed, because install script sets proper paths for destination environment (install dir, output dir and location of tools). 

  The files shouldn't be simply moved or copied; instead, once a change is needed to the location it should be reinstalled into new paths.
  
  When moving the files into another directory inside the same machine the files cannot find proper settings anymore. This affects the configuration file and the output path.

  When copying the files onto another server and perhaps platform, the tools might not be found.
	  
- It supports Solaris 10 SPARC/x64, generic Linux versions and MacOS X. Note that MacOS X support is very limited in terms of performance data because of limitations in the standard tools.

- To run the tool successfully on Linux systems systools (iostat, vmstat, mpstat, etc.) *must be installed* on the system.

- Having too large data files makes it difficult to compress the files quickly before starting the whole thing again. Although placing the drop directory into tmpfs (i.e. /tmp) makes it very quick, some time is needed by the gzip itself. Running for 5 minutes would be a good  fit.

- All configuration can be done during installation with command line arguments; please use `./install_watchperf.sh -h` to figure out on possible selections.
  Once installed, changes can be applied by modifying `.watchperf_settings` in the installation director which defaults to `/var/tmp/watchperf`.

- It only *collects* data - nothing is done with the data within these scripts.

HOWTO:

1) unpack tar/tgz file into any directory (this *must be not* the install dir)

2) decide on following aspects of installation and configuration (just think about it):

   - output directory (for log file and data directories)
     - it can use /tmp as formal base but be aware of the volatile type of it (at
          least this is the case on Solaris OS, Linux might be auto-cleaned during
          reboot, depending on policy layed out by admin)
     - any other productive file system will need to accomodate additional
          load (from size of data, I/O (few KB) and IOPS (some when writing
          and compressing) - so, don't use starved local disks under heavy load --
          it could slow down your base OS (a short manual run of iostat will show
          you load of desired drives)
     - ensure to have enough free space available in the volume/disk used !

   - installation directory
        - install directory is used for installation of the files from the
          tool archive plus a small configuration file
        - the install directory must be reable for root
        - the install directory doesn't need to be writeable after installation
          is finished

   - time to run per start of collection script:

        If heavy load is expected, with this you can throttle the load
        generated to few minutes only and control next start (regular run is
        recommended) via crond or similar tool.
        *Best is to use 5 minutes and run it every 5 minutes via crond to avoid
        prolonged run time for tar and compression.*
        However, for watching system performance for identifying trouble, one 
        should run this for at least 24 hrs to collect the data from a whole
        period (day). For tracking backup or end-of-quarter activity, one should
        run it over the weekend, for 7 days before and 2 days after quarter end,
        or whatever covers the pre-, high load and  post-period.
        Avoid longer run times for this script with more than 24 hrs in one 
        rush (not a problem to run it multiple times as layed out above). So,
        using `TIME_TO_RUN` > 1440 is deprecated.
   
   - use of gzip at the end of each collection 
   
        Data files are tarred together for one time period (see TIME_TO_RUN).
        If limited space is available but CPU compute power is not limited
        already, one can gzip the tar files additionally.
        If CPU power is limited, disable gzip with `-n` option.
	However, it's generating a lot of data - so avoid running without.

   - set proper space to facilitate long term run and free space in filesystem
   
	The amount of data can become big if running longer or on complex
	systems (more CPUs, cores, disks). In this case, the user limit
	the usage of disk space in the output directory to avoid exhausting 
	the file system space. Limiting can be done by specifying 
	a lot of space if free space is not an issue - even several GB.
	Remember to specify space limitation in KB: 1 MB = 1024, 100 MB = 102400
	5 GB = 5242880, for instance. Default setting is 1 GB = 1024000
	
	NOTE: If limit is reached, the oldest files with the watchperf specific naming
	are deleted automatically from the data directory. So, avoid to store anything
	else into the same directory (or just create an additional directory within
	the same to avoid kicking off auto-deletion upon false positives). It's
	looking for consumed space using `du -sk $DEFAUL_OUTPUT_DIR` and everything
	placed therein or underneath will be counted against the `$MAXSPACE`.


3) run `install_watchperf.sh` to install the tool and configure it

   For further information on the installation, run `install_watchperf.sh -h` .
        
   It's recommended to accept the default settings (just run install_watchperf.sh -d)
        Default settings are:
```
                DEFAULT_INSTALL_DIR=/var/tmp/watchperf
                DEFAULT_OUTPUT_DIR=/tmp/watchperf
                DEFAULT_TIMETORUN=5
                DEFAULT_GZIP=-z
		MAXSPACE=1024000
```
        
   After installation, one can change the parameters by editing the 
   configuration file. The configuration file is named `.watchperf_settings` and
   is located in the install directory. The name of the configuration file
   cannot be changed !


4) If running via crontab:

   - add the wrapper-controlwatchperf.sh to crontab to run continuously 
     For instance, set it run every 5 minutes again if run time above
     was choosen to be 5 minutes - thus covering the whole time.
     
     Example: 
```
          0,5,10,15,20,25,30,35,40,45,50,55 * * * * /bin/sh -c /var/tmp/watchperf/wrapper-controlwatchperf.sh &
```        
   - to stop collection, simple disable it in crontab

     When used for troubleshooting the time to start should be
	not aligned with the start time of the program to monitor the system for.
	Because of start time, some glitches might be missing from the start
	of the program in question. Please keep in mind that there are 5 seconds
	pause after 55 seconds of data collection to calm down the load posed by the
	data collection itself. During these 5 seconds, nothing is collected, so
	valueable information might be lost.

5) If not running from crontab:

   - one should use nohup to avoid stopping collection once a logout and HUP occures:

     Example: 
```
     nohup /bin/sh /var/tmp/watchperf/wrapper-controlwatchperf.sh &
```
   - to stop collection before time to run is over: simply look for the proc ID
          of the `wrapper-controlwatchperf.sh` process and send it a kill (if started via nohup)
          or simply kill the process from shell by hitting `^C` (or it's replacement, depending
          on your terminal settings)


CONFIGURATION FILE:

/var/tmp/watchperf/.watchperf_settings (Linux example):
```
		CMD_ECHO=/bin/echo  
		CMD_BASENAME=/usr/bin/basename
		CMD_DATE=/bin/date
		CMD_EXPR=/usr/bin/expr
		CMD_ID=/usr/bin/id
		CMD_MKDIR=/bin/mkdir
		CMD_UNAME=/bin/uname
		CMD_SHOWREV=
		CMD_AWK=/usr/bin/awk
		CMD_VMSTAT=/usr/bin/vmstat
		CMD_IOSTAT=/usr/bin/iostat
		CMD_PS=/bin/ps
		CMD_MPSTAT=/usr/bin/mpstat
		CMD_IPCS=/usr/bin/ipcs
		CMD_NETSTAT=/bin/netstat
		CMD_LOCKSTAT=
		CMD_GZIP=/bin/gzip
		CMD_SLEEP=/bin/sleep
		CMD_DIR=/var/tmp/watchperf	# -i option
		OUTPUT_DIR=/tmp/watchperf	# -o option
		TIME_TO_RUN=5			<=== Look here, there should be 5 for 5 minutes to run
		GZIP=-z				<=== Should gzip files !!  # -n option (default=-z)
		NO_DTRACE=0		# -D option (default=0, -D => 1)
		IOSTATONLY=0		# -I option (default=0, -I => 1)
		MAXSPACE=1024000	# -s option (default=1024000 = 1 GB)
```


Known Issues:

- On Oracle/Sun Servers using the T2 or T3 processors (like T5220, for instance), one might encounter drops of probe data due to high load placed by dtrace on a single core. You might consider to disable dtrace if no granular IO data is needed - like offsets of IOs and IO size distribution; use `-D` option. Although UltraSPARC IIi processors are *somewhat* older, on a U10 and a U80 with 4 processors this wasn't observed. On U10 with only 384 MB memory the buffer size for dtrace was reduced only.
