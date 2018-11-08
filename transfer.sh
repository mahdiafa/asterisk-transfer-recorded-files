#!/bin/bash
# Creator: Mahdi Afazeli
# Created on: 2018-02-25
# REV 1.1.B
# This is for transfer old recorded voice from elastix to backup server
# for that firstly find the old files and after archive, scp them to the backup server
time=$(date)
year=$(date +"%Y") # find the year
date=$(date +"%Y%m" --date="180 day ago") # find date (month of the year) that you want to backup and transfers recorded files  
log="/tmp/transfer.$(date +%Y%m%d).log" # where you would like logs stored
dir="/var/spool/asterisk/monitor" # default directory of asterisk that store the recorded files
srv="BACKUPSERVER" # Please change it to name or IP of your backup server
port="22" # if you  changed the default ssh port, please change it
maillist="your-email@your-domain" # Please change it to your email address
host=$(hostname -s) # it is just hostname
avail=$(df -Ph / | awk '{print $4}' | grep -v Av)
use=$(df -Ph / | awk '{print $5}' | grep -v Use)

# find files for transfer seperated by incomming, outgoing and group of calls
in=$(find $dir -name "$date??-*" | awk -F "/" '{print $6}' | sort)
out=$(find $dir -name "OUT???-$date??-*" | awk -F "/" '{print $6}' | sort)
grp=$(find $dir -name "g???-$date??-*" | awk -F "/" '{print $6}' | sort)

echo "Transfer start at $time for $date date files" >> "$log"

# Archive incomming files	
/bin/tar -vczf archive-"$date".tar.gz $in &&
if [ $? -eq 0 ]
then
	/bin/rm -f $in
else
	exit 500
fi
echo "incomming files with $(ls -lhs "$dir"/archive-"$date".tar.gz | awk '{print $1}') size archived" >> "$log"

# Archive group files
/bin/tar -vczf archive-"$date"-g.tar.gz $grp &&
if [ $? -eq 0 ]
then
	/bin/rm -f $grp
else
	exit 500
fi
echo "group files with $(ls -lhs "$dir"/archive-"$date"-g.tar.gz | awk '{print $1}') archived" >> "$log"

# Archve outgoing files
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

# find md5 checksum
cd "$dir" /usr/bin/md5sum archive-* > /tmp/sum

# check old file are exist in the backup server or not
/usr/bin/ssh backup@"$srv" -p"$port" cd /backup/"$host"/"$year"/"$date"/ && /usr/bin/md5sum archi* > /tmp/rsum &&

# check md5sum for local and remote files to make sure file are uploaded correctly
/usr/bin/diff /tmp/sum /tmp/rsum
echo "diff return code is: $?" >> "$log"
if [ $? -eq 0 ]
then
	/bin/rm -f "$dir"/arch*
  	echo -e "Dear sysadmin\\nPleased be informed that files for $date, archived and transferd successfully.\\nRight now server has $(df -Ph / | awk '{print $4}' | grep -v Av) available disk space ($(df -Ph / | awk '{print $5}' | grep -v Use)) under root directory\\nRegards,\\n$(hostname)" | mail -s "$host file trasfer was ok" $maillist
else
  	echo "There is some problem, please check archive files in backup server or connection between the servers" >> "$log"
  	echo "Transfer stop at $time for $date date files with return code $?" >> "$log"
  	echo -e "Dear sysadmin\\nPlease be informed that file transfer to the backup server has been failed\\nRight now server has $(df -Ph / | awk '{print $4}' | grep -v Av) available disk under root directory\\nRegards,\\n$(hostname)" | mail -s "$host file trasfer was nok" $maillist
fi
