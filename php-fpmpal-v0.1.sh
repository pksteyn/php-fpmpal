#! /bin/bash

echo
echo -e "\e[33m (        )  (         (     (       *                      "
echo -e "\e[33m\e[1m )\ )  ( /(  )\ )      )\ )  )\ )  (  \`                 (   "
echo -e "\e[38;5;208m(()/(  )\())(()/(     (()/( (()/(  )\))(             )  )\  "
echo -e "\e[38;5;208m /(_))((_)\  /(_))     /(_)) /(_))((_)()\  \`  )   ( /( ((_) "
echo -e "\e[91m(_))   _((_)(_))      (_))_|(_))  (_()((_) /(/(   )(_)) _   "
echo -e "\e[0m\e[38;5;21m| _ \ | || || _ \ ___ | |_  | _ \ |  \/  |\e[91m\e[1m((_)_\ ((_)\e[0m\e[38;5;21m_ | |  "
echo -ne "|  _/ | __ ||  _/|___|| __| |  _/ | |\/| || '_ \\"
echo -e "\e[91m\e[1m)\e[0m\e[38;5;21m/ _\` || |  "
echo -e "|_|   |_||_||_|       |_|   |_|   |_|  |_|| .__/ \__,_||_|  "
#echo -e "========================================= |_| ============\e[0m"
for i in {17..21} {21..17} {17..21} {21..17} {17..21} {21..17} {17..21} {21..17} {17..17} ; do echo -en "\e[38;5;${i}m=\e[0m" ; done
echo -en "\e[38;5;21m |_| "
for i in {17..21} {21..21} {21..21} {21..21} {20..16} ; do echo -en "\e[38;5;${i}m=\e[0m" ; done
echo -e "\e[0m"
echo

### Get list of all PHP-FPM pools from proces list
IFS=$'\n' list_of_pools=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | awk -F "pool " '{print $2}' | sort | uniq | sed -e 's/ //g'))

### Get total server memory
total_server_memory=`cat /proc/meminfo  | grep MemTotal | awk '{print $2}'`

### Initialise variable to tally up total current PHP-FPM memory usage
total_phpfpm_mem_usage=0

### Initialise variable to tally up total potential PHP-FPM memory usage based on largest processes in pool
total_phpfpm_mem_usage_largest_process=0

### Initialise variable to tally up total potential PHP-FPM memory usage based on average process size in pool
total_phpfpm_mem_usage_average_process=0

