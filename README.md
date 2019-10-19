# IOF_XML_generator
generate an IOF XML file suitable for upload to Attackpoint

# parseStarts.sh
 Script to download and xml file from winsplits and add punchcards in order to create and IOF XML valid file
Event files are created in a new directory with event name. The xml file will have the event name in that directory with '.xml suffix


Three options are available for populating the punch card list:
  SPL file
  Swedish Eventor
  self created txt file

#usage:
  ./parseStarts eventName winsplitsEventID siCardSource [eventorId] [eventorURL] [extraStartsFile]"

siCardSource can be one of:
  "spl"
  "eventor"
  name of the file to read starts from

the following 2 arguments must be supplied if using eventor
eventorId is only valid when using the eventor option and should be the swedish eventor id of the event
eventorURL defines which countries eventor to download results from. e.g:
  "orienteering.org" from IOF, "orientering.se" (note the single 'e') from Sweden. Default is "orienteering.org"

always optional:
extraStartsFile is optional to add any extra punch cards that may not be present in the start list (e.g. late entries)
  NOTE: MUST BE LONGER THAN 3 CHARACTERS

#examples:
TODO make these examples work - currently only the first one does
   ./parseStarts.sh TestEventSPL 62159 spl
  ./parseStarts.sh TestEventEventorSweden 61234 eventor se 2341
  ./parseStarts.sh TestEventFile 61235 exampleStarts.txt

Documentation for winsplits api
http://obasen.orientering.se/winsplits/api/documentation

#TODO:
Make the examples work
2017-MilaByNight3 had gaffles. Parse and remove controls that weren't common. Almost need an xml parser?
modify the parse ordering to search the start list for names found in Winsplits

#files:
swed_codes:
    HTML codes for various characters that I have come across in start lists. Eventor using HTML codes but Winsplits uses utf8
