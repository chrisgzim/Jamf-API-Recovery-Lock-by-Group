# Jamf-API-Recovery-Lock-by-Group

This script does use Python in order to work as it parses information from a JSON file and dumps it to a CSV. 

This is a script I made to try a couple of new things. The goal is to leverage the API to pull the serial number and management id from the inventory record of all computers. 

The information is set up as a CSV document that will go ahead and search by serials to find the corresponding management id. You can also pull a smart group by entering the Smart Group Id. All of the serial numbers from that group will automatically be searched for in the CSV document and then will put whatever recovery lock password you would like for that group of machines. 

Currently the Recovery Lock API call does not have a way to set randomized passwords (this can only be done through pre-stage enrollment. However, this script can create randomized passwords -- if you so choose. The password will be randomized for each computer that is sent the recovery lock password command. 


## UPDATE 9-5-23

Created a new script for this workflow that leverages SwiftDialog. To use this newer workflow, check out [swiftDialog Recovery Lock](https://github.com/chrisgzim/Jamf-API-Recovery-Lock-by-Group/blob/main/swiftdialog_jproapilock.sh). 

I thought it was time to give this a makeover so the workflow would look a little more modern and would help streamline the experience. (There were a ton of prompts with the AppleScript method.) 

Here are some screenshots of the swiftDialog workflow: 

![Screenshot 2023-09-05 at 12 10 13 PM](https://github.com/chrisgzim/Jamf-API-Recovery-Lock-by-Group/assets/101137859/2c9d3b47-9da5-4920-95f4-1aad39b2dd51)

![Screenshot 2023-09-05 at 12 11 15 PM](https://github.com/chrisgzim/Jamf-API-Recovery-Lock-by-Group/assets/101137859/4b154fc7-358d-4a7d-9363-fe3c4ea4f0e7)
