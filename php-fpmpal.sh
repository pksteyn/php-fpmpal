#! /bin/bash

### Switches
function usage()
{
        echo
        echo "Usage: php-fpmpal.sh [OPTION]"
        echo
        echo "Arguments:"
        echo "  -MB [VALUE]             Specify how much memory (in MB) you would like the whole of PHP-FPM to be able to use and base the calculations on this value, rather than on the value worked out by the script"
        echo
}


if [ $# != 0 ]; then
   if [ $1 == "--help" ]; then
      usage
      exit 0
   fi
fi

### Check if the script is being run with root privileges
if [ $EUID != "0" ]; then
   echo "This script must be run as root" 1>&2
   echo
   echo
   exit 1
fi

### Check if bc is installed
bc -v 1> /dev/null 2>&1
if [ $? != 0 ]; then
   echo -e "\e[31m\"bc\" is not installed. This script depends on it.\e[0m"
while true; do
   echo "Do you wish to install bc? (y/n)"
   read yn < /dev/tty
   case $yn in
      [Yy]* ) python -mplatform | egrep -i 'debian|ubuntu' 2>&1 > /dev/null && apt-get install bc -y -qq || yum install bc -y -q ; break;;
      [Nn]* ) exit;;
      * ) echo "Please answer yes or no.";;
    esac
done
fi

### END OF switches

echo
echo -e "\e[38;5;81m (        )  (         (     (       *                      "
echo -e "\e[38;5;51m\e[1m )\ )  ( /(  )\ )      )\ )  )\ )  (  \`           \e[33m\e[1m      (   "
echo -e "\e[38;5;45m(()/(  )\())(()/(     (()/( (()/(  )\))(          \e[38;5;214m   )  )\  "
echo -e "\e[38;5;33m /(_))((_)\  /(_))     /(_)) /(_))((_)()\ \e[38;5;208m \`  )   ( /( ((_) "
echo -e "\e[38;5;27m(_))   _((_)(_))      (_))_|(_))  (_()((_) \e[38;5;124m/(/(   )(_)) _   "
echo -e "\e[0m\e[38;5;21m| _ \ | || || _ \ ___ | |_  | _ \ |  \/  |\e[38;5;88m\e[1m((_)_\ \e[38;5;88m((_)\e[0m\e[38;5;9m_ | |  "
echo -ne "\e[38;5;21m|  _/ | __ ||  _/|___|| __| |  _/ | |\/| |\e[38;5;9m| '_ \\"
echo -e "\e[38;5;88m\e[1m)\e[0m\e[38;5;9m/ _\` || |  "
echo -e "\e[38;5;21m|_|   |_||_||_|       |_|   |_|   |_|  |_|\e[38;5;9m| .__/ \__,_||_|  "
for i in {17..21} {21..17} {17..21} {21..17} {17..21} {21..17} {17..21} {21..17} {17..17} ; do echo -en "\e[38;5;${i}m=\e[0m" ; done
echo -en "\e[38;5;9m |_| "
for i in {17..21} {21..21} {21..21} {21..21} {20..16} ; do echo -en "\e[38;5;${i}m=\e[0m" ; done
echo -e "\e[0m"
echo
echo


### Determine whether the PHP-FPM process is called php-fpm or php5-fpm
phpfpm_installed=0

php-fpm -v 1> /dev/null 2>&1
if [ $? == 0 ]; then
   phpfpm_installed=1
   fpm_type=`php-fpm -i 2>&1 | grep "SERVER\[\"_\"\]" | cut -d\/ -f4`
fi

php5-fpm -v 1> /dev/null 2>&1
if [ $? == 0 ]; then
   phpfpm_installed=1
   fpm_type=`php5-fpm -i 2>&1 | grep "SERVER\[\"_\"\]" | cut -d\/ -f4`
fi

### Exit if PHP-FPM is not installed
if [ $phpfpm_installed == 0 ]; then
   echo -e "\e[31m!!! PHP-FPM not detected. Exiting. !!!\e[0m"
   echo
   exit 1
fi

### Check if PHP-FPM is running
ps aux | grep "php-fpm" | grep -v grep |  grep -v "php-fpmpal" 1> /dev/null 2>&1
if [ $? == 1 ]; then
   echo -e "\e[31m!!! PHP-FPM is installed but not running. PHP-FPM should be started before running this script. Exiting. !!!\e[0m"
   echo
   exit 1
