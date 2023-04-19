#!/bin/bash

########### RECOVERY LOCK SCRIPT (M1) ###########
# This Script allows you to select a smart group,
# static group, or a list of serial numbers. It
# first starts by getting a list of serials and 
# the corresponding management ids. (Which the 
# number of computers will pull and make a CSV 
# document.) {Python needed} 
#
#
# Created by Chris Zimmerman 3-22-22 
# HUGE THANK YOU to @joshvotnoy -- feedback on March 7th led to this script being
# so much better
# Updates Committed February 24th 2023
# V5 Commit Date - March 10th 2023
# V6 Commit Date - March 20th 2023
# 
#
# 
# By using this script you agree to using it "as -is".
# Total number of computers in your environment
numberofcomputers=""
###### Will be prompted later if you prefer to not have plain text credentials ####
username=""
password=""
#### https://instancename.jamfcloud.com
jurl=""
####### RECOMMENDED TO USE A SHARED PATH #########
####### If any values are not filled out, script will prompt for a file path that will be used for all ###
#/path/to/file (no extension on file)
sharedfilepath=""

#################################################

# Check for input on variables, prompt if empty

#number of computers

if [ -z ${numberofcomputers} ]; then
	echo "How many computers are in your Jamf Pro Environment?"
	read numberofcomputers
fi

# Empty Username
if [ -z ${username} ]; then
	echo "Please enter your Jamf Pro username: "
	read username
fi

# Empty Password
if [ -z ${password} ]; then
	echo "Please enter your Jamf Pro password: "
	read -s password
fi

# Empty jssURL
if [ -z ${jurl} ]; then
	echo "Please enter your Jamf Pro URL: "
	echo "(ex. https://server.jamfcloud.com)"
	read jurl
fi

# emptyfileextensions 
if [[ -z $sharedfilepath ]]; then
	filepathset=$(osascript << EOF
set theResponse to display dialog "Looks like you may have forgotten to establish a file path for the output on this script. Just specify a filepath and the necessary files will be created. (No need to set extensiontype)" default answer "/Users/Shared/ManagementID" with icon note buttons {"Cancel", "Continue"} default button "Continue"
text returned of theResponse
EOF
)

jsonpath="$filepathset.json"
csvpath="$filepathset.csv"
pspath="$filepathset.py"

	if [[ -e $jsonpath ]] || [[ -e $csvpath ]] || [[ -e $pspath ]]; then
		echo "found duplicate files, alerting user"
		freshstart=$(osascript << EOF
set theDialogText to "You may have some old documents from a previous workflow. Recommended action is to delete for best results. Would you like to do so now?"
display dialog theDialogText buttons {"Delete", "No thanks"}
EOF
)
		if [[ $freshstart =~ "Delete" ]]; then
			echo "deleting old documents"
			if [[ -e $jsonpath ]]; then
				echo "deleting old json"
				rm $jsonpath
			fi
			if [[ -e $csvpath ]]; then
				echo "deleting old csv"
				rm $csvpath
			fi
			if [[  -e $pspath ]]; then
				echo "deleting old python script"
				rm $pspath
			fi
		fi
	fi
fi

#max is 2000 -- no need to mess with this variable
if [[ $numberofcomputers -lt 500 ]]; then
	#recordsperpage=$numberofcomputers
	recordsperpage=$numberofcomputers
else
	recordsperpage=500
fi
if [[ $numberofcomputers -gt $recordsperpage ]]; then
	echo "That is a lot of computers"
	pnarrayadd=0
	noc=$numberofcomputers
	
	until [[ $noc -le 0 ]]
	do
		tp+=($pnarrayadd)
		noc=$((noc-$recordsperpage))
		((pnarrayadd++))
	done
else
	tp=(0)
fi
	
#creates the basic auth credentials from the classic authentication
if [[ -z $userpass64 ]]; then
	userpass64=$(printf '%s' "${username}:${password}" | /usr/bin/iconv -t ISO-8859-1 | /usr/bin/base64 -i - )
fi

