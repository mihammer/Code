#!/bin/bash

while :
do
echo "Linux Perf Diagnostics
    Select 1 2 or 3
1 - Install Linux Perf Insights
2 - Run Perf Linux Perf Insights
3 - Exit"
  read INPUT_STRING
  case $INPUT_STRING in
	1)
		# Install linux perf diagnostics

            #Check if Python is installed
            if which python > /dev/null 2>&1;
            then
                echo "Python is installed"

            #install perfiags 
            echo "What directory would you like to extract install files to? example /tmp"
            read directory

            #Does the directory exist?
                if [ -d "$directory" ]; then
                # Yes, the directory is there, let's get the file and extract 
                cd $directory
                wget https://perfinsightsforlinux.blob.core.windows.net/release/perfinsights.tar.gz
                tar xzvf perfinsights.tar.gz
                else
                    echo "This directory doesn't exist. Create it? y / n"
                        read yn
                        if [ $yn = y ]; then
                        mkdir $directory
                        wget https://perfinsightsforlinux.blob.core.windows.net/release/perfinsights.tar.gz
                        tar xzvf perfinsights.tar.gz
                        else
                        break
                        fi
                fi

            else
                echo "Python is not installed. Please install Python then try again. "
                break
            fi

            #install perfdiags
                sudo python setup.py install --record installationfile.txt
                    ;;
	2)  #run perfdiags
        sudo perfinsights -s basic
		;;
	*)
		echo "You must select 1 or 2. See you again!"
		break
		;;
  esac
done