#!/bin/bash

cron_log_location="/var/log/php-fpmpal"

function pool_summary_memory()
{
echo -e "\e[32m\e[1m==================================="
echo -e "TOTAL MEMORY USAGE PER PHP-FPM POOL"
echo -e "===================================\e[0m"
echo

for i in `ls -tr /var/log/php-fpmpal/`
do
	echo -ne "\e[32m\e[1m===== "
	echo -ne $(head -1 /var/log/php-fpmpal/$i)
	echo -e " ====="
	echo -e "\e[36mPool		\e[38;5;208mTotal size (MB)	\e[33mNr. of processes\e[0m"
	#awk '/^:.*/ {sum4[$2] += $4} {count[$2]++}; END {for (id in sum4) {print "\033[36m-- " id " --	\033[38;5;208m", sum4[id]/1024 "		\033[33m" count[id] } }' < /var/log/php-fpmpal/$i
	#awk '/^:.*/ {sum += $4}; END {print "\033[31m\033[1mTOTAL: " sum/1024 " MB" }' < /var/log/php-fpmpal/$i
	awk '/^:.*/ {sum4[$2] += $4} {count[$2]++}; END {for (id in sum4) {print "\033[36m-- " id " --	\033[38;5;208m", sum4[id]/1024 "		\033[33m" count[id] } }' < $cron_log_location/$i
	awk '/^:.*/ {sum += $4}; END {print "\033[31m\033[1mTOTAL: " sum/1024 " MB" }' < $cron_log_location/$i
        echo
done
}


function pool_summary_memory_single_file()
{
        echo -ne "\e[32m\e[1m===== "
        echo -ne $(head -1 $1)
        echo -e " ====="
        echo -e "\e[36mPool             \e[38;5;208mTotal size (MB)     \e[33mNr. of processes\e[0m"
        awk '/^:.*/ {sum4[$2] += $4} {count[$2]++}; END {for (id in sum4) {print "\033[36m-- " id " --	\033[38;5;208m", sum4[id]/1024 "                \033[33m" count[id] } }' < $1
        awk '/^:.*/ {sum += $4}; END {print "\033[31m\033[1mTOTAL: " sum/1024 " MB" }' < $1
        echo
}

function usage()
{
	echo
	echo "Usage: interpretcron.sh [OPTION]"
	echo
	echo "Arguments:"
	echo "  -ms			For each logfile in $cron_log_location show the total memory usage per PHP-FPM pool"
	echo "  -msl [FILENAME]	Show the total memory usage per PHP-FPM pool for this logfile"
	echo
}

if [ $# -eq 0 ]; then
   echo
   echo "No arguments provided"
   usage
   exit 1
fi

if [ $1 == "--help" ]; then
   usage
elif [ $1 == "-ms" ]; then
   pool_summary_memory
elif [ $1 == "-msl" ]; then
   pool_summary_memory_single_file $2
fi
#echo $1

echo -e "\e[0m"

#for i in `ls -tr /var/log/php-fpmpal/`; do echo -n "===== "; echo -n $(head -1 /var/log/php-fpmpal/$i); echo " ====="; awk '/^:.*/ {sum4[$2] += $4}; END{for (id in sum4) {print id, sum4[id] } }' < /var/log/php-fpmpal/$i; done
