#!/usr/sbin/dtrace -Zs
/*
 * Script for tracing all PHP Static Probes with DTrace.
 * Usage: sudo ./dtruss-php.d
 * @author kenorb
 */

#pragma D option quiet

unsigned long long indent;

dtrace:::BEGIN {
    total = 0;
    ts_start = timestamp;
    printf("Tracing... (Hit Ctrl-C to end)\n");
}

/*
 * Fires when an opcode array is to be executed. For example, it fires on function calls, includes, and generator resumes.
 * char *request_file, int lineno
 */
php*:::execute-entry
{
    printf("%Y: PHP execute-entry:       %*s%s %s:%d\n", walltimestamp, indent, "", "->", basename(copyinstr(arg0)), (int)arg1);
}

/*
 * Fires after execution of an opcode array.
 * char *request_file, int lineno
 */
php*:::execute-return
{
    printf("%Y: PHP execute-return:      %*s%s %s:%d\n", walltimestamp, indent, "", "<-", basename(copyinstr(arg0)), (int)arg1);
}

/*
 * Fires when the PHP engine enters a PHP function or method call.
 * char *function_name, char *request_file, int lineno, char *classname, char *scope
 */
php*:::function-entry
{
    printf("%Y: PHP function-entry:      %*s%s %s%s%s() in %s:%d\n", walltimestamp, indent, "", "->", copyinstr(arg3), copyinstr(arg4), copyinstr(arg0), basename(copyinstr(arg1)), (int)arg2);
    self->vts = timestamp;
    self->cmd = arg3
}

/*
 * Fires when the PHP engine returns from a PHP function or method call.
 * char *function_name, char *request_file, int lineno, char *classname, char *scope
 */
php*:::function-return
/self->vts/
{
    /* Summarize the CPU time spent to execute read(), in nanoseconds, as a histogram. Linear quantize via quantize(). */
    @time[pid, self->cmd] = quantize(timestamp - self->vts);
    @num = count();
/*
    total += @time;
    @proctime[pid,uid,execname,curpsinfo->pr_psargs] = sum(this->time/1000);
*/
    /* tcpu = lquantize((vtimestamp - self->vts) / 1000, 0, 10000, 10); */
    /* printf("%Y: PHP function-return:     %*s%s %s%s%s() in %s:%d (%dusec)\n", walltimestamp, indent, "", "<-", copyinstr(arg3), copyinstr(arg4), copyinstr(arg0), basename(copyinstr(arg1)), (int)arg2, (timestamp-ts_start)/1000); */
    printf("%Y: PHP function-return:     %*s%s %s%s%s() in %s:%d\n", walltimestamp, indent, "", "<-", copyinstr(arg3), copyinstr(arg4), copyinstr(arg0), basename(copyinstr(arg1)), (int)arg2);
    self->vts = 0; /* Frees the "ts" thread-local variable. */
    self->cmd = 0;
}

/*
 * Fires when the compilation of a script starts.
 *  char *compile_file, char *compile_file_translated
 */
php*:::compile-file-entry
{
    printf("%Y: PHP compile-file-entry:  %*s%s %s (%s)\n", walltimestamp, indent++, "", "=>", basename(copyinstr(arg0)), basename(copyinstr(arg1)));
}

/*
 * Fires when the compilation of a script finishes.
 * char *compile_file, char *compile_file_translated
 */
php*:::compile-file-return
{
    printf("%Y: PHP compile-file-return: %*s%s %s (%s)\n", walltimestamp, --indent, "", "<=", basename(copyinstr(arg0)), basename(copyinstr(arg1)));
}

/*
 * Fires when a request starts.
 * char *file, char *request_uri, char *request_method
 */
php*:::request-startup
{
    indent--;
    printf("%Y, PHP request-startup:     %*s%s %s at %s via %s\n", walltimestamp, indent++, "", "=>", basename(copyinstr(arg0)), copyinstr(arg1), copyinstr(arg2));
}

/*
 * Fires when a request starts
 * char *file, char *request_uri, char *request_method
 */
php*:::request-shutdown
{
    printf("%Y: PHP request-shutdown:    %*s%s %s at %s via %s\n", walltimestamp, --indent, "", "<=", basename(copyinstr(arg0)), copyinstr(arg1), copyinstr(arg2));
}

/*
 * Fires when an exception is thrown.
 * char *classname
 */
php*:::exception-thrown
{
    printf("%Y: PHP exception-thrown:    %*s%s %s\n", walltimestamp, indent, "", "=>", copyinstr(arg0));
}

/*
 * Fires when an exception is caught.
 * char *classname
 */
php*:::exception-caught
{
    printf("%Y: PHP exception-caught:    %*s%s %s\n", walltimestamp, indent, "", "<=", copyinstr(arg0));
}

/*
 * Fires when an error occurs, regardless of the error_reporting level.
 * char *errormsg, char *request_file, int lineno
 */
php*:::error
{
    printf("%Y: PHP error message:\t%s in %s:%d\n", walltimestamp, copyinstr(arg0), basename(copyinstr(arg1)), (int)arg2);
}

/*
profile:::tick-2s
{
  printf("\nPHP commands/second total: ");
  printa("%@d; commands latency (ns) by pid & cmd:", @num);
  printa(@time);
  clear(@time);
  clear(@num);
}
*/

dtrace:::END {
    printf("Elapsed time %d usec\n", (timestamp - ts_start) / 1000);
    printf("Total Time on CPU: %d usec\n", total / 1000);
    /* printa(@proctime); */
    trunc(@time);
    trunc(@num);
}
