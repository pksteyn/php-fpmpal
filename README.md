# php-fpmpal
Bash script script that makes recommendations on max_children for each PHP-FPM pool on a server.

What the script does is:

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
