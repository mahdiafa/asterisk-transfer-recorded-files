#!/bin/bash
# Creator: Mahdi Afazeli
# Created on: 2018-02-25
# This is for transfer old recorded voice from elastix to backup server
# for that firstly find the old files and after archive, scp them to the backup server
time=$(date)
year=$(date +"%") # find the year
date=$(date +"%Y%m" --date="180 day ago") # find date (month of the year) that you want to backup and transfers recorded files  
olddate=$(date +"%Y%m" --date="210 day ago") # find date (month of the year) that you backup and transfers recorded files last month
log="/tmp/transfer.$(date +%Y%m%d).log" # where you would like logs stored
dir="/var/spool/asterisk/monitor" # default directory of asterisk that store the recorded files
srv="BACKUPSERVER" # Please change it to name or IP of your backup server
port="22" # if you  changed the default ssh port, please change it
maillist="your-email@your-domain" # Please change it to your email address
host=$(hostname -s) # it is just hostname
avail=$(df -Ph / | awk '{print $4}' | grep -v Av)
oldsrvfile=$(ssh backup@"$srv" -p"$port" du -h /backup/"$host"/"$year"/"$olddate" | awk '{print $1}' | sed s/G//)
oldfile=$(du -ch "$dir"/arch* | tail -1 | awk '{print $1}' | sed s/G//)
use=$(df -Ph / | awk '{print $5}' | grep -v Use)

# find files for transfer seperated by incomming, outgoing and group of calls
in=$(find $dir -name "$date??-*" | awk -F "/" '{print $6}' | sort)
out=$(find $dir -name "OUT???-$date??-*" | awk -F "/" '{print $6}' | sort)
grp=$(find $dir -name "g???-$date??-*" | awk -F "/" '{print $6}' | sort)

echo "Transfer start at $time for $date date files" >> "$log"

# check old file are exist in the backup server or not
/usr/bin/ssh backup@"$srv" -p"$port" ls /backup/"$host"/"$year"/"$olddate"/archi*
if [ $? = 0 ]
then
	echo "Return code is:$?. Means archive file for $olddate are exist in backup server" >> "$log"
  	cd $dir
  	if [[ $dir = $(pwd) ]]
  	then
    		echo "We are in $dir" >> $log
		if [ "$oldsrvfile" -eq "$oldfile" ]
    		then
			/bin/rm -f archive-"$olddate"*.tar.gz
    			echo "oldest archive files are removed by $? return code" >> "$log"
		else
			echo "$oldsrvfile" and "$oldfile" >> "$log"
			echo "there is something wrong in the oldest archived files between $host and backupServer" >> "$log"
			exit 500
		fi
	else
		echo "We are not in a correct directory" >> "$log"
    		exit 255
  	fi
	echo `pwd`  
	/bin/tar -vczf archive-"$date".tar.gz $in &&
	if [ $? -eq 0 ]
	then
		/bin/rm -f $in
	else
		exit 500
	fi
 	echo "incomming files with $(ls -lhs "$dir"/archive-"$date".tar.gz | awk '{print $1}') size archived" >> "$log"
	/bin/tar -vczf archive-"$date"-g.tar.gz $grp &&
	if [ $? -eq 0 ]
        then
                /bin/rm -f $grp
        else
                exit 500
        fi
  	echo "group files with $(ls -lhs "$dir"/archive-"$date"-g.tar.gz | awk '{print $1}') archived" >> "$log"
	/bin/tar -vczf archive-"$date"-out.tar.gz $out &&
	if [ $? -eq 0 ]
        then
                /bin/rm -f $out
        else
                exit 500
        fi
	echo "outgoing files with $(ls -lhs "$dir"/archive-"$date"-out.tar.gz | awk '{print $1}') archived" >> "$log"

### make a directory to transfer the files ###
	/usr/bin/ssh backup@"$srv" -p"$port" mkdir -p /backup/"$host"/"$year"/"$date"
	echo "directory created with $? return code"
### transfer all archived files to the backup server and put them to the related directory
	/usr/bin/scp -P"$port" archive-"$date"*.tar.gz backup@"$srv":/backup/"$host"/"$year"/"$date" 
  	echo "Transfer stop at $time for $date date files with return code $?" >> "$log"

### remove files after transfer
  	#/bin/rm -f "$in" "$out" "$grp"
  	#echo "Files for $date are removed from hdd" >> "$log"

  	echo -e "Dear sysadmin\\nPleased be informed that files for $date, archived and transferd successfully.\\nRight now server has $(df -Ph / | awk '{print $4}' | grep -v Av) available disk space ($(df -Ph / | awk '{print $5}' | grep -v Use)) under root directory\\nRegards,\\n$(hostname)" | mail -s "$host file trasfer was ok" $maillist
else
  	echo "There is some problem, please check archive files in backup server or connection between the servers" >> "$log"
  	echo "Transfer stop at $time for $date date files with return code $?" >> "$log"
  	echo -e "Dear maillist\\nPlease be informed that file transfer to the backup server has been failed\\nRight now server has $(df -Ph / | awk '{print $4}' | grep -v Av) available disk under root directory\\nRegards,\\n$(hostname)" | mail -s "$host file trasfer was nok" $maillist
fi