fi

### VARIABLE INITIALISATION

# Apache root and config file
#apachectl -V 1> /dev/null 2>&1
if [ $(which apachectl | wc -l) != 0 ]; then
	httpd_root=`apachectl -V | awk -F "\"" '/HTTPD_ROOT/ {print $2}'`
	httpd_config_file=`apachectl -V | awk -F "\"" '/SERVER_CONFIG_FILE/ {print $2}'`
	httpd_root_and_config_file=$httpd_root"/"$httpd_config_file
	# Apache Includes (only 1 level deep from main configuration file)
	httpd_main_include=`awk -v var="$httpd_root"  '/^Include/ {print var "/" $2}' $httpd_root_and_config_file`
	IFS=$'\n' list_of_apache_includes=($(ls $httpd_main_include))
fi
### Get list of all PHP-FPM pools from process list
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


### Get list of possible configuration files
IFS=$'\n' list_of_includes=($(grep -i ^include `ps aux | egrep "php.*master" | grep -v grep | cut -d\( -f2 | cut -d\) -f1` | cut -d= -f2))

### Set total number of include files
let no_of_includes=(${#list_of_includes[@]}-1)

### Match each pool to its configuration file
for ((p=0; p<=no_of_pools; p++))
do
   for ((i=0; i<=no_of_includes; i++ ))
   do
      grep "\[${list_of_pools[$p]}\]" ${list_of_includes[$i]} > /dev/null
      if [ $? == 0 ]; then
         pool_config_file[$p]="${list_of_includes[$i]}"
      fi
   done
done


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
   echo -n "Configuration file: "; echo `grep -H "\[${list_of_pools[$i]}\]" ${pool_config_file[$i]} | cut -d: -f1`


if [ 0 == 1 ]; then
   ### Find the site(s) that rely on this pool
   # Find the socket/TCP listener for this pool
   pool_listener=`egrep -i "^listen" ${pool_config_file[$i]} | sed -e 's/ //g' | grep "^listen=" | cut -d= -f2`
 
   # Find the FastCGIExternalServer directive for this socket in the Apache configuration and get the "Alias/Action"
   action_alias=`grep -h "FastCGIExternalServer" ${list_of_apache_includes[@]} | grep -v "#" | grep $pool_listener | awk '{print $2}'`
   #echo $action_alias
   
   # Find all the vhost files within which the "Alias/Action" is referenced
   # First find out whether any sites rely on this pool
   grep -H $action_alias ${list_of_apache_includes[@]} | grep Alias | grep -v "#" | awk '{print $4, $1}' | grep "$action_alias " > /dev/null
   # If no sites rely on it
   if [ $? == 1 ]; then
      echo "Site(s) that rely on this pool: None"
   
   # Else if at least one site relies on it
   else
      IFS=$'\n' vhost_name=($(grep -H $action_alias ${list_of_apache_includes[@]} | grep Alias | grep -v "#" | awk '{print $4, $1}' | grep "$action_alias " | awk '{print $2}' | cut -d: -f1))
      #echo ${vhost_name[@]}

     # As there may be multiple vhosts in the file, we want to extract just the vhost within which the "Alias/Action" was referenced
      echo "" > temp_filelist
      echo "" > filelist
   
      #action_line_nr=`grep -hn $action_alias$ ${list_of_apache_includes[@]} | grep Alias | grep -v "#" | cut -d: -f1`
      #echo $action_line_nr >> temp_filelist
   
      let no_of_vhosts_that_rely_on_this_pool=(${#vhost_name[@]}-1)
  
      #echo ${vhost_name[@]}
      #echo -n "nr_of_vhosts: "
      #echo $no_of_vhosts_that_rely_on_this_pool

      #nr_of_vhost_name=${#vhost_name[@]}

      #let nr_of_vhost_name=(${#vhost_name[@]}-1) 
      #echo $nr_of_vhost_name
      # for every vhosts pull out the sitename
      echo -n "Site(s) that rely on this pool: "
      #for a in ${nr_of_vhost_name[@]} ###
      #for ((i=0; i<=no_of_vhosts_that_rely_on_this_pool; i++))
      for ((i=0; i<=no_of_vhosts_that_rely_on_this_pool; i++))
      #for ((i=0; i<=1; i++))
      do ###
         action_line_nr=`grep -hn $action_alias$ ${vhost_name[$i]} | grep Alias | grep -v "#" | cut -d: -f1`
         
         echo $action_line_nr >> temp_filelist
         egrep -n "<VirtualHost|</VirtualHost" ${vhost_name[$i]} | grep -v "#" | cut -d: -f1 >> temp_filelist
         sort -n temp_filelist > filelist
         vhost_start_line=`grep -B1 $action_line_nr filelist | head -1`
         vhost_end_line=`grep -A1 $action_line_nr filelist | tail -1`
         rm -rf filelist
         rm -rf temp_filelist
         
         site_name=`sed -n "$vhost_start_line,$vhost_end_line p" ${vhost_name[$i]} | grep ServerName | awk '{print $2}'`
         echo -ne "\e[36m\e[1m$site_name\e[0m "
      done ###
      echo
   fi
fi
   



### ROLLBACK
if [ 0 == 1 ]; then
   ### Find the site(s) that rely on this pool
   # Find the socket/TCP listener for this pool
   pool_listener=`egrep -i "^listen" ${pool_config_file[$i]} | sed -e 's/ //g' | grep "^listen=" | cut -d= -f2`

   # Find the FastCGIExternalServer directive for this socket in the Apache configuration and get the "Alias/Action"
   action_alias=`grep -h "FastCGIExternalServer" ${list_of_apache_includes[@]} | grep -v "#" | grep $pool_listener | awk '{print $2}'`

   # Find the vhost file within which the "Alias/Action" is referenced
   vhost_name=`grep -H $action_alias ${list_of_apache_includes[@]} | grep Alias | cut -d: -f1`

  # As there may be multiple vhosts in the file, we want to extract just the vhost within which the "Alias/Action" was referenced
   echo "" > temp_filelist
   echo "" > filelist

   action_line_nr=`grep -hn $action_alias ${list_of_apache_includes[@]} | grep Alias | cut -d: -f1`
   echo $action_line_nr >> temp_filelist

   egrep -n "<VirtualHost|</VirtualHost" $vhost_name | grep -v "#" | cut -d: -f1 >> temp_filelist

   sort -n temp_filelist > filelist

   vhost_start_line=`grep -B1 $action_line_nr filelist | head -1`
   vhost_end_line=`grep -A1 $action_line_nr filelist | tail -1`

   rm -rf filelist
   rm -rf temp_filelist

   echo -n "Site(s) that rely on this pool: "
   site_name=`sed -n "$vhost_start_line,$vhost_end_line p" $vhost_name | grep ServerName | awk '{print $2}'`
   echo -e "\e[36m$site_name\e[0m"
fi
### /ROLLBACK
 

   ### Create a list of process IDs that belong to this pool
   IFS=$'\n' list_of_pids=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | grep pool | awk '{print $2, $13}' | grep " ${list_of_pools[$i]}$" | awk '{print $1}'))

   ### List all process IDs that belong to this pool
   echo -n "List of processes: "
   echo ${list_of_pids[@]}

   ### List total number of processes that belong to this pool
   echo -n "Number of processes: "
   echo ${#list_of_pids[@]}

   ### Get the current max_children value
   echo -n "Current max_children value: "
   current_max_children_value=`grep "^pm.max_children" ${pool_config_file[$i]} | cut -d= -f2 | sed -e 's/ //g' | tail -1`
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

   ### Total potential memory usage for pool based on average process size: max_children * average process size
   echo -n "Total potential memory usage for pool (based on average process) (KB): "
   potential_mem_usage=`echo "$current_max_children_value * ${pool_ave_process_size[$i]}" | bc`
   let total_phpfpm_mem_usage_average_process+=$potential_mem_usage
   echo $potential_mem_usage

   ### Get the largest pool process size
   echo -n "Largest process in this pool is (KB): "
   for a in "${list_of_pids[@]}"
   do 
      pool_processes_mem_size[$a]=`pmap -d $a | grep "writeable/private" | awk '{ print $4 }' | sed -e s/K// | sort -nr | head -1 | sort -nr | head -1`
   done
   let largest_pool_process_size=`echo "${pool_processes_mem_size[*]}" | sort -nr | head -1`
   echo $largest_pool_process_size

   ### Total potential memory usage for pool based on largest process size: max_children * largest process size
   echo -n "Total potential memory usage for pool (based on largest process) (KB): "
   potential_mem_usage=`echo "$current_max_children_value * $largest_pool_process_size" | bc`
   let total_phpfpm_mem_usage_largest_process+=$potential_mem_usage
   echo $potential_mem_usage

   echo
done

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
# If Apache is installed
apachectl -V 1> /dev/null 2>&1
if [ $? == 0 ]; then
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
else
   total_apache_pool_mem_usage=0
fi
echo $total_apache_pool_mem_usage

### Calculate total nginx memory usage
echo -n "  =Total nginx memory usage in KB: "
nginx -v 1> /dev/null 2>&1
# If nginx is installed
if [ $? == 0 ]; then
   IFS=$'\n' list_of_nginx_pids=($(ps aux | grep -i nginx | grep -v ^root | grep -v grep | awk '{print $2}'))
   total_nginx_mem_usage=0
   ### Add the memort usage for that process to the total nginx memory usage
   for a in "${list_of_nginx_pids[@]}"
   do
      let total_nginx_mem_usage+=`pmap -d $a | grep "writeable/private" | awk '{ print $4 }' | sed -e s/K//`
   done
# else if nginx is not installed
else
   total_nginx_mem_usage=0
fi
echo $total_nginx_mem_usage

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

### Print total current PHP-FPM memory usage
echo -n "  =Total PHP-FPM memory usage in KB: "
echo $total_phpfpm_mem_usage

echo

# Calculate total memory available to assign to PHP-FPM
echo -n "Memory available to assign to PHP-FPM pools in KB: "
   ### Total memory usage - (the sum of all other processes listed above)
   ### Take total free memory and add current PHP-FPM total memory usage
   # RHEL 7's free reports look different to CentOS6, Ubuntu 14 and Debian 8 so I have to 1) check whether this is RHEL/CentOS 7, and 2) if it is, use different formulas
   rhel7_check=0
   if [ -f /etc/redhat-release ]; then
      rhel7_check=`grep -v ^# /etc/redhat-release | awk -F "release" '{print $2}' | awk '{print $1}' | cut -d. -f1` > /dev/null
   fi
   # If this is RHEL 7 then use this formula
   if [ $rhel7_check == '7' ]; then
      total_phpfpm_allowed_memory=$(echo "`free -k | awk '/Mem/ {print $7}'` + $total_phpfpm_mem_usage" | bc)
   # If this is not RHEL 7 use this formula
   else
      total_phpfpm_allowed_memory=$(echo "`free -k | awk '/buffers\/cache/ {print $4}'` + $total_phpfpm_mem_usage" | bc)
   fi
# If the user has specified that they will set the available PHP-FPM memory themselves
if [ $# != 0 ]; then
   # then print out user-specified value
   if [ $1 == "-MB" ]; then
      total_phpfpm_allowed_memory=`echo "$2*1024" | bc`
      echo -n $total_phpfpm_allowed_memory
      echo " (user-specified)"
   fi
# Otherwise print out script-calculate value
else
   echo -n $total_phpfpm_allowed_memory
   echo " (total free memory + PHP-FPM's current memory usage)"
fi
echo


### Print out total potential PHP-FPM usage based on largest process size per pool
   echo -n "Total potential PHP-FPM memory usage based on largest processes (KB): "
   echo -n $total_phpfpm_mem_usage_largest_process
   echo -ne "\e[33m (`echo "scale=2; $total_phpfpm_mem_usage_largest_process*100/$total_phpfpm_allowed_memory" | bc `"
   echo -n "%)"
   # Print warning if this is larger than allowed PHP-FPM memory usage
   if [ $total_phpfpm_mem_usage_largest_process -gt $total_phpfpm_allowed_memory ]; then
      echo -e " \e[31m!!! THIS IS LARGER THAN THE ASSIGNED MEMORY USAGE !!!\e[0m"
   else
      echo -e " \e[32m...GOOD :-)\e[0m"
   fi

### Print out total potential PHP-FPM usage based on average process size per pool
   echo -n "Total potential PHP-FPM memory usage based on average process size (KB): "
   echo -n $total_phpfpm_mem_usage_average_process
   echo -ne "\e[33m (`echo "scale=2; $total_phpfpm_mem_usage_average_process*100/$total_phpfpm_allowed_memory" | bc `"
   echo -n "%)"
   # Print warning if this is larger than allowed PHP-FPM memory usage
   if [ $total_phpfpm_mem_usage_average_process -gt $total_phpfpm_allowed_memory ]; then
      echo -e " \e[31m!!! THIS IS LARGER THAN THE ASSIGNED MEMORY USAGE !!!\e[0m"
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
   ### Get the current max_children value for this PHP-FPM pool
   current_max_children_value=`grep "^pm.max_children" ${pool_config_file[$i]} | cut -d= -f2 | sed -e 's/ //g' | tail -1`
   ### Print out all this information
   echo -e "\e[36m\e[1m-- ${list_of_pools[$i]} --\e[0m currently uses ${total_pool_mem_usage[$i]} KB memory (\e[33m${pool_perc_mem_use[$i]}%\e[0m of all PHP-FPM memory usage). It should be allowed to use about ${pool_allowed_mem_use[$i]} KB of all available memory. Its average process size is ${pool_ave_process_size[$i]} KB so this means \e[38;5;208mmax_children should be set to ~\e[1m${pool_allowed_max_children[$i]}\e[0m. It is currently set to $current_max_children_value (this can be changed in ${pool_config_file[$i]})."
done

echo
### END OF Calculate and display recommendations for every PHP-FPM pool
### ===================================================================


### Other considerations
### ====================
echo -en "\e[38;5;22m=\e[38;5;28m=\e[38;5;34m=\e[38;5;40m=\e[38;5;46m="
echo -en "\e[32m\e[1m Other considerations to take into account \e[0m"
echo -e "\e[38;5;46m=\e[38;5;40m=\e[38;5;34m=\e[38;5;28m=\e[38;5;22m=\e[0m"

# Find PHP-FPM main configuration file
main_phpfpm_config_file=`ps aux | grep "php-fpm: master process" | grep -v grep | awk -F 'process' '{print $2}' | sed -e 's/[() ]//g'`

# Get error log location from main configuration file
error_log_location=`grep "^error_log" $main_phpfpm_config_file | awk '{print $3}'`

# Find out whether there were any max_children errors in the logs
errors_in_logs=`zgrep "server reached pm.max_children" $error_log_location* | wc -l` > /dev/null

# If there were max_children errors
if [ $errors_in_logs != 0 ]; then
   # Print out consideration regarding this
   echo "From the PHP-FPM error logfiles ($error_log_location):"
   zgrep "server reached pm.max_children" $error_log_location* | awk '{print $5, $10}' | sed -e 's/[(),]//g' | sed -e 's/\]//g' | sort | uniq -c | awk '{print " - pool \033[36m" $2 "\033[0m had reached its max_children value of " $3 " on " $1 " occasion(s)"}'
   echo
   echo "For these pools you may want to compare the recommended max_children value to this information, and decide whether the recommended value would be high enough to prevent max_children from being hit in future."
# Else print that there are no further recommendations
else
   echo "No other recommendations at this stage."
fi

# PHP-FPMpal usage
echo
echo "Note: It is not ideal to run PHP-FPMpal shortly after restarting PHP-FPM or your webservices. This is because PHP-FPMpal makes recommendations based on the average pool process size, and if PHP-FPM was restarted a short while ago then the likelihood is high that there won't have been many requests made to the sites since the restart, and metrics will be skewed and not show a normalised average."
echo "It is also worth noting that if you've recently restarted any services that normally use up a large amount of memory then you probably want to wait a while before running PHP-FPMpal (e.g. if MySQL normally uses 50% of memory, but you've just restarted it then it may only use 10% of memory right now, thus the recommendations will be very skewed)."

echo
### END OF Other considerations
### ===========================

for i in {17..21} {21..17} {17..21} {21..17} {17..21} {21..17} {17..21} {21..17} {17..21} {21..17} {17..21} {21..17} ; do echo -en "\e[38;5;${i}m=\e[0m" ; done
echo -e "\e[0m"
echo
