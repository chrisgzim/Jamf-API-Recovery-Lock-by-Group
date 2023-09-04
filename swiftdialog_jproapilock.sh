#!/bin/bash

dialogBinary="/usr/local/bin/dialog"

file="/var/tmp/burnafterreading.txt"
commandfile=$( mktemp /var/tmp/recoverylock.XXX )
icon="SF=applelogo,colour=pink,colour2=purple"

title="Sending Recovery Lock Commands"
message="Sending Recovery Lock Commands. Depending on the amount of commands, this could take awhile."
message1="There was a problem with your API Credentials, please try again."
message2="Number of Managed Computers= Total number of computers that are managed in your Jamf Pro Environment \n\nAPI Username / Password= Credentials for an API account that has the following permissions: \n\nRead Computers, Read Computer Groups, and Send Recovery Lock Command. \n\nSelect Your Workflow= You can leverage a Computer Group in Jamf or you can just type in serial numbers on the next prompt. \n\nSelect Password Type= Gives an option for a randomized 15 character password or you can set your own password for all machines in scope."

message3="Computer Serial Numbers Field. On this field, you can enter 1 or more serial numbers in your Jamf Pro Environment. All you have to do is separate the Serial Numbers with a comma. \n\ni.e. serialnumber1,serialnumber2,serialnumber3,etc."

function dialogUpdate () {
	echo "$1" >> "$commandfile"
}

