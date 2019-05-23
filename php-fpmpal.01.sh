#! /bin/bash


#============================================================================================
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | Logo method                                                         |
# |                                                                     |
# +---------------------------------------------------------------------+
#
function print_logo ()
{
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
}
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | /// END OF Logo method ///                                          |
# |                                                                     |
# +---------------------------------------------------------------------+
#
#============================================================================================
#
# +---------------------------------------------------------------------+
# |									|
# | Pre-checks methods							|
# |									|
# +---------------------------------------------------------------------+
#
# +---------------------------------------------------------------------+
# | Determine if PHP-FPM is installed and what the process name is      |
# +---------------------------------------------------------------------+
phpfpm_installed=0 # flag - is PHP-FPM installed? ( 0=No 1=Yes )
fpm_type='' # PHP-FPM process name ( php-fpm php5-fpm )

function check_php-fpm_installed_and_processname ()
{
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

        php-fpm7.2 -v 1> /dev/null 2>&1
        if [ $? == 0 ]; then
                phpfpm_installed=1
                fpm_type=`php-fpm7.2 -i 2>&1 | grep "SERVER\['_'\]" | cut -d\/ -f4`
        fi


	if [ $phpfpm_installed == 0 ]; then # Exit if PHP-FPM is not installed
		echo -e "\e[31m!!! PHP-FPM not detected. Exiting. !!!\e[0m"
		echo
		exit 1
	fi
}

# +---------------------------------------------------------------------+
# | Determine if PHP-FPM is running				        |
# +---------------------------------------------------------------------+
function check_php-fpm_running ()
{
	ps aux | grep "php-fpm" | grep -v grep |  grep -v "php-fpmpal" 1> /dev/null 2>&1
	if [ $? == 1 ]; then
		echo -e "\e[31m!!! PHP-FPM is installed but not running. PHP-FPM should be started before running this script. Exiting. !!!\e[0m"
		echo
		exit 1
	fi
}