#bearer token for JPAPI -- Used for Computers Preview and Issuing Recovery Lock Command
credentials=$(curl -s -X POST "$jurl/api/v1/auth/token" -H "accept: application/json" -H "Authorization: Basic '$userpass64'" | awk  '/token/{print $NF}' | tr -d \",)
if [[  -z $credentials ]]; then
	echo "There was an error, please check your account credentials and try again"
	exit 1
fi
setexpire=$(($(date +%s)+1790))

#Remove Json File if it exists -- It will make things complicated otherwise 
if [[ -e $jsonpath ]]; then
	echo "json found, deleting now"
	rm $jsonpath
fi

#creating python script
	cat << EOF > "$pspath"
import json

# specify the path to your JSON file
json_file_path = "$jsonpath"

# open the file and load its contents into a Python dictionary
with open(json_file_path, "r") as f:
	json_data = json.load(f)

# extract all pairs of "serialNumber" and "managementId" from within the "results" object
results = json_data.get("results", [])
pairs = []
for result in results:
	serial_number = result.get("serialNumber")
	management_id = result.get("managementId")
	if serial_number is not None and management_id is not None:
		pairs.append(f"{serial_number}, {management_id}")

# print each pair on its own line
for pair in pairs:
	print(pair)
EOF
#JSON File
for pn in ${tp[@]}; do
	jsoninfo=$(curl -X GET -s "$jurl/api/preview/computers?page=$pn&page-size=$recordsperpage&sort=name%3Aasc" -H "accept: application/json" -H "Authorization: Bearer $credentials") 
	echo "$jsoninfo" >> $jsonpath
	python3 "$pspath" >> $csvpath
	rm $jsonpath
done

#value that is important to the python script later
nc=$(cat $csvpath | wc -l)
echo "number of computers returned:$nc"
			
# Determine Workflow (Single, Multiple or Cancel)
prompt=$(/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper\
	-windowType hud\
	-description "Would you like to import a Smart / Static Group?"\
	-button1 "Yes"\
	-button2 "No"\
	-defaultButton 1)
			
			
if [[ $prompt -eq "0" ]]; then
	smartgroupselection=$(osascript << EOF 
set smartgroup to display dialog "Enter Computer Group ID" default answer "" with icon note buttons {"Cancel", "Continue"} default button "Continue"
text returned of smartgroup
EOF
)
	# generate an auth token
	authToken=$( /usr/bin/curl "${jurl}/uapi/auth/tokens" \
	--silent \
	--request POST \
	--header "Authorization: Basic ${userpass64}" )
	
	# Create token for authorization on classic API -- Only used for Smart Search Lookup
	token=$( /usr/bin/awk -F \" '{ print $4 }' <<< "$authToken" | /usr/bin/xargs )
	
	serialsreturned+=($(curl -s -X GET "$jurl/JSSResource/computergroups/id/$smartgroupselection" -H "accept: application/xml" -H "Authorization: Bearer $token" | xmllint --format - | awk -F'>|<' '/<serial_number>/{print $3}' | sort -n ))
				
	echo "${#serialsreturned[@]} serials found in smart group"
	notfound=0
	IFS=""
	for result in ${serialsreturned[@]}; do
		#checks for serial number in csv document
		csn=$(grep $result $csvpath)
		if [[ -z $csn ]]; then
			echo "$result not found"
			nfsn+=($result)
			((notfound++))
		else
			managementid+=($(awk -F, -v serial="$result" '$1 == serial { print $2; exit }' $csvpath))
		fi
	done
	if [[ $notfound -eq 0 ]]; then
		echo "All Serials Found in csv!"
	fi
	correctserials=$((${#serialsreturned[@]}-$notfound))

elif [[ $prompt -eq "2" ]]; then
				
	serialsearch=$(osascript << EOF 
set Serial to display dialog "Serial Number" default answer "" with icon note buttons {"Cancel", "Continue"} default button "Continue"
text returned of Serial
EOF
)
				
	if [[ -z $serialsearch ]]; then
		echo "$serialsearch not found"
		exit 1
	else
		IFS=","
		for result in $serialsearch; do
			managementid+=($(awk -F, -v serial="$result" '$1 == serial { print $2; exit }' $csvpath))
		done
		correctserials=1
	fi
else
	exit 1
fi
			
#Set Recovery Lock Prompt
rmpass=0
	random=$(osascript << EOF
set theDialogText to "Would you like to send randomized passwords to your computers or set your own? (Note: Command will send to any machines in scope, but will not work on Intel Machines)"
display dialog theDialogText buttons {"Static", "Random"} default button "Random"
EOF
)

if [[ $random =~ "Random" ]]; then
	echo "random selected"
	((rmpass++))
fi

#run commands on the computers in scope -- refreshing bearer token if needed 
success=0
fail=0
cpb=1

if [[ $rmpass -eq 0 ]]; then
rlpass=$(osascript << EOF
set theResponse to display dialog "Please Enter your Recovery Lock Password: (Note: Command will send to any machines in scope, but will not work on Intel Machines)" default answer "" with icon note buttons {"Cancel", "Continue"} default button "Continue"
text returned of theResponse
EOF
)
	if [[ -z $rlpass ]]; then
		exit 1
	fi
	for mid in ${managementid[@]}; do
		if [[ $(date +%s) -ge $setexpire ]]; then
			echo "Auth token Expired, reissuing now"
			credentials=$(curl -s -X POST "$jurl/api/v1/auth/token" -H "accept: application/json" -H "Authorization: Basic '$userpass64'" | awk  '/token/{print $NF}' | tr -d \",)
			setexpire=$(($(date +%s)+1790))
		fi
		echo "Sending command $cpb of $correctserials"
		((cpb++))
		task=$(curl -s -X POST "$jurl/api/preview/mdm/commands" -H "accept: application/json" -H "Authorization: Bearer $credentials" -H "Content-Type: application/json" -d "{\"clientData\":[{\"managementId\":\"$mid\",\"clientType\":\"COMPUTER\"}],\"commandData\":{\"commandType\":\"SET_RECOVERY_LOCK\",\"newPassword\":\"$rlpass\"}}")
		check=$(echo "$task" | grep "id" | awk '{print ($NF)}')
		if [[ ! -z $check ]]; then
			((success++))
		else
			failedsn+=($(grep "$mid" $csvpath | awk -F '[,]' '{print $1}'))
			((fail++))
		fi
	done
elif [[ $rmpass -eq 1 ]]; then
	for mid in ${managementid[@]}; do
		if [[ $(date +%s) -ge $setexpire ]]; then
			echo "Auth token Expired, reissuing now"
			credentials=$(curl -s -X POST "$jurl/api/v1/auth/token" -H "accept: application/json" -H "Authorization: Basic '$userpass64'" | awk  '/token/{print $NF}' | tr -d \",)
			setexpire=$(($(date +%s)+1790))
		fi
		#creates a randomized passcode that is 15 characters long
		rlpass=$(openssl rand -base64 15)
		echo "Sending command $cpb of $correctserials"
		((cpb++))
		task=$(curl -s -X POST "$jurl/api/preview/mdm/commands" -H "accept: application/json" -H "Authorization: Bearer $credentials" -H "Content-Type: application/json" -d "{\"clientData\":[{\"managementId\":\"$mid\",\"clientType\":\"COMPUTER\"}],\"commandData\":{\"commandType\":\"SET_RECOVERY_LOCK\",\"newPassword\":\"$rlpass\"}}")
		check=$(echo "$task" | grep "id" | awk '{print ($NF)}')
		if [[ ! -z $check ]]; then
			((success++))
		else
			failedsn+=($(grep "$mid" $csvpath | awk -F '[,]' '{print $1}'))
			((fail++))
		fi
	done
fi

logfile=/var/tmp/rlock.txt
			
#logic for success / failures
echo "command sent to $success computer(s)"
echo "command not sent on $fail computer(s), check $logfile for more info"
echo "number of serials not found: $notfound"

$date=$(date)

#logfile for failures
if [[ $fail -gt 0 ]] || [[ $notfound -gt 0 ]]; then
	if [[ ! -e $logfile ]]; then 
		touch $logfile 
	fi
	echo "Failed Serials on $date" >> $logfile
	echo "" >> $logfile
	formatsn=$(printf '%s\n' "${failedsn[@]}")
	echo "$formatsn" >> $logfile
	echo "" >> $logfile
	echo "Serials that could not be found from Smart Group:"
	formatns=$(printf '%s\n' "${nfsn[@]}")
	echo "$formatns" >> $logfile
fi
	
#cleanup
	delete=$(osascript << EOF
set theDialogText to "Commands Sent. Would you like to delete the old materials?"
display dialog theDialogText buttons {"Delete", "No thanks"}
EOF
)
	
if [[ $delete =~ "Delete" ]]; then
	echo "deleting old documents"
	rm $csvpath
	rm $pspath
else 
	exit 0
fi
