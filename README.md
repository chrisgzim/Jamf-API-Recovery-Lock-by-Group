# Jamf-API-Recovery-Lock-by-Group

This is a script I made to make things easier for admins to send Recovery Lock Commands to their endpoints. (Had they forgotten to set the setting in their Prestage.) It also serves as an option if admins want to rotate their Recovery Lock Passwords as well! 

Put in some credentials (API Role or Standard Account), your URL, and how you want to input your computers! (I prefer the static or smart group option myself.) The script will then get a list of machines and start pushing out the API command to set the Recovery Lock Password.

Currently the Recovery Lock API call does not have a way to set randomized passwords (this can only be done through pre-stage enrollment. However, this script can create randomized passwords -- if you so choose. The password will be randomized for each computer.) 


## UPDATE 9-5-23

Created a new script for this workflow that leverages SwiftDialog. To use this newer workflow, check out [swiftDialog Recovery Lock](https://github.com/chrisgzim/Jamf-API-Recovery-Lock-by-Group/blob/main/swiftdialog_jproapilock.sh). 

I thought it was time to give this a makeover so the workflow would look a little more modern and would help streamline the experience. (There were a ton of prompts with the AppleScript method.) 

Here are some screenshots of the swiftDialog workflow: 

![Screenshot 2023-09-05 at 12 10 13 PM](https://github.com/chrisgzim/Jamf-API-Recovery-Lock-by-Group/assets/101137859/2c9d3b47-9da5-4920-95f4-1aad39b2dd51)

![Screenshot 2023-09-05 at 12 11 15 PM](https://github.com/chrisgzim/Jamf-API-Recovery-Lock-by-Group/assets/101137859/4b154fc7-358d-4a7d-9363-fe3c4ea4f0e7)
