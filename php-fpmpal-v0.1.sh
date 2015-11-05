#! /bin/bash

echo -e "\e[33m (        )  (         (     (       *                      "
echo -e "\e[91m )\ )  ( /(  )\ )      )\ )  )\ )  (  \`                 (   "
echo -e "\e[33m\e[1m(()/(  )\())(()/(     (()/( (()/(  )\))(             )  )\  "
echo -e "\e[91m /(_))((_)\  /(_))     /(_)) /(_))((_)()\  \`  )   ( /( ((_) "
echo -e "\e[33m(_))   _((_)(_))      (_))_|(_))  (_()((_) /(/(   )(_)) _   "
echo -e "\e[0m\e[96m| _ \ | || || _ \ ___ | |_  | _ \ |  \/  |\e[91m\e[1m((_)_\ ((_)\e[0m\e[96m_ | |  "
echo -e "|  _/ | __ ||  _/|___|| __| |  _/ | |\/| || '_ \)/ _\` || |  "
echo -e "|_|   |_||_||_|       |_|   |_|   |_|  |_|| .__/ \__,_||_|  "
echo -e "========================================= |_| ============\e[0m"
echo

#ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | awk -F "pool " '{print $2}' | sort | uniq

#IFS=$'\n' array_name=($(COMMAND))

### GET LIST OF ALL PHP-FPM POOLS FROM PROCESS LIST ###
IFS=$'\n' list_of_pools=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | awk -F "pool " '{print $2}' | sort | uniq | sed -e 's/ //g'))
#IFS=$'\n' total_pool_mem_usage=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | awk -F "pool " '{print $2}' | sort | uniq))

total_server_memory=`cat /proc/meminfo  | grep MemTotal | awk '{print $2}'`
total_phpfpm_mem_usage=0
let no_of_pools=(${#list_of_pools[@]}-1)

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

echo -e "\e[32m\e[1m=== List of PHP-FPM pools ===\e[0m"

for ((i=0; i<=no_of_pools; i++))
do
   echo -en "\e[36m\e[1m--- "
   echo -en ${list_of_pools[$i]}
   echo -e " ---\e[0m"
   echo -n "Configuration file: "; echo `grep "\[${list_of_pools[$i]}\]" $pool_directory | cut -d: -f1`

   if [ $fpm_type == "php-fpm" ]; then
      IFS=$'\n' list_of_pids=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | grep "pool ${list_of_pools[$i]}$" | awk '{print $2}'))
   elif [ $fpm_type == "php5-fpm" ]; then ### Ubuntu/PHP5-FPM nuance in ps output
      IFS=$'\n' list_of_pids=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | grep "pool ${list_of_pools[$i]} " | awk '{print $2}'))
   fi

