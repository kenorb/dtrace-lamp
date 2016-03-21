#!/usr/sbin/dtrace -Zs
/*
 * Script for tracing all PHP Static Probes with DTrace.
 * Usage: sudo dtruss-php.d
 * @author kenorb
 */

#pragma D option quiet

unsigned long long indent;

dtrace:::BEGIN {
    total = 0;
    ts_start = timestamp;
    printf("Starting...\n");
}

php*:::execute-entry
{
    printf("%Y: PHP execute-entry:       %*s%s %s:%d\n", walltimestamp, indent, "", "->", basename(copyinstr(arg0)), (int)arg1);
}

php*:::execute-return
{
    printf("%Y: PHP execute-return:      %*s%s %s:%d\n", walltimestamp, indent, "", "<-", basename(copyinstr(arg0)), (int)arg1);
}

php*:::function-entry
{
    printf("%Y: PHP function-entry:      %*s%s %s%s%s() in %s:%d\n", walltimestamp, indent, "", "->", copyinstr(arg3), copyinstr(arg4), copyinstr(arg0), basename(copyinstr(arg1)), (int)arg2);
    self->vts = vtimestamp;
}

php*:::function-return
/self->vts/
{
    /* Summarize the CPU time spent to execute read(), in nanoseconds, as a histogram. Linear quantize via lquantize(). */
    this->time = vtimestamp - self->vts;
/*
    total += this->time;
    @proctime[pid,uid,execname,curpsinfo->pr_psargs] = sum(this->time/1000);
*/
    self->vts = 0; /* Frees the "ts" thread-local variable. */
    /* tcpu = lquantize((vtimestamp - self->vts) / 1000, 0, 10000, 10); */
    /* printf("%Y: PHP function-return:     %*s%s %s%s%s() in %s:%d (%dusec)\n", walltimestamp, indent, "", "<-", copyinstr(arg3), copyinstr(arg4), copyinstr(arg0), basename(copyinstr(arg1)), (int)arg2, (timestamp-ts_start)/1000); */
    printf("%Y: PHP function-return:     %*s%s %s%s%s() in %s:%d\n", walltimestamp, indent, "", "<-", copyinstr(arg3), copyinstr(arg4), copyinstr(arg0), basename(copyinstr(arg1)), (int)arg2);
}

php*:::compile-file-entry
{
    printf("%Y: PHP compile-file-entry:  %*s%s %s (%s)\n", walltimestamp, indent++, "", "=>", basename(copyinstr(arg0)), basename(copyinstr(arg1)));
}

php*:::compile-file-return
{
    printf("%Y: PHP compile-file-return: %*s%s %s (%s)\n", walltimestamp, --indent, "", "<=", basename(copyinstr(arg0)), basename(copyinstr(arg1)));
}

php*:::request-startup
{
    indent--;
    printf("%Y, PHP request-startup:     %*s%s %s at %s via %s\n", walltimestamp, indent++, "", "=>", basename(copyinstr(arg0)), copyinstr(arg1), copyinstr(arg2));
}

php*:::request-shutdown
{
    printf("%Y: PHP request-shutdown:    %*s%s %s at %s via %s\n", walltimestamp, --indent, "", "<=", basename(copyinstr(arg0)), copyinstr(arg1), copyinstr(arg2));
}

php*:::exception-thrown
{
    printf("%Y: PHP exception-thrown:    %*s%s %s\n", walltimestamp, indent, "", "=>", copyinstr(arg0));
}

php*:::exception-caught
{
    printf("%Y: PHP exception-caught:    %*s%s %s\n", walltimestamp, indent, "", "<=", copyinstr(arg0));
}

php*:::error
{
    printf("%Y: PHP error message:\t%s in %s:%d\n", walltimestamp, copyinstr(arg0), basename(copyinstr(arg1)), (int)arg2);
}

dtrace:::END {
    printf("Elapsed time %d usec\n", (timestamp - ts_start) / 1000);
    printf("Total Time on CPU: %d usec\n", total / 1000);
    /* printa(@proctime); */
}