# +---------------------------------------------------------------------+
# | Determine if BC is installed                                        |
# +---------------------------------------------------------------------+
function check_bc_install ()
{
	bc -v 1> /dev/null 2>&1
		if [ $? != 0 ]; then
		echo -e "\e[31m\"bc\" is not installed. This script depends on it. Exiting. \e[0m"
		echo
		exit 1
	fi
}
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | /// END OF Pre-checks methods ///                                   |
# |                                                                     |
# +---------------------------------------------------------------------+
#
#============================================================================================
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | Variable initialisation and general info gathering                  |
# |                                                                     |
# +---------------------------------------------------------------------+
#
function variable_initialisation ()
{
	# Apache root and config file
	httpd_root=`apachectl -V | awk -F "\"" '/HTTPD_ROOT/ {print $2}'`
	httpd_config_file=`apachectl -V | awk -F "\"" '/SERVER_CONFIG_FILE/ {print $2}'`
	httpd_root_and_config_file=$httpd_root"/"$httpd_config_file
	
	# List of Apache Includes (only 1 level deep from main configuration file)
	httpd_main_include=`awk -v var="$httpd_root"  '/^Include/ {print var "/" $2}' $httpd_root_and_config_file`
	IFS=$'\n' list_of_apache_includes=($(ls $httpd_main_include))
	
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
	function match_pool_to_config_file ()
	{
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
	}
	match_pool_to_config_file
}
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | /// END OF Variable initialisation and general info gathering ///   |
# |                                                                     |
# +---------------------------------------------------------------------+
#
#============================================================================================
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | Print out PHP-FPM pool information					|
# |                                                                     |
# +---------------------------------------------------------------------+
#
function display_pool_information ()
{
	echo
	echo -en "\e[38;5;22m=\e[38;5;28m=\e[38;5;34m=\e[38;5;40m=\e[38;5;46m="
	echo -en "\e[32m\e[1m List of PHP-FPM pools \e[0m"
	echo -e "\e[38;5;46m=\e[38;5;40m=\e[38;5;34m=\e[38;5;28m=\e[38;5;22m=\e[0m"

	### For each pool
	for ((i=0; i<=no_of_pools; i++))
	do
		### Print pool name and configuration file
		echo -en "\t\e[36m\e[1m--- "
		echo -en ${list_of_pools[$i]}
		echo -e " ---\e[0m"

		### Create a list of process IDs that belong to this pool
		IFS=$'\n' list_of_pids=($(ps aux | grep "php-fpm" | grep -v ^root | grep -v grep | grep pool | awk '{print $2, $13}' | grep " ${list_of_pools[$i]}$" | awk '{print $1}'))

		### Calculate the total memory usage for this pool
		total_pool_mem_usage[$i]=0
		### For each process
		for a in "${list_of_pids[@]}"
		do
			### Gather memory usage (using pmap) and add it to total_pool_mem_usage variable
			let total_pool_mem_usage[$i]+=`pmap -d $a | grep "writeable/private" | awk '{ print $4 }' | sed -e s/K//`
		done
		### Print total memory usage for this pool
		echo -en "\t\tTotal memory used: \e[1m"
		echo -en `echo "scale =2; ${total_pool_mem_usage[$i]}" / 1024 | bc`; echo -en " MB\e[0m\t"
		### Increase the total PHP-FPM memory usage with the total memory usage for this pool
		let total_phpfpm_mem_usage+=${total_pool_mem_usage[$i]}

        	### List total number of processes that belong to this pool
	        echo -n "Processes: "
	        echo -en "\e[1m${#list_of_pids[@]}\e[0m"

        	### Get the current max_children value
	        echo -en " \e[2m(max_children: "
	        current_max_children_value=`grep "^pm.max_children" ${pool_config_file[$i]} | cut -d= -f2 | sed -e 's/ //g' | tail -1`
	        echo -en "$current_max_children_value)\e[0m\t"

		### Calculate the average process memory usage for this pool
		echo -en "Ave. process: \e[1m"
		pool_ave_process_size[$i]=`echo "${total_pool_mem_usage[$i]} / ${#list_of_pids[@]}" | bc`
		echo -en `echo "scale =2; ${pool_ave_process_size[$i]}" / 1024 | bc`; echo -e " MB\e[0m"

		### Total potential memory usage for pool based on average process size: max_children * average process size
		potential_mem_usage=`echo "$current_max_children_value * ${pool_ave_process_size[$i]}" | bc`
		let total_phpfpm_mem_usage_average_process+=$potential_mem_usage
	done
	
}
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | /// END OF Print out PHP-FPM pool information ///                   |
# |                                                                     |
# +---------------------------------------------------------------------+
#
#============================================================================================
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | Print out server memory information	                    	        |
# |                                                                     |
# +---------------------------------------------------------------------+
#
function display_server_memory_information ()
{
	echo
	echo -en "\e[38;5;22m=\e[38;5;28m=\e[38;5;34m=\e[38;5;40m=\e[38;5;46m="
	echo -en "\e[32m\e[1m Server memory usage statistics \e[0m"
	echo -e "\e[38;5;46m=\e[38;5;40m=\e[38;5;34m=\e[38;5;28m=\e[38;5;22m=\e[0m"
	
	### Total server memory
	echo -ne "\tTotal server memory: "
	echo -ne "\t\t\t\t\e[1m"
	echo -ne `echo "scale =2; $total_server_memory" / 1024 | bc`; echo -e " MB\e[0m"
	
	# Calculate total memory available to assign to PHP-FPM
	echo -en "\tMemory available to assign to PHP-FPM pools: "
	
	### Total memory usage - (the sum of all other processes listed above)
	### Take total free memory and add current PHP-FPM total memory usage
	
	# RHEL 7's free reports look different to CentOS6, Ubuntu 14 and Debian 8 so I have to 1) check whether this is RHEL/CentOS 7, and 2) if it is, use different formulas
	rhel7_check=0
	if [ -f /etc/redhat-release ]; then
		rhel7_check=`cat /etc/redhat-release | awk -F "release" '{print $2}' | awk '{print $1}' | cut -d. -f1` > /dev/null
	fi

	# Ubuntu 18.04's free report looks different so we use a different formula
	ubuntu1804_check=0
	if [ -f /etc/lsb-release ]; then
		ubuntu1804_check=`grep DISTRIB_ID /etc/lsb-release | cut -d= -f2`
		if [ $ubuntu1804_check == 'Ubuntu' ]; then
			ubuntu1804_check=`grep DISTRIB_RELEASE /etc/lsb-release | cut -d= -f2`
			if [ $ubuntu1804_check == '18.04' ]; then
				ubuntu1804_check=1
			else
				ubuntu1804_check=0
			fi
		else
			ubuntu1804_check=0
		fi
	fi

	# If this is RHEL 7 then use this formula
	if [ $rhel7_check == '7' ]; then
		total_phpfpm_allowed_memory=$(echo "`free -k | awk '/Mem/ {print $7}'` + $total_phpfpm_mem_usage" | bc)
	
	# If this is Ubuntu 18.04 then use this formula
	elif [ $ubuntu1804_check == '1' ]; then
		total_phpfpm_allowed_memory=$(echo "`free -k | awk '/Mem/ {print $7}'` + $total_phpfpm_mem_usage" | bc)

	# If this is not RHEL 7 or Ubuntu 18.04	use this formula
	else
		total_phpfpm_allowed_memory=$(echo "`free -k | awk '/buffers\/cache/ {print $4}'` + $total_phpfpm_mem_usage" | bc)
	fi
	echo -ne "\t\e[1m"
        echo -ne `echo "scale =2; $total_phpfpm_allowed_memory" / 1024 | bc`; echo -e " MB\e[0m"
	echo -e "\t\t\e[2m(total free memory + PHP-FPM's current memory usage)\e[0m"
	echo

	### Print out total potential PHP-FPM usage based on average process size per pool
	echo -en "\tPotential PHP-FPM memory usage: "
	echo -en "\t\t\e[1m"
	echo -ne `echo "scale =2; $total_phpfpm_mem_usage_average_process" / 1024 | bc`; echo -en " MB\e[0m "
	echo -ne "\e[33m (`echo "scale=2; $total_phpfpm_mem_usage_average_process*100/$total_phpfpm_allowed_memory" | bc `"
	echo -n "%)"
	
	# Print warning if this is larger than allowed PHP-FPM memory usage
	if [ $total_phpfpm_mem_usage_average_process -gt $total_phpfpm_allowed_memory ]; then
		echo -e " \e[31m!!! THIS IS LARGER THAN THE ASSIGNED MEMORY USAGE !!!\e[0m"
	else
		echo -e " \e[32m...GOOD :-)\e[0m"   
	fi
	echo -e "\t\t\e[2m(based on current ave. process and max_children)\e[0m"
	echo
}	
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | /// END OF Print out server memory information ///                  |
# |                                                                     |
# +---------------------------------------------------------------------+
#
#============================================================================================
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | Calculate and display pool recommendations				|
# |                                                                     |
# +---------------------------------------------------------------------+
#
# +---------------------------------------------------------------------+
# | Succinct pool recommendations                                       |
# +---------------------------------------------------------------------+
function succinct_pool_recommendations ()
{
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
		echo -e "\t\e[36m\e[1m--- ${list_of_pools[$i]} ---\e[0m"
		echo -ne "\t\tCurrent usage: \e[1m${pool_perc_mem_use[$i]}%\e[0m"
		echo -ne "\tRecommended max_children: \e[1m${pool_allowed_max_children[$i]}\e[0m"
		echo -ne "\e[2m (current: $current_max_children_value)\e[0m"
		echo -ne "\tConfig file: ${pool_config_file[$i]}"
		echo
	done
	echo
}

