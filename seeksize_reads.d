#!/usr/sbin/dtrace -s
/*
 * seeksize.d - analyse disk head seek distance by process.
 *              Written using DTrace (Solaris 10 3/05).
 *
 * Disk I/O events caused by processes will in turn cause the disk heads
 * to seek. This program analyses those seeks, so that we can determine
 * if processes are causing the disks to seek in a "random" or "sequential"
 * manner.
 *
 * 15-Jun-2005, ver 1.00
 *
 * USAGE:       seeksize.d              # wait several seconds, then hit Ctrl-C
 *
 * FIELDS:
 *              PID     process ID
 *              CMD     command and argument list
 *              value   distance in disk blocks (sectors)
 *              count   number of I/O operations
 *
 * SEE ALSO: bitesize.d, iosnoop
 *
 * Standard Disclaimer: This is freeware, use at your own risk.
 *
 * 11-Sep-2004  Brendan Gregg   Created this.
 * 10-Oct-2004     "      "     Rewrote to use the io provider.
 */

#pragma D option quiet

/*
 * Print header
 */
dtrace:::BEGIN
{
}

self int last[dev_t];

/*
 * Process io start
 */
io:::start
{
        /* fetch details */
        this->dev = args[0]->b_edev;
        this->blk = args[0]->b_blkno;
        this->size = args[0]->b_bcount;
        cmd = (string)curpsinfo->pr_psargs;
}
io:::start
/self->last[this->dev] != 0 && args[0]->b_flags & B_READ/
{       
        /* calculate seek distance */
        this->dist = this->blk - self->last[this->dev] > 0 ?
            this->blk - self->last[this->dev] :
            self->last[this->dev] - this->blk;
        
        /* store details */ 
        /* @Size[pid,cmd] = quantize(this->dist); */
        @[args[1]->dev_statname, args[1]->dev_pathname] = quantize(this->dist);
}
io:::start
{       
        /* save last position of disk head */
        self->last[this->dev] = this->blk + this->size / 512;
}

/* 
 * Print final report
 */
dtrace:::END
{       
        /* printf("\n%8s  %s\n","PID","CMD");
        printa("%8d  %s\n%@d\n",@Size);
        */
        printa("  %s (%s)\n%@d\n", @);
}



/*      
        @[args[1]->dev_statname, args[1]->dev_pathname] =
            quantize((args[0]->b_bcount * 976562) / this->elapsed);
        start[args[0]->b_edev, args[0]->b_blkno] = 0;
        
        printa("  %s (%s)\n%@d\n", @);
*/
