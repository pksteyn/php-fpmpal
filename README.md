# php-fpmpal
Bash script script that makes recommendations on max_children for each PHP-FPM pool on a server.

1) What the main script (php-fpmpal.sh) does is:
* identify all PHP-FPM pools on a server and the average memory usage
per process for each pool
* classify how much of the overall PHP-FPM memory each pool uses (e.g.
pool one uses about 60%, pool2 uses 25% and pool3 uses 15%)
* works out how much memory is available on the server for PHP-FPM to
use as a whole
* works out how much of that available memory should be allocated to
each pool
* works out the max_children setting for each pool based on it's
"allocated" memory and the average process size for the pool

2) Cron job (cron.sh):
* will catch various PHP-FPM pool stats and keep a set number of copies
* saves stats to "/var/log/php-fpmpal/" by default
* to setup cronjob create the file "/etc/cron.d/php-fpmpal-stats-capture" with content:

SHELL=/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

*/10 * * * * root /bin/bash /path/to/cron.sh




3) Cron job interpreter (interpretcron.sh):
* can be used to print out various types of reports using stats captured in PHP-FPM cronjob
* run "./interpretcron.sh --help" to get help on usage:

Usage: interpretcron.sh [OPTION]

Arguments:

  -ms                   For each logfile in /var/log/php-fpmpal show the total memory usage per PHP-FPM pool
  
  -msl [FILENAME]       Show the total memory usage per PHP-FPM pool for this logfile