### Set variable to the total number of PHP-FPM pools
let no_of_pools=(${#list_of_pools[@]}-1)

### Determine whether the PHP-FPM process is called php-fpm or php5-fpm, and set the pool directory accordingly
php-fpm -v 1> /dev/null 2>&1
if [ $? == 0 ]; then
   pool_directory="/etc/php-fpm.d/*.conf"
   fpm_type="php-fpm"
fi

php5-fpm -v 1> /dev/null 2>&1
if [ $? == 0 ]; then
   pool_directory="/etc/php5/fpm/pool.d/*.conf"
   fpm_type="php5-fpm"
fi

### Give info re all list of PHP-FPM pools
### ======================================

echo -en "\e[38;5;22m=\e[38;5;28m=\e[38;5;34m=\e[38;5;40m=\e[38;5;46m="
echo -en "\e[32m\e[1m List of PHP-FPM pools \e[0m"
echo -e "\e[38;5;46m=\e[38;5;40m=\e[38;5;34m=\e[38;5;28m=\e[38;5;22m=\e[0m"

### For each pool
for ((i=0; i<=no_of_pools; i++))
do
   ### Print pool name and configuration file
   echo -en "\e[36m\e[1m--- "
   echo -en ${list_of_pools[$i]}
   echo -e " ---\e[0m"
   echo -n "Configuration file: "; echo `grep "\[${list_of_pools[$i]}\]" $pool_directory | cut -d: -f1`

   ### Create a list of process IDs that belong to this pool
   if [ $fpm_type == "php-fpm" ]; then ### For RHEL/CentOS release use this command
      IFS=$'\n' list_of_pids=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | grep "pool ${list_of_pools[$i]}$" | awk '{print $2}'))
   elif [ $fpm_type == "php5-fpm" ]; then ### Ubuntu/PHP5-FPM nuance in ps output
      IFS=$'\n' list_of_pids=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | grep "pool ${list_of_pools[$i]} " | awk '{print $2}'))
   fi

   ### List all process IDs that belong to this pool
   echo -n "List of processes: "
   echo ${list_of_pids[@]}

   ### List total number of processes that belong to this pool
   echo -n "Number of processes: "
   echo ${#list_of_pids[@]}

   ### Get the current max_children value
   echo -n "Current max_children value: "
   config_file_location=`grep "\[${list_of_pools[$i]}\]" $pool_directory | cut -d: -f1`
   current_max_children_value=`grep "^pm.max_children" $config_file_location | cut -d= -f2 | sed -e 's/ //g'`
   echo $current_max_children_value

   ### Calculate the total memory usage for this pool
   total_pool_mem_usage[$i]=0
   ### For each process
   for a in "${list_of_pids[@]}"
   do
      ### Gather memory usage (using pmap) and add it to total_pool_mem_usage variable
      let total_pool_mem_usage[$i]+=`pmap -d $a | grep "writeable/private" | awk '{ print $4 }' | sed -e s/K//`
   done
   ### Print total memory usage for this pool
   echo -n "Total memory usage for pool in KB: "
   echo ${total_pool_mem_usage[$i]}
   ### Increase the total PHP-FPM memory usage with the total memory usage for this pool
   let total_phpfpm_mem_usage+=${total_pool_mem_usage[$i]}

   ### Calculate the average process memory usage for this pool
   echo -n "Average memory usage per process in KB: "
   pool_ave_process_size[$i]=`echo "${total_pool_mem_usage[$i]} / ${#list_of_pids[@]}" | bc`
   echo ${pool_ave_process_size[$i]}

   ### Get the largest pool process size
   echo -n "Largest process in this pool is (KB): "
   for a in "${list_of_pids[@]}"
   do 
      pool_processes_mem_size[$a]=`pmap -d $a | grep "writeable/private" | awk '{ print $4 }' | sed -e s/K// | sort -nr | head -1 | sort -nr | head -1`
   done
   let largest_pool_process_size=`echo "${pool_processes_mem_size[*]}" | sort -nr | head -1`
   echo $largest_pool_process_size

   ### Total memory usage: max_children * largest process size
   echo -n "Total potential memory usage for pool (based on largest process) (KB): "
   potential_mem_usage=`echo "$current_max_children_value * $largest_pool_process_size" | bc`
   let total_phpfpm_mem_usage_largest_process+=$potential_mem_usage
   echo $potential_mem_usage

   ### Total memory usage: max_children * average process size
   echo -n "Total potential memory usage for pool (based on average process) (KB): "
   potential_mem_usage=`echo "$current_max_children_value * ${pool_ave_process_size[$i]}" | bc`
   let total_phpfpm_mem_usage_average_process+=$potential_mem_usage
   echo $potential_mem_usage

   echo
done

### Print out total potential PHP-FPM usage based on largest process size per pool
#   echo -n "Total potential PHP-FPM memory usage based on largest processes (KB): "
#   echo $total_phpfpm_mem_usage_largest_process
### Print out total potential PHP-FPM usage based on largest process size per pool
#   echo -n "Total potential PHP-FPM memory usage based on average process size (KB): "
#   echo $total_phpfpm_mem_usage_average_process
#   echo


### END OF Give info re all list of PHP-FPM pools
### =============================================

### Print out statistics re server memory usage
### ===========================================

echo -en "\e[38;5;22m=\e[38;5;28m=\e[38;5;34m=\e[38;5;40m=\e[38;5;46m="
echo -en "\e[32m\e[1m Server memory usage statistics \e[0m"
echo -e "\e[38;5;46m=\e[38;5;40m=\e[38;5;34m=\e[38;5;28m=\e[38;5;22m=\e[0m"

### Total server memory
echo -ne "Total server memory in KB: "
echo -e "$total_server_memory"

### Calculate total Apache memory usage
echo -n "  =Total Apache memory usage in KB: "
### Gather the process name for Apache (httpd for RHEL/CentOS; apache2 for Ubuntu 
apache_process_name=`apachectl -V 2>&1 | grep PID | awk -F"run/" '{print $2}' | cut -d. -f1`
### If Apache is running
ps aux | grep -v ^root | egrep $apache_process_name > /dev/null
   if [ $? == 0 ]; then
      ### Get a list of all Apache process IDs
      IFS=$'\n' list_of_apache_pids=($(ps aux | grep $apache_process_name | grep -v ^root | grep -v grep | awk '{print $2}'))
      total_apache_pool_mem_usage=0
      ### Add the memory usage for that process to the total Apache memory usage
      for a in "${list_of_apache_pids[@]}"
      do
         let total_apache_pool_mem_usage+=`pmap -d $a | grep "writeable/private" | awk '{ print $4 }' | sed -e s/K//`
      done
   ### Else if Apache is not running set total Apache memory usage to 0
   else
      total_apache_pool_mem_usage=0
   fi
echo $total_apache_pool_mem_usage

### Calculate total Varnish memory usage
echo -n "  =Total Varnish memory usage in KB: "
### If Varnish is running
ps aux | grep -v ^root | grep varnish > /dev/null
   if [ $? == 0 ]; then
      ### Get Varnish's % memory usage from ps (I've found this more reliable than using pmap
      varnish_perc=`ps aux | grep -v ^root | grep varnish | awk '{print $4}'`
      ### Calculate total Varnish memory usage
      total_varnish_mem_usage=`echo "$total_server_memory / 100 * $varnish_perc" | bc`
   ### Else if Varnish is not running set total Varnish memory usage to 0
   else
      total_varnish_mem_usage=0
   fi
echo $total_varnish_mem_usage

### Calculate total MySQL memory usage
echo -n "  =Total MySQL memory usage in KB: "
### If MySQL is running
ps aux | grep -v ^root | grep mysql > /dev/null
   if [ $? == 0 ]; then
      ### Get MySQL's % memory usage from ps (I've found this more reliable than using pmap
      mysql_perc=`ps aux | grep -v ^root | grep mysql | awk '{print $4}'`
      ### Calculate total MySQL memory usage
      total_mysql_pool_mem_usage=`echo "$total_server_memory / 100 * $mysql_perc" | bc`
   ### Else if MySQL is not running set total MySQL memory usage to 0
   else
      total_mysql_pool_mem_usage=0
   fi
echo $total_mysql_pool_mem_usage

echo
### Calculate total memory that would be available for PHP-FPM to use by subtracting memory usage from all other processes from the server's total memory
echo -n "Memory available to assign to PHP-FPM pools in KB: "
   ### Total memory usage - (the sum of all other processes listed above)
   #total_phpfpm_allowed_memory=`echo "$total_server_memory - ($total_apache_pool_mem_usage + $total_mysql_pool_mem_usage + $total_varnish_mem_usage)" | bc`

   ### Take total free memory and add current PHP-FPM total memory usage
   total_phpfpm_allowed_memory=$(echo "`free -k | awk '/buffers\/cache/ {print $4}'` + $total_phpfpm_mem_usage" | bc)
echo $total_phpfpm_allowed_memory

### Print total current PHP-FPM memory usage
echo -n "(Current total PHP-FPM memory usage in KB: "
echo -n $total_phpfpm_mem_usage
echo ")"
echo

### Print out total potential PHP-FPM usage based on largest process size per pool
   echo -n "Total potential PHP-FPM memory usage based on largest processes (KB): "
   echo -n $total_phpfpm_mem_usage_largest_process
   echo -ne "\e[33m (`echo "scale=2; $total_phpfpm_mem_usage_largest_process*100/$total_phpfpm_allowed_memory" | bc `"
   echo -n "%)"
   # Print warning if this is larger than allowed PHP-FPM memory usage
   if [ $total_phpfpm_mem_usage_largest_process -gt $total_phpfpm_allowed_memory ]; then
      echo -e " \e[31m!!! THIS IS LARGER THAN THE ALLOWED MEMORY USAGE !!!\e[0m"
   else
      echo -e " \e[32m...GOOD :-)\e[0m"
   fi

### Print out total potential PHP-FPM usage based on largest process size per pool
   echo -n "Total potential PHP-FPM memory usage based on average process size (KB): "
   echo -n $total_phpfpm_mem_usage_average_process
   echo -ne "\e[33m (`echo "scale=2; $total_phpfpm_mem_usage_average_process*100/$total_phpfpm_allowed_memory" | bc `"
   echo -n "%)"
   # Print warning if this is larger than allowed PHP-FPM memory usage
   if [ $total_phpfpm_mem_usage_average_process -gt $total_phpfpm_allowed_memory ]; then
      echo -e " \e[31m!!! THIS IS LARGER THAN THE ALLOWED MEMORY USAGE !!!\e[0m"
   else
      echo -e " \e[32m...GOOD :-)\e[0m"   
   fi
   echo

### END OF Print out statistics re server memory usage
### ==================================================

### Calculate and display recommendations for every PHP-FPM pool
### ============================================================

echo -en "\e[38;5;22m=\e[38;5;28m=\e[38;5;34m=\e[38;5;40m=\e[38;5;46m="
echo -en "\e[32m\e[1m Recommendations per pool \e[0m"
echo -e "\e[38;5;46m=\e[38;5;40m=\e[38;5;34m=\e[38;5;28m=\e[38;5;22m=\e[0m"

### For every PHP-FPM pool
for ((i=0; i<=no_of_pools; i++))
do
   ### Calculate percentage of memory that pool is using against total PHP-FPM memory usage
   pool_perc_mem_use[$i]=`echo "scale=2; ${total_pool_mem_usage[$i]}*100/$total_phpfpm_mem_usage" | bc`
   ### Take that percentage and divide it by the total memory that should be available for PHP-FPM to use to get the total "allowed" memory usage for this pool
   pool_allowed_mem_use[$i]=`echo "$total_phpfpm_allowed_memory * ${pool_perc_mem_use[$i]} / 100" | bc`
   ### Divide the average process size for this pool by the total "allowed" memory usage for this pool to get a recommended max_children value
   pool_allowed_max_children[$i]=`echo "${pool_allowed_mem_use[$i]} / ${pool_ave_process_size[$i]}" | bc`
   ### Get the configuration file location for this PHP-FPM pool
   config_file_location=`grep "\[${list_of_pools[$i]}\]" $pool_directory | cut -d: -f1`
   ### Get the current max_children value for this PHP-FPM pool
   current_max_children_value=`grep "^pm.max_children" $config_file_location | cut -d= -f2 | sed -e 's/ //g'`
   ### Print out all this information
   echo -e "\e[36m\e[1m-- ${list_of_pools[$i]} --\e[0m currently uses ${total_pool_mem_usage[$i]} KB memory (\e[33m${pool_perc_mem_use[$i]}%\e[0m of all PHP-FPM memory usage). It should be allowed to use about ${pool_allowed_mem_use[$i]} KB of all available memory. Its average process size is ${pool_ave_process_size[$i]} KB so this means \e[38;5;208mmax_children should be set to ~\e[1m${pool_allowed_max_children[$i]}\e[0m. It is currently set to $current_max_children_value (this can be changed in $config_file_location)."
done

echo
### END OF Calculate and display recommendations for every PHP-FPM pool
### ===================================================================

for i in {17..21} {21..17} {17..21} {21..17} {17..21} {21..17} {17..21} {21..17} {17..21} {21..17} {17..21} {21..17} ; do echo -en "\e[38;5;${i}m=\e[0m" ; done
echo -e "\e[0m"
echo