###
   echo -n "List of processes: "
   echo ${list_of_pids[@]}

   echo -n "Number of processes: "
   echo ${#list_of_pids[@]}

   total_pool_mem_usage[$i]=0
   for a in "${list_of_pids[@]}"
   do
      let total_pool_mem_usage[$i]+=`pmap -d $a | grep "writeable/private" | awk '{ print $4 }' | sed -e s/K//`
   done
   echo -n "Total memory usage for pool in KB: "
   echo ${total_pool_mem_usage[$i]}
   let total_phpfpm_mem_usage+=${total_pool_mem_usage[$i]}

   echo -n "Average memory usage per process in KB: "
   pool_ave_process_size[$i]=`echo "${total_pool_mem_usage[$i]} / ${#list_of_pids[@]}" | bc`
   echo ${pool_ave_process_size[$i]}

#   # do whatever on $i
   echo
done

echo -e "\e[32m\e[1m=== Server statistics ===\e[0m"

echo -n "Total server memory in KB: "
echo $total_server_memory

#echo -n "Total PHP-FPM memory usage in KB: "
#echo $total_phpfpm_mem_usage

echo -n "Total Apache memory usage in KB: "
apache_process_name=`apachectl -V 2>&1 | grep PID | awk -F"run/" '{print $2}' | cut -d. -f1`
ps aux | grep -v ^root | egrep $apache_process_name > /dev/null
   if [ $? == 0 ]; then
      IFS=$'\n' list_of_apache_pids=($(ps aux | grep $apache_process_name | grep -v ^root | grep -v grep | awk '{print $2}'))
      total_apache_pool_mem_usage=0
      for a in "${list_of_apache_pids[@]}"
      do
         let total_apache_pool_mem_usage+=`pmap -d $a | grep "writeable/private" | awk '{ print $4 }' | sed -e s/K//`
      done
   else
      total_apache_pool_mem_usage=0
   fi
echo $total_apache_pool_mem_usage

echo -n "Total Varnish memory usage in KB: "
ps aux | grep -v ^root | grep varnish > /dev/null
   if [ $? == 0 ]; then
      varnish_perc=`ps aux | grep -v ^root | grep varnish | awk '{print $4}'`
      total_varnish_mem_usage=`echo "$total_server_memory / 100 * $varnish_perc" | bc`
   else
      total_varnish_mem_usage=0
   fi
echo $total_varnish_mem_usage

echo -n "Total MySQL memory usage in KB: "
ps aux | grep -v ^root | grep mysql > /dev/null
   if [ $? == 0 ]; then
      mysql_perc=`ps aux | grep -v ^root | grep mysql | awk '{print $4}'`
      total_mysql_pool_mem_usage=`echo "$total_server_memory / 100 * $mysql_perc" | bc`
   else
      total_mysql_pool_mem_usage=0
   fi
echo $total_mysql_pool_mem_usage

echo
echo -n "Memory available to assign to PHP-FPM pools in KB: "
   total_phpfpm_allowed_memory=`echo "$total_server_memory - ($total_apache_pool_mem_usage + $total_mysql_pool_mem_usage + $total_varnish_mem_usage)" | bc`
echo $total_phpfpm_allowed_memory

echo -n "(Current total PHP-FPM memory usage in KB: "
echo -n $total_phpfpm_mem_usage
echo ")"

echo
echo -e "\e[32m\e[1m=== Recommendations per pool ===\e[0m"

for ((i=0; i<=no_of_pools; i++))
do
   #let pool_perc_mem_use[$i]=(${total_pool_mem_usage[$i]}/$total_phpfpm_mem_usage)*100
   pool_perc_mem_use[$i]=`echo "scale=2; ${total_pool_mem_usage[$i]}*100/$total_phpfpm_mem_usage" | bc`
   #pool_allowed_mem_use[$i]=`echo "$total_server_memory * ${pool_perc_mem_use[$i]} / 100" | bc`
   pool_allowed_mem_use[$i]=`echo "$total_phpfpm_allowed_memory * ${pool_perc_mem_use[$i]} / 100" | bc`
   pool_allowed_max_children[$i]=`echo "${pool_allowed_mem_use[$i]} / ${pool_ave_process_size[$i]}" | bc`
   config_file_location=`grep "\[${list_of_pools[$i]}\]" $pool_directory | cut -d: -f1`
   current_max_children_value=`grep "^pm.max_children" $config_file_location | cut -d= -f2 | sed -e 's/ //g'`
   #let pool_perc_mem_use[$i]=32440/114680*100
   echo -e "\e[36m\e[1m-- ${list_of_pools[$i]} --\e[0m uses ${total_pool_mem_usage[$i]} KB memory (\e[33m${pool_perc_mem_use[$i]}%\e[0m of all PHP-FPM memory usage). It should be allowed to use about ${pool_allowed_mem_use[$i]} KB of all available memory. Its average process size is ${pool_ave_process_size[$i]} KB so this means \e[31mmax_children should be set to about \e[1m${pool_allowed_max_children[$i]}\e[0m. It is currently set to $current_max_children_value (this can be changed in $config_file_location)."
   #echo "-- ${list_of_pools[$i]} -- uses ${total_pool_mem_usage[$i]} KB memory (${pool_perc_mem_use[$i]}% of all PHP-FPM memory usage). Should be allowed ${pool_allowed_mem_use[$i]} KB of all available memory. Its average process size is ${pool_ave_process_size[$i]} KB so this means max_children should be set to ${pool_allowed_max_children[$i]}. It is currently set to $current_max_children_value (this can be changed in $config_file_location)."
#   echo ${total_pool_mem_usage[$i]}
done

echo
#
#####echo ${list_of_pools[@]}
