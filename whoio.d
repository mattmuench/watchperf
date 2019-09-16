/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 *
 * This D script is used as an example in the Solaris Dynamic Tracing Guide
 * in Chapter 27, "io Provider".
 *
 * The full text of Chapter 27 may be found here:
 *
 *   http://docs.sun.com/db/doc/817-6223?a=view
 *
 * On machines that have DTrace installed, this script is available as
 * whoio.d in /usr/demo/dtrace, a directory that contains all D scripts
 * used in the Solaris Dynamic Tracing Guide.  A table of the scripts and their
 * corresponding chapters may be found here:
 *
 *   file:///usr/demo/dtrace/index.html
 */

#pragma D option quiet

io:::start
{
        @[args[1]->dev_statname, execname, pid] = sum(args[0]->b_bcount);
}

END
{
        printf("%10s %20s %10s %15s\n", "DEVICE", "APP", "PID", "BYTES");
        printa("%10s %20s %10d %15@d\n", @);
}

