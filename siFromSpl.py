import os
import sys

# Read punch card numbers from an spl file and output them as
# { Course1: { Name1: punchCard1, Name2: punchCard2, ... }
#   Course2: { Name1: punchCard1, ... } ...
# }
# 

#Look for \x45 followed by \x4e 3 chars later when the course is not longer than 50 chars or off the end of the file
def check_is_course( courseLoc, courseLen, data ):
    isRealCourse = False
    if courseLen < 50 and courseLoc + 3 + courseLen < len(data) and data[courseLoc + 3 + courseLen] == 69:
        courseLenAlt = int.from_bytes( data[courseLoc+3+courseLen+1:courseLoc+3+courseLen+3], byteorder='little' )
        if courseLoc + 6 + courseLen < len(data) and data[courseLoc + 6 + courseLen] == 78:
            isRealCourse = True
    return isRealCourse

def si_from_spl( splFile, startFile ):
    endLoc = 0
    num = 0
    with open(splFile, "rb") as binary_file:
        data = binary_file.read()

    file_length = os.path.getsize(splFile)

    startFile = open(startFile, "w+")

    # spl format looks like, in order:
    # \x80 some 4 byte number
    # \x84 4 byte punch card
    # \x87 2 bytes for forename length, then forename of that length
    # \x88 2 bytes for surname length, then surname of that length
    # \x89 some stuff about club, that finishes with \x97 
    # if an field is empty the start byte sequence doesn't appear

    # find the all the courses
    courseLoc = 0
    courseList = []
    courseDict = {}
    coursePrintStr = "loc {}, len {}"
    while courseLoc != -1:
        courseLoc = data.find(b'\x43', courseLoc+1)
        # \x43 is stupidly common so look for the end character which is \x45 and 3 characters later \x4e
        # Alternatively the end char is \x44 in which case the class is repeated usually, so just change where we look
        # We also 
        # FIXME
        # This is far from perfect but fails if the format is not exactly this which it sometime is
        courseLen = int.from_bytes( data[courseLoc+1:courseLoc+3], byteorder='little' )
    #    print( coursePrintStr.format(courseLoc, courseLen) )
        isRealCourse = False

        # If the end char is \x44 then this is the long name. This is usually what the xml also has
        # Need to check on \x45 though, which ends the short name
        if courseLoc + 3 + courseLen < len(data) and data[courseLoc + 3 + courseLen] == 68:
            courseCheckLoc = courseLoc + 3 + courseLen
            courseCheckLen = int.from_bytes( data[courseCheckLoc+1:courseCheckLoc+3], byteorder='little' )
            isRealCourse = check_is_course( courseCheckLoc, courseCheckLen, data )
        else:
            isRealCourse = check_is_course( courseLoc, courseLen, data )
#        if courseLoc + 3 + courseLen < len(data) and data[courseLoc + 3 + courseLen] == 69:
#            courseLenAlt = int.from_bytes( data[courseLoc+3+courseLen+1:courseLoc+3+courseLen+3], byteorder='little' )
#            if courseLoc + 6 + courseLen < len(data) and data[courseLoc + 6 + courseLen] == 78:
#                isRealCourse = True

#            courseLenAlt = and data[courseLoc + 6 + courseLen] == 78 ):
#            if courseLoc + courseLen + courseLenAlt + 9 < len(data) and data[courseLoc + courseLen + courseLenAlt + 9] == 78:
#                isRealCourse = True

        if isRealCourse:
            courseName_binary = data[courseLoc+3:courseLoc + 3 + courseLen] 
            courseName = courseName_binary.decode('cp1252')
        #    print( courseName )
            courseList.append( courseName )
            courseDict[courseName] = courseLoc

    courseList.append( 'EOF' )
    courseDict['EOF'] = len( data )
    courseIdx = 0
    courseName = courseList[courseIdx]
    courseEntry = {}

    startList = {}

    while endLoc != -1:
        # start by finding a forename entry, starting with \x87.
        # for some reason the si card then sometimes starts with \x84 (132), \x81 (129) or \x80 (128).
        #FIXME Need to ensure we are reading the right thing more rigorously
        # Since \x87 is a valid thing in the file check the 5th byte before the one we found
        # marks the start of an si card
        endLoc = data.find(b'\x87', endLoc + 1)

        # increment the course index when we move onto the next course
        if endLoc > courseDict[courseList[courseIdx + 1]]:
            startList[courseName] = courseEntry
            courseEntry = {}
            courseIdx += 1
            courseName = courseList[courseIdx]

        if data[endLoc-5] == 132 or data[endLoc-5] == 129 or data[endLoc-5] == 128:
    #FIXME
    #check on these data transforms being the right length
            si_no = int.from_bytes(data[endLoc-4:endLoc],byteorder='little')
            # Get the length of the first name
            firstStart = endLoc + 3
            firstLen = int.from_bytes(data[firstStart-2:firstStart], byteorder='little')
            # Check the surname follows the firstname to ensure we are where we expect
            if firstStart + firstLen > len( data ):
                continue
            if data[firstStart+firstLen] != 136:
                continue 
            # Then get it. spl uses cp1252 windows encoding
            firstName_binary = data[firstStart:firstStart+firstLen]
            firstName = firstName_binary.decode('cp1252')

            # Same for surname
            surStart = firstStart + firstLen + 3
            surLen = int.from_bytes(data[surStart-2:surStart], byteorder='little')
            surName_binary = data[surStart:surStart+surLen]
            surName = surName_binary.decode('cp1252')

            name = firstName + " " + surName
            courseEntry[name] = str(si_no)
            
            #TODO add club and course to improve uniqueness matching

            startToWrite = courseName + ";" + name + ";" + str(si_no) + "\n"
            startFile.write( startToWrite )
        num = num + 1
        
    startList[courseName] = courseEntry
    startFile.close()
    return startList


if __name__=='__main__':
    splFile = sys.argv[1]
    startFile = sys.argv[2]
    startList = si_from_spl( splFile, startFile )
    print( startList )
