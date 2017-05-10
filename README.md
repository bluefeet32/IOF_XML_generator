# IOF_XML_generator
generate an IOF XML file suitable for upload to Attackpoint

usage:
./parseStarts winSplitsEventId eventorEventId name-for-output

Downloads a start list

files:
-swed_codes:
    HTML codes for various characters that I have come across in start lists. Eventor using HTML codes but Winsplits uses utf8
        

TODO:
modify the parse ordering to search the start list for names found in Winsplits
Allow for a start list as in input file or a link to download from