# +---------------------------------------------------------------------+
# | Detailed pool recommendations                                 |
# +---------------------------------------------------------------------+
function detailed_pool_recommendations ()
{
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
                echo -e "\t\e[36m\e[1m--- ${list_of_pools[$i]} ---\e[0m"
                echo -ne "\t\tCurrent usage: \e[1m${pool_perc_mem_use[$i]}%\e[0m"
                echo -ne "\tRecommended max_children: \e[1m${pool_allowed_max_children[$i]}\e[0m"
                echo -ne "\e[2m (current: $current_max_children_value)\e[0m"
                echo -ne "\tConfig file: ${pool_config_file[$i]}"
                echo
		echo -ne "\t\tMemory usage: \e[1m"
		echo -ne `echo "scale =2; ${total_pool_mem_usage[$i]}" / 1024 | bc`; echo -ne " MB\e[0m"
		echo -ne "\tAllowed usage: \e[1m"
		echo -ne `echo "scale =2; ${pool_allowed_mem_use[$i]}" / 1024 | bc`; echo -ne " MB\e[0m"
		echo
        done
        echo
}
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | /// END OF Calculate and display pool recommendations ////          |
# |                                                                     |
# +---------------------------------------------------------------------+
#
#============================================================================================
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | Other recommendations methods                                       |
# |                                                                     |
# +---------------------------------------------------------------------+
#
# +---------------------------------------------------------------------+
# | Observations from the pool logfiles                                 |
# +---------------------------------------------------------------------+
function logfile_observations ()
{
	echo -en "\e[38;5;22m=\e[38;5;28m=\e[38;5;34m=\e[38;5;40m=\e[38;5;46m="
	echo -en "\e[32m\e[1m Observations from the pool logfiles \e[0m"
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
		echo "\tFrom the PHP-FPM error logfiles ($error_log_location):"
		zgrep "\tserver reached pm.max_children" $error_log_location* | awk '{print $5, $10}' | sed -e 's/[(),]//g' | sed -e 's/\]//g' | sort | uniq -c | awk '{print " - pool \033[36m" $2 "\033[0m had reached its max_children value of " $3 " on " $1 " occasion(s)"}'
		echo
		echo "\tFor these pools you may want to compare the recommended max_children value to this information, and decide whether the recommended value would be high enough to prevent max_children from being hit in future."

	# Else print that there are no further recommendations
	else
		echo -e "\tNo other recommendations/observations at this stage."
	fi
}

