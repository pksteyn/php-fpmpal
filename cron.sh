#!/bin/bash

# Logrotate
copies_to_keep=144

# Log location and filename
logdirectory="/var/log/php-fpmpal/"
mkdir -p $logdirectory

# Log file name
logfile_name=$logdirectory`date "+%Y.%m.%d_%H:%M:%S"`

# Create new log file
touch $logfile_name

# Put timestamp at top of logfile
echo `date "+%Y.%m.%d_%H:%M:%S"` >> $logfile_name

# Create a list of PHP-FPM pools
IFS=$'\n' list_of_pools=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | awk -F "pool " '{print $2}' | sort | uniq | sed -e 's/ //g'))

# Get total server memory
total_server_memory=`cat /proc/meminfo  | grep MemTotal | awk '{print $2}'`

# Initialise total PHP-FPM memory usage
total_phpfpm_mem_usage=0

# Get the number of pools
let no_of_pools=(${#list_of_pools[@]}-1)

# Set the php-fpm process name
php-fpm -v 2&>1 /dev/null
if [ $? == 0 ]; then
   pool_directory="/etc/php-fpm.d/*.conf"
   fpm_type="php-fpm"
fi

php5-fpm -v 2&>1 /dev/null
if [ $? == 0 ]; then
   pool_directory="/etc/php5/fpm/pool.d/*.conf"
   fpm_type="php5-fpm"
fi

# For each pool
for ((i=0; i<=no_of_pools; i++))
do
   # Get list of PIDs
   if [ $fpm_type == "php-fpm" ]; then
      IFS=$'\n' list_of_pids=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | grep "pool ${list_of_pools[$i]}$" | awk '{print $2}'))
   elif [ $fpm_type == "php5-fpm" ]; then ### Ubuntu/PHP5-FPM nuance in ps output
      IFS=$'\n' list_of_pids=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | grep "pool ${list_of_pools[$i]} " | awk '{print $2}'))
   fi

   total_pool_mem_usage[$i]=0

   # For every PID
   for ((a=0; a<=no_of_pids; a++))
   do
      # Get PID memory usage and add it to pool's total memory usage
      let total_pool_mem_usage[$i]+=`/usr/bin/pmap -d ${list_of_pids[$a]} | grep "writeable/private" | awk '{ print $4 }' | sed -e s/K//`
   done
   # Add total pool memory usage to total PHP-FPM memory usage
   let total_phpfpm_mem_usage+=${total_pool_mem_usage[$i]}
   # Calculate average process size for this pool
   pool_ave_process_size[$i]=`echo "${total_pool_mem_usage[$i]} / ${#list_of_pids[@]}" | bc`
done

