#!/bin/sh
#ident: start_dtrace.sh, ver 1.2. (C)2011,2013,Matthias.Muench@alice-dsl.de
#
# CHANGES:
#
#	ver 1.1:
#		- changed pid recognition and kill behaviour
#		- added transport of pid information outside  (but disabled)
#	ver 1.2:
#		- fixed missing output
#		- fixed wrong signal handling

if [ $# -ne 3 ]; then
        echo "usage: $0 dtrace_file time_in_sec outputfile"
        exit 1
fi
if [ "XX$1" = "XX" ]; then
        echo "$0 - error: dtrace file to execute required"
        exit 1
else
        if [ ! -r  $1 ]; then
                echo "$0 - error: dtrace file $1 doesn't exist or isn't readable"
        fi
fi

trap 'kill $KCHILD 2>/dev/null; exit 0' 1 2 5 10 15
/usr/sbin/dtrace -s $1 >>$3 &
KCHILD=$!
sleep $2 
kill $KCHILD 2>/dev/null

trap 1 2 5 10 15

#Done.