function preflight {
	
	# Get the URL of the latest PKG From the Dialog GitHub repo
	dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
	
	# Expected Team ID of the downloaded PKG
	expectedDialogTeamID="PWA5E9TQ59"
	
	updateScriptLog "PRE-FLIGHT CHECK: Installing swiftDialog..."
	
	# Create temporary working directory
	workDirectory=$( /usr/bin/basename "$0" )
	tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
	
	# Download the installer package
	/usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"
	
	# Verify the download
	teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
	
	# Install the package if Team ID validates
	if [[ "$expectedDialogTeamID" == "$teamID" ]]; then
		
		/usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
		sleep 2
		dialogVersion=$( /usr/local/bin/dialog --version )
		updateScriptLog "PRE-FLIGHT CHECK: swiftDialog version ${dialogVersion} installed; proceeding..."
		
	else
		
		# Display a so-called "simple" dialog if Team ID fails to validate
		osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Setup Your Mac: Error" buttons {"Close"} with icon caution'
		completionActionOption="Quit"
		exitCode="1"
		quitScript
		
	fi
	
	# Remove the temporary working directory when done
	/bin/rm -Rf "$tempDirectory"

}
function start {

$dialogBinary \
--title \Set\ Recovery\ Lock \
--message \Please\ enter\ values\ into\ the\ required\ fields \
--icon \info \
--textfield \Number\ of\ Managed\ Computers\,regex="^[0-9]",regexerror="This must be a Number",required \
--textfield \API\ Username\,required \
--textfield \API\ Password\,required,secure \
--textfield \Jamf\ Pro\ Server\ URL\,prompt="https://instance.jamfcloud.com",required \
--selecttitle \Select\ Your\ Workflow,radio \
--selectvalues \Static\ or\ Smart\ Group,Manual\ Entry \
--selecttitle \Select\ Password\ Type,radio \
--selectvalues \Random\,Set\ Your\ Own \
--big \
--button1text \Next \
--helpmessage \ "$message2" \ 2>&1 > $file

username=$(cat $file | grep "API Username" | awk '{print $NF}')
password=$(cat $file | grep "API Password" | awk '{print $NF}')
jurl=$(cat $file | grep "Jamf Pro Server URL" | awk '{print $NF}')
numberofcomputers=$(cat $file | grep "Number of Managed Computers" | awk '{print $NF}')
workflow=$(cat $file | grep "index" | grep "Workflow" | awk '{print $NF}' | xargs)
passwordtype=$(cat $file | grep "index" | grep "Password" | awk '{print $NF}' | xargs)

rm -r $file

userpass64=$(printf '%s' "${username}:${password}" | /usr/bin/iconv -t ISO-8859-1 | /usr/bin/base64 -i - )
credentials=$(curl -s -X POST "$jurl/api/v1/auth/token" -H "accept: application/json" -H "Authorization: Basic '$userpass64'" | awk  '/token/{print $NF}' | tr -d \",)

if [[ -z $credentials ]]; then
	$dialogBinary \
	--title \Error \
	--icon \warning \
	--message \ "$message1 " 
	exit 1
else
	echo "API Credentials work, invalidating token"
	responseCode=$(curl -w "%{http_code}" -H "Authorization: Bearer ${credentials}" $jurl/api/v1/auth/invalidate-token -X POST -s -o /dev/null)
	if [[ ${responseCode} == 204 ]]; then
		echo "Token Successfully Invalidated"
	fi
fi

}



function premagic {
	

if [[ $workflow -eq 0 ]] && [[ $passwordtype -eq 0 ]]; then
	promptbeforerun="$dialogBinary \ 
	--title \Final\Parameters \
	--title \Final\ Parameters \
	--icon \info \
	--message \Please\ fill\ in\ the\ Required\ Fields \
    --textfield \Computer\ Group\ ID,regex='^[0-9]',regexerror='This must be a Number',required "
elif [[ $workflow -eq 0 ]] && [[ $passwordtype -eq 1 ]]; then
	promptbeforerun="$dialogBinary \ 
	--title \Final\Parameters \
	--title \Final\ Parameters \
	--icon \info \
	--message \Please\ Fill\ in\ the\ Required\ Fields \
	--textfield \Computer\ Group\ ID,regex='^[0-9]',regexerror='This must be a Number',required \
	--textfield \Recovery\ Lock\ Password,required"
elif [[ $workflow -eq 1 ]] && [[ $passwordtype -eq 0 ]]; then
	promptbeforerun="$dialogBinary \ 
	--title \Final\Parameters \
	--title \Final\ Parameters \
	--icon \info \
	--message \Please\ Fill\ in\ the\ Required\ Fields \
	--textfield \Computer\ Serial\ Numbers,required \
    --helpmessage \"$message3\" "
elif [[ $workflow -eq 1 ]] && [[ $passwordtype -eq 1 ]]; then
	promptbeforerun="$dialogBinary \ 
	--title \Final\Parameters \
	--title \Final\ Parameters \
	--icon \info \
	--message \Please\ Fill\ in\ the\ Required\ Fields \
	--textfield \Computer\ Serial\ Numbers,required \
	--textfield \Recovery\ Lock\ Password,required \
    --helpmessage \"$message3\" "
fi


eval ${promptbeforerun} 2>&1 > $file

rlpass=$(cat $file | grep "Password" | awk '{print $NF}')
smartgroupselection=$(cat $file | grep "Group" | awk '{print $NF}')
serialsearch=$(cat $file | grep "Numbers" | awk '{print $NF}')

if [[ ! -z $rlpass ]]; then 
	rmpass=0
else
	rmpass=1
fi
	
if [[ ! -z $smartgroupselection ]]; then
	prompt=0
fi
	
if [[ ! -z $serialsearch ]]; then
	prompt=2
fi
	
rm -r $file

}	

function magic {
	
#Files for Script to Work
sharedfilepath="/var/tmp/recoverylock"
jsonpath="${sharedfilepath}.json"
csvpath="${sharedfilepath}.csv"
pspath="${sharedfilepath}.py"
	
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

credentials=$(curl -s -X POST "$jurl/api/v1/auth/token" -H "accept: application/json" -H "Authorization: Basic '$userpass64'" | awk  '/token/{print $NF}' | tr -d \",)
setexpire=$(($(date +%s)+1790))
#JSON File Converted to CSV File -- This is what makes this script run 
for pn in ${tp[@]}; do
	jsoninfo=$(curl -X GET -s "$jurl/api/preview/computers?page=$pn&page-size=$recordsperpage&sort=name%3Aasc" -H "accept: application/json" -H "Authorization: Bearer $credentials") 
	echo "$jsoninfo" >> $jsonpath
	python3 "$pspath" >> $csvpath
	rm $jsonpath
done
	
nc=$(cat $csvpath | wc -l)
echo "number of computers returned:$nc"

if [[ $prompt -eq "0" ]]; then

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

piv=$(( 100 / ${#managementid[@]} ))


commandtime="$dialogBinary \
--title \"$title\" \
--message \"$message\" \
--messagealignment \center \
--icon \"$icon\" \
--big \
--centericon \
--progress \
--progresstext \"Sending Recovery Lock Commands\" \
--button1text \"Wait\" \
--button1disabled \
--ontop \
--commandfile \"$commandfile\" "

success=0
fail=0
cpb=0

echo "$commandtime" >> $commandfile
dialogUpdate "progress: 1"

eval ${commandtime[*]} & sleep 0.3

if [[ $rmpass -eq 0 ]]; then

	if [[ -z $rlpass ]]; then
		echo "No Password found"
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
		dialogUpdate "progress: increment ${piv}"
		dialogUpdate "progresstext: Sending command $cpb of $correctserials"
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
		dialogUpdate "progress: increment ${piv}"
		dialogUpdate "progresstext: Sending command $cpb of $correctserials"
		sleep 10
	done
fi


}


function cleanup {
	
	
	rm -r ${sharedfilepath}.csv
	rm -r ${sharedfilepath}.py
	rm -r $commandfile
	
	
}

preflight
start 
premagic
magic 
cleanup 