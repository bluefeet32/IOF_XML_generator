import os
import sys

endLoc = 0
num = 0
with open(sys.argv[1], "rb") as binary_file:
    data = binary_file.read()

file_length = os.path.getsize(sys.argv[1])

startFile = open(sys.argv[2], "w+")

# spl format looks like, in order:
# \x80 some 4 byte number
# \x84 4 byte punch card
# \x87 2 bytes for forename length, then forename of that length
# \x88 2 bytes for surname length, then surname of that length
# \x89 some stuff about club, that finishes with \x97 
# if an field is empty the start byte sequence doesn't appear

while endLoc != -1:
    # start by finding a forename entry, starting with \x87.
    # for some reason the si card then sometimes starts with \x84 (132) or \x80 (128).
    # Since \x87 is a valid thing in the file check the 5th byte before the one we found
    # marks the start of an si card
    endLoc = data.find(b'\x87', endLoc + 1)
    if data[endLoc-5] == 132 or data[endLoc-5] == 128:
        si_no = int.from_bytes(data[endLoc-4:endLoc],byteorder='little')
        # Get the length of the first name
        firstStart = endLoc + 3
        firstLen = int.from_bytes(data[firstStart-2:firstStart-1], byteorder='little')
        # Then get it. spl uses cp1252 windows encoding
        firstName_binary = data[firstStart:firstStart+firstLen]
        firstName = firstName_binary.decode('cp1252')

        # Same for surname
        surStart = firstStart + firstLen + 3
        surLen = int.from_bytes(data[surStart-2:surStart-1], byteorder='little')
        surName_binary = data[surStart:surStart+surLen]
        surName = surName_binary.decode('cp1252')
        
        #TODO add club and course to improve uniqueness matching

        startToWrite = firstName + " " + surName + ";" + str(si_no) + "\n"
        startFile.write( startToWrite )
    num = num + 1
    
startFile.close()