# Get the number of PIDs
no_of_pids=(${#list_of_pids[@]}-1)


### Write pool, PID and PID memory usage to logfile
# For every pool
for ((p=0; p<=no_of_pools; p++))
do
   # Get the list of PIDs
   if [ $fpm_type == "php-fpm" ]; then
      IFS=$'\n' list_of_pids=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | grep "pool ${list_of_pools[$p]}$" | awk '{print $2}'))
   elif [ $fpm_type == "php5-fpm" ]; then ### Ubuntu/PHP5-FPM nuance in ps output
      IFS=$'\n' list_of_pids=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | grep "pool ${list_of_pools[$p]} " | awk '{print $2}'))
   fi
   # Set the number of PIDs
   no_of_pids=(${#list_of_pids[@]}-1)
   # For every PID
   for ((i=0; i<=no_of_pids; i++ ))
   do
      # Get PID memory usage and write to logfile
      echo ": ${list_of_pools[$p]} ${list_of_pids[$i]} `/usr/bin/pmap -d ${list_of_pids[$i]} | grep "writeable/private" | awk '{ print $4 }' | sed -e s/K//`" >> $logfile_name
      #grep "\[${list_of_pools[$p]}\]" ${list_of_includes[$i]} > /dev/null
      #if [ $? == 0 ]; then
      #   pool_config_file[$p]="${list_of_includes[$i]}"
      #fi
   done
done


### Write memory usage for different processes to logfile
echo "Total server memory in KB: $total_server_memory" >> $logfile_name

# Apache
apache_process_name=`apachectl -V 2>&1 | grep PID | awk -F"run/" '{print $2}' | cut -d. -f1`
ps aux | grep -v ^root | egrep $apache_process_name > /dev/null
   if [ $? == 0 ]; then
      IFS=$'\n' list_of_apache_pids=($(ps aux | grep $apache_process_name | grep -v ^root | grep -v grep | awk '{print $2}'))
      total_apache_pool_mem_usage=0
      for a in "${list_of_apache_pids[@]}"
      do
         let total_apache_pool_mem_usage+=`/usr/bin/pmap -d $a | grep "writeable/private" | awk '{ print $4 }' | sed -e s/K//`
      done
   else
      total_apache_pool_mem_usage=0
   fi
echo "Total Apache memory usage in KB: $total_apache_pool_mem_usage" >> $logfile_name

# Varnish
ps aux | grep -v ^root | grep varnish > /dev/null
   if [ $? == 0 ]; then
      varnish_perc=`ps aux | grep -v ^root | grep varnish | awk '{print $4}'`
      total_varnish_mem_usage=`echo "$total_server_memory / 100 * $varnish_perc" | bc`
   else
      total_varnish_mem_usage=0
   fi
echo "Total Varnish memory usage in KB: $total_varnish_mem_usage" >> $logfile_name

# MySQL
ps aux | grep -v ^root | grep mysql > /dev/null
   if [ $? == 0 ]; then
      mysql_perc=`ps aux | grep -v ^root | grep mysql | awk '{print $4}'`
      total_mysql_pool_mem_usage=`echo "$total_server_memory / 100 * $mysql_perc" | bc`
   else
      total_mysql_pool_mem_usage=0
   fi
echo "Total MySQL memory usage in KB: $total_mysql_pool_mem_usage" >> $logfile_name

# PHP-FPM
echo "Current total PHP-FPM memory usage in KB: $total_phpfpm_mem_usage" >> $logfile_name

# Memory available to PHP-FPM
total_phpfpm_allowed_memory=`echo "$total_server_memory - ($total_apache_pool_mem_usage + $total_mysql_pool_mem_usage + $total_varnish_mem_usage)" | bc`
echo "Memory available to assign to PHP-FPM pools in KB: $total_phpfpm_allowed_memory" >> $logfile_name


###
echo "Pool                 Memory_usage    %           Allowed_mem_usage    Ave_process_size Recommended_max_children Current_max_children" >> $logfile_name

for ((i=0; i<=no_of_pools; i++))
do
   pool_perc_mem_use[$i]=`echo "scale=2; ${total_pool_mem_usage[$i]}*100/$total_phpfpm_mem_usage" | bc`
   pool_allowed_mem_use[$i]=`echo "$total_phpfpm_allowed_memory * ${pool_perc_mem_use[$i]} / 100" | bc`
   pool_allowed_max_children[$i]=`echo "${pool_allowed_mem_use[$i]} / ${pool_ave_process_size[$i]}" | bc`
   config_file_location=`grep "\[${list_of_pools[$i]}\]" $pool_directory | cut -d: -f1`
   #current_max_children_value=`grep "^pm.max_children" $config_file_location | cut -d= -f2 | sed -e 's/ //g'`
   echo "${list_of_pools[$i]} ${total_pool_mem_usage[$i]} ${pool_perc_mem_use[$i]} ${pool_allowed_mem_use[$i]} ${pool_ave_process_size[$i]} ${pool_allowed_max_children[$i]} $current_max_children_value" >> $logfile_name
done


### Rotate out old logfiles
for i in `diff <(ls -tr /var/log/php-fpmpal/ | tail -$copies_to_keep) <(ls -tr /var/log/php-fpmpal/) | awk '/^>.*/ {print $2}'`
do
   rm -f $logdirectory$i
done
