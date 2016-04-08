#!/usr/sbin/dtrace -qws
# Usage: dtrace -s watch.d -p `pgrep -x mysqld`

/*
 * DTrace script to trace MySQL.
 * See: https://dev.mysql.com/tech-resources/articles/getting_started_dtrace_saha.html
 */

#pragma D option strsize=1024

dtrace:::BEGIN
{
  printf("Logging to file..Hit Ctrl-C to end.\n");
  /* freopen("/tmp/mysql.log"); */

}

/* This probe is fired when the execution enters mysql_parse */
pid$target::*mysql_parse*:entry 
{
  printf("Query: %s\n", copyinstr(arg1));
   self->start = vtimestamp;

}

pid$target:::entry
/self->start/
{
   trace(timestamp);

}

pid$target:::return
/self->start/
{
   trace(timestamp);
}
pid$target::*mysql_parse*:return
/self->start/
{

   self->start = 0;

}

mysql*:::query-start /* using the mysql provider */
{

  self->query = copyinstr(arg0); /* Get the query */
  self->connid = arg1; /*  Get the connection ID */
  self->db = copyinstr(arg2); /* Get the DB name */
  self->who   = strjoin(copyinstr(arg3),strjoin("@",copyinstr(arg4))); /* Get the username */

  printf("%Y\t %20s\t  Connection ID: %d \t Database: %s \t Query: %s\n", walltimestamp, self->who ,self->connid, self->db, self->query);

}

mysql*:::connection-start
{

 self->bytes_read = 0;
 self->bytes_write = 0;
 self->conn_id = arg0;
 self->who = strjoin(copyinstr(arg1),strjoin("@",copyinstr(arg2))); /* Get the username */
 printf("Got a client connection at %Y from %20s with ID %u\n", walltimestamp, self->who, self->conn_id);
 self->client_connect_start = timestamp;


}

mysql*:::net-read-done/* using the mysql provider */
{

 self->bytes_read = self->bytes_read + arg1;

}

mysql*:::net-write-start/* using the mysql provider */
{

 self->start_w = timestamp;
 self->bytes_write= self->bytes_write + arg1;

}


mysql*:::connection-done
{

  printf ("Connection with ID: %u closed.\nTotal Bytes transferred: %u \nTotal connection time (ms): %-9d\n\n",self>conn_id, self->bytes_read + self->bytes_write,(timestamp-self->client_connect_start)/1000000 );

}

pid$target:::entry
/self->start/
{
   trace(timestamp);

}

pid$target:::return
/self->start/
{
   trace(timestamp);
}
