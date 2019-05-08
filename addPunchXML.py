import sys
import xml.etree.ElementTree as ET
import siFromSpl

def addControlCardToXML( splFile, inXMLFile, outXMLFile ):
    # Register the iof xml namespace to avoid ns0: in output
    ET.register_namespace('',"http://www.orienteering.org/datastandard/3.0")
    tree = ET.parse( inXMLFile )
    root = tree.getroot()

    #print( root.tag )
    #print( root.tag )

    #Loop over event and class results
    #for child in root:
    #    print (child.tag, child.attrib)
    #    print( child[0] )
    #    # Print the event ID
    #    if child.tag == '{http://www.orienteering.org/datastandard/3.0}Event':
    #        print( child[0].text )

    # setup namespaces to make typing easier and prettier
    ns = {'iof': 'http://www.orienteering.org/datastandard/3.0'}

    # Print the event ID
    event = root.find('iof:Event', ns)
    eventId = event.find('iof:Id', ns).text
    eventName = event.find('iof:Name', ns).text
    eventDate = event.find('iof:StartTime', ns).find('iof:Date', ns).text
    print( "Adding control cards for ", eventName, " on ", eventDate, ", winsplitsID: ", eventId )


    if "spl" in splFile:
        # Read the spl file to get the startlist has the format
        # {'courseName1':{'name1':'controlCard1','name2':controlCard2,... 
        #  'courseName2':{'name1':'controlCard1',... } 
        # }
        # This allows us to get the controlCard easily once we have a name and a course
        startList = siFromSpl.si_from_spl( splFile, 'forename_surname_si.txt' )
    else:
        #FIXME this doesn't actually work
        print("Non SPL files are not supported in the python xml population")
        exit()
        startList = readStarts.readStarts( splFile, 'forename_surname_si.txt' )

    # Loop over the courses in the startList first
    for course in startList:
        courseXml = ''
        # Find that course in the xml
        courseResults = root.findall( 'iof:ClassResult', ns )
        for courseSearch in courseResults:
            courseName = courseSearch.find( 'iof:Class', ns ).find( 'iof:Name', ns ).text
            if courseName == course:
                courseXml = courseSearch
                break
        # Next get a list of all the competitors from the xml file
        # We will add control cards using the startList data
        personResults = courseXml.findall( 'iof:PersonResult', ns )
        for personResult in personResults:
            # The actual name is slightly buried in a <PersonResult> under
            # <Person>
            #   <Name>
            #       <Family></Family>
            #       <Given></Given>
            #   </Name>
            # </Person>
            person = personResult.find( 'iof:Person', ns )
            family = person.find('iof:Name', ns).find('iof:Family', ns)
            given = person.find('iof:Name', ns).find('iof:Given', ns)
            familyName = ''
            givenName = ''
            if  family != None:
                familyName = family.text
            if given != None:
                givenName = given.text
            name = givenName + ' ' + familyName
            # The control card belongs in the <Result> part of a <PersonResult>
            result = personResult.find( 'iof:Result', ns )
            # Need to create a controlCard element to add it to the xml
            controlCard = ET.Element('{http://www.orienteering.org/datastandard/3.0}ControlCard')
            controlCard.text = startList[course][name]
            # Insert the controlCard as the first element in <Result>
            result.insert( 0, controlCard ) 
        

    # Write output to specified file without 'ns0:' prefixed everywhere
    tree.write( outXMLFile, xml_declaration = True, encoding = 'utf-8', method = 'xml' )
    
if __name__=='__main__':
    splFile = sys.argv[1]
    inXMLFile = sys.argv[2]
    outXMLFile = sys.argv[3]
    addControlCardToXML( splFile, inXMLFile, outXMLFile )
