# Jamf-API-Recovery-Lock-by-Group

This script does use Python in order to work. As it parses information from a JSON file and dumps it to a CSV. 

This is a script I made to try a couple of new things. The goal is to leverage the API to pull the serial number and management id from the inventory record of all computers. 

The information is set up as a CSV document that will go ahead and search by serials to find the corresponding management id. You can also pull a smart group by entering the Smart Group Id. All of the serial numbers from that group will automatically be searched for in the CSV document and then will put whatever recovery lock password you would like for that group of machines. 

Currently the Recovery Lock API call does not have a way to set randomized passwords (this can only be done through pre-stage enrollment. 
