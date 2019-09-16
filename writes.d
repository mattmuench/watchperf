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
 * iothrough.d in /usr/demo/dtrace, a directory that contains all D scripts
 * used in the Solaris Dynamic Tracing Guide.  A table of the scripts and their
 * corresponding chapters may be found here:
 *
 *   file:///usr/demo/dtrace/index.html
 */

#pragma D option quiet

io:genunix::start
{
        start[args[0]->b_edev, args[0]->b_blkno] = timestamp;
}

io:genunix::done
/start[args[0]->b_edev, args[0]->b_blkno] && args[0]->b_flags & B_WRITE/
{
        /*
         * We want to get an idea of our throughput to this device in KB/sec.
         * What we have, however, is nanoseconds and bytes.  That is we want
         * to calculate:
         *
         *                        bytes / 1024
         *                  ------------------------
         *                  nanoseconds / 1000000000
         *
         * But we can't calculate this using integer arithmetic without losing
         * precision (the denomenator, for one, is between 0 and 1 for nearly
         * all I/Os).  So we restate the fraction, and cancel:
         *
         *     bytes      1000000000         bytes        976562
         *   --------- * -------------  =  --------- * -------------
         *      1024      nanoseconds          1        nanoseconds
         * 
         * This is easy to calculate using integer arithmetic; this is what
         * we do below.
         */
        this->elapsed = timestamp - start[args[0]->b_edev, args[0]->b_blkno];
        @[args[1]->dev_statname, args[1]->dev_pathname] =
            quantize((args[0]->b_bcount * 976562) / this->elapsed);
        start[args[0]->b_edev, args[0]->b_blkno] = 0;
}

END
{       
        printa("  %s (%s)\n%@d\n", @);
}