# +---------------------------------------------------------------------+
# | General information about this script's usage                       |
# +---------------------------------------------------------------------+
function general_script_info ()
{
	echo
        echo -en "\e[38;5;22m=\e[38;5;28m=\e[38;5;34m=\e[38;5;40m=\e[38;5;46m="
        echo -en "\e[32m\e[1m General information about this script's usage \e[0m"
        echo -e "\e[38;5;46m=\e[38;5;40m=\e[38;5;34m=\e[38;5;28m=\e[38;5;22m=\e[0m"
	echo -e "\tNote: It is not ideal to run PHP-FPMpal shortly after restarting PHP-FPM or your webservices. This is because PHP-FPMpal makes recommendations based on the average pool process size, and if PHP-FPM was restarted a short while ago then the likelihood is high that there won't have been many requests made to the sites since the restart, and metrics will be skewed and not show a normalised average."
	echo -e "\tIt is also worth noting that if you've recently restarted any services that normally use up a large amount of memory then you probably want to wait a while before running PHP-FPMpal (e.g. if MySQL normally uses 50% of memory, but you've just restarted it then it may only use 10% of memory right now, thus the recommendations will be very skewed)."
	echo
}
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | /// END OF Other recommendations methods ///                        |
# |                                                                     |
# +---------------------------------------------------------------------+
#
#============================================================================================
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | Debug methods                                                       |
# |                                                                     |
# +---------------------------------------------------------------------+
#
# +---------------------------------------------------------------------+
# | Print all variables for debugging                                   |
# +---------------------------------------------------------------------+
function debug_print_variables()
{
	echo "phpfpm_installed : $phpfpm_installed"
	echo "fpm_type : $fpm_type"
	echo "total_server_memory : $total_server_memory"
}
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | /// END OF Debug methods ///                                        |
# |                                                                     |
# +---------------------------------------------------------------------+
#
#============================================================================================
#
# +---------------------------------------------------------------------+
# |                                                                     |
# | Main methods                                                        |
# |                                                                     |
# +---------------------------------------------------------------------+
#
# +---------------------------------------------------------------------+
# | Verbose Main		                                        |
# +---------------------------------------------------------------------+
function main_verbose ()
{
	# Run pre-checks
	check_php-fpm_installed_and_processname
	check_php-fpm_running
	check_bc_install

	# Print Logo
	print_logo

	# Run variable initialisation and general information gathering
	variable_initialisation
	
	# Display information for each PHP-FPM pool
	display_pool_information

	# Display information on server memory
	display_server_memory_information

	# Calculate and display PHP-FPM pool recommendations
	detailed_pool_recommendations

	# Print observations from the logfiles
	logfile_observations

	# Print general information about this script's usage
	general_script_info
}

# +---------------------------------------------------------------------+
# | Succinct Main                                                        |
# +---------------------------------------------------------------------+
function main_succinct ()
{
        # Run pre-checks
        check_php-fpm_installed_and_processname
        check_php-fpm_running
        check_bc_install
       
        # Run variable initialisation and general information gathering
        variable_initialisation

        # Display information for each PHP-FPM pool
        display_pool_information

        # Display information on server memory
        display_server_memory_information

        # Calculate and display PHP-FPM pool recommendations
        succinct_pool_recommendations
}

#
# +---------------------------------------------------------------------+
# |                                                                     |
# | /// END OF Main methods ///                                         |
# |                                                                     |
# +---------------------------------------------------------------------+
#
#============================================================================================

if [ $# != 0 ]; then
	if [ $1 == "-d" ]; then
		main_verbose
	fi
else
	main_succinct
fi
