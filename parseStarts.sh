#! /bin/bash
# 
# Script to download and xml file from winsplits and add punchcards in order to create and IOF XML valid file
#
# Three options are available for populating the punch card list:
#   SPL file
#   Swedish Eventor
#   self created txt file
#
# usage:
#   ./parseStarts eventName winsplitsEventID siCardSource [eventorId] [eventorURL] [extraStartsFile]"
#
# siCardSource can be one of:
#   "spl"
#   "eventor"
#   name of the file to read starts from
#
# the following 2 arguments must be supplied if using eventor
# eventorId is only valid when using the eventor option and should be the swedish eventor id of the event
# eventorURL defines which countries eventor to download results from. e.g:
#   "orienteering.org" from IOF, "orientering.se" (note the single 'e') from Sweden. Default is "orienteering.org"
#
# always optional:
# extraStartsFile is optional to add any extra punch cards that may not be present in the start list (e.g. late entries)
#   NOTE: MUST BE LONGER THAN 3 CHARACTERS
#
# examples:
#TODO make these examples work
#   ./parseStarts TestEventSPL 61233 spl"
#   ./parseStarts TestEventEventorSweden 61234 eventor se 2341"
#   ./parseStarts TestEventFile 61235 exampleStarts.txt
#
# Documentation for winsplits api
# http://obasen.orientering.se/winsplits/api/documentation

# TODO MilaByNight3 had gaffles. Parse and remove controls that weren't common. Almost need an xml parser?

eventName=$1
winEventId=$2
siSource=$3

#can use winsplits to get the si card numbers by downloading the spl file, e.g.:
#curl -o colonial.spl http://obasen.orientering.se/winsplits/wsp4/downloadEvent.php?databaseId=61334
#this has the si card delimited by 

#FIXME what is or?
if [[ $1 == "" ]]; then
    echo "Usage: ./parseStarts eventName winsplitsEventID siCardSource [eventorId] [extraStartsFile]"
    exit
elif [[ $2 == "" ]]; then
    echo "Usage: ./parseStarts eventName winsplitsEventID siCardSource [eventorId] [extraStartsFile]"
    exit
elif [[ $3 == "" ]]; then
    echo "Usage: ./parseStarts eventName winsplitsEventID siCardSource [eventorId] [extraStartsFile]"
    exit
fi

rm -r $eventName
mkdir $eventName
cd $eventName
resultFile=$eventName.xml

if [[ $siSource == "spl" ]]; then
    # Download the spl file
    curl -o $eventName.spl http://obasen.orientering.se/winsplits/wsp4/downloadEvent.php?databaseId=${winEventId}
#    python3 ../siFromSpl.py $eventName.spl forename_surname_si.txt

else
    if [[ $siSource == "eventor" ]]; then
        if [[ $4 == "" ]]; then
            echo "Usage: ./parseStarts eventName winsplitsEventID eventor eventorId [extraStartsFile]"
            exit
        fi

        eventorId=$4
        if [[ $5 == "" ]]; then
            eventorURL="orienteering.org"
        else
            eventorURL=$5
            extraStarts=$6
        fi

        # Extract the names and SI card numbers from an eventor entry list

        startFile=startList$eventName
        echo $eventorURL

        # Create download url
        url="https://eventor.$eventorURL/Events/Entries?eventId=${eventorId}&groupBy=EventClass"
        # Download the start list with si card numbers from eventor
        echo "url: "
        echo $url
        curl -o $startFile $url &

        # SOFT eventor
        #echo https://eventor.orientering.se/Events/Entries?eventId=${eventorId}&groupBy=EventClass 
    #    curl -o $startFile "https://eventor.orientering.se/Events/Entries?eventId=${eventorId}&groupBy=EventClass" &
        #TODO be able to accept startlist files which have a different ordering
        #curl -o $startFile "https://eventor.orientering.se/Events/StartList?eventId=${eventorId}&groupBy=EventClass" &
        #IOF eventor
    #    curl -o $startFile "https://eventor.orientering.org/Events/Entries?eventId=${eventorId}&groupBy=EventClass" &
    #    curl -o $startFile  "https://eventor.orienteering.org/Events/StartList?eventId=5741&groupBy=EventClass" &

        wait
        dos2unix $startFile

        # When eventor check that this actually contains the start list and is not just a lot of links to the classes
        grep punchingCard $startFile > tmp
        if [[ $? != 0 ]]; then
            # if we found didn't find any punching cards we need to loop over the classes
            # find the first class
    #        grep eventClassID $startFile | strip out the first and last number > firstClID, lastClID 
            classList=$(grep eventClassId $startFile | sed 's/| /\n/g' | awk 'BEGIN {FS="="}; {print $4}' | awk 'BEGIN {FS=">"}; {print $1}' | sed 's/"//')
            echo $classList
            for clID in $classList; do
                curl -o ${clID}StartFile "https://eventor.orientering.se/Events/Entries?eventId=${eventorId}&eventClassId=${clID}" &
    #            # parse 
            done
            wait
            cat *StartFile > startFile
            rm *StartFile
            mv startFile $startFile
        fi
        rm tmp

        # http://stackoverflow.com/questions/1251999/how-can-i-replace-a-newline-n-using-sed
        grep name $startFile | awk 'BEGIN {FS="<"}; {print $2, ";", $11}' | sed 's/td class="name">//' | sed 's/td class="punchingCard">//' | sed ':a;N;$!ba;s/th class="name">Namn ; \n//g' > forename_surname_si.txt
        #TODO be able to accept startlist files which have a different ordering
        #grep name $startFile | awk 'BEGIN {FS="<"}; {print $7, ";", $}' | sed 's/td class="name">//' | sed 's/td class="punchingCard">//' | sed ':a;N;$!ba;s/th class="name">Namn ; \n//g' > forename_surname_si.txt

        #../convert.sh
    else
        eventorId=-1
        extraStarts=$4
        echo "Expecting the input file $siSource to contain a list of runners and their SI numbers to be used."
        #FIXME this should work as long as the seperator is not ";"
        echo "Does this file contain an seperators other than tabs or spaces, e.g. \",\". \";\" will not work."
        echo "y/n"
        read resp < /dev/tty
        if [[ $resp == "y" ]]; then
            echo "Please type the seperator to be used:"
            read sep < /dev/tty
        else
            sep=" ";
        fi
        echo "Please input the column number containing the numbers you would like to use as SI cards."
        echo "If these are not si cards it is recommended a note is put on Attackpoint explaing how to claim the splits."
        echo "This is only supported if the number is before the entries with spaces eg names with no seperator, or the last. For the last enter NF."

        awk -F "$sep" '{for (i=1; i <= NF; i++ ) print i, $i; exit 0}' ../$siSource
        read siCol < /dev/tty

        awk -v col=$siCol '{print $col}' ../$siSource > siNums
        paste -d ";" ../$siSource siNums > forename_surname_si.txt

        rm siNums
    fi

    # Add any extra starts
    if [[ $extraStarts != "" ]]; then
        cat ../$extraStarts >> forename_surname_si.txt
    fi

    while read code letter; do
        sed -i "s/$code/$letter/g" forename_surname_si.txt
    done < ../swed_codes 

    if [[ $extraStarts == "" ]]; then
        echo "Would you like to give all unknown runners random si card numbers?"
        echo "y/n"
        read randomSi < /dev/tty
        if [[ $randomSi == "y" ]]; then
            siCheck=0
        else
            siCheck=1
        fi
    else
        siCheck=0
        echo "Will add the following names to the start list and will insert random si numbers for any missing"
        cat $extraStarts
    fi

    # check for unknown HTML codes
    grep "&#" forename_surname_si.txt
    if [[ $? == 0 ]]; then
        echo "found unknown HTML codes"
        exit
    fi
fi




# Download from winsplits an event xml. eventId is specified by the user
# e.g curl http://obasen.orientering.se/winsplits/api/events/{eventId}/resultlist/{format}
curl -o $eventName.xml http://obasen.orientering.se/winsplits/api/events/${winEventId}/resultlist/xml &

#Download for just one class
#classId=2
#curl -o $eventName.xml http://obasen.orientering.se/winsplits/api/events/${winEventId}/classes/${classId}/resultlist/xml &

# Download the start list with si card numbers from eventor
#echo https://eventor.orientering.se/Events/Entries?eventId=${eventorId}&groupBy=EventClass
#curl -o startList$eventName "https://eventor.orientering.se/Events/Entries?eventId=${eventorId}&groupBy=EventClass" &

wait
dos2unix $eventName.xml

cp $eventName.xml ${eventName}Input.xml

#TODO check on these ampersands
#while read code letter; do
#    sed -i 's/amp;//g' $eventName.xml
#done < ../swed_codes 

#
if [[ $siSource == "spl" ]]; then
    rm ${eventName}.xml
    python3 ../addPunchXML.py ${eventName}.spl ${eventName}Input.xml ${eventName}.xml
else
    #TODO replace all of the below with python
    echo "Creating list of names in results..."
    # Create a list of the names present in the  xml result file
    grep -n Given $resultFile | sed 's:          <Given>::' | sed 's:</Given>::' | awk 'BEGIN {FS=":"} {print $1}' > LineNos
    grep Given $resultFile | sed 's:          <Given>::' | sed 's:</Given>::' > GivNames
    grep Family $resultFile | sed 's:          <Family>::' | sed 's:</Family>::' > FamNames
    givLen=$(wc -l GivNames | awk '{print $1}')
    famLen=$(wc -l FamNames | awk '{print $1}')

    lineList=()
    while read line; do
        lineList+=($line)
    done < LineNos

    if [[ $givLen != $famLen ]]; then
        echo "Missing family ($famLen) or given names ($givLen)"

        addedLines=0
        fileEnd=$(expr $givLen - 1)
        for i in $(seq 0 $fileEnd); do
            lineNo=${lineList[$i]}
            lineInsert=$(expr $lineNo - 1 + $addedLines)
            cat $resultFile | head -n $lineInsert | tail -n 1 | grep "<Family>"
            if [[ $? != 0 ]]; then
                lineInsert=$(expr $lineNo + $addedLines)
                sed -i "${lineInsert}i\\
              <Family></Family>" $resultFile
                addedLines=$(expr $addedLines + 1)
            fi
        done

        grep -n Given $resultFile | sed 's:          <Given>::' | sed 's:</Given>::' | awk 'BEGIN {FS=":"} {print $1}' > LineNos
        grep Given $resultFile | sed 's:          <Given>::' | sed 's:</Given>::' > GivNames
        grep Family $resultFile | sed 's:          <Family>::' | sed 's:</Family>::' > FamNames
        givLen=$(wc -l GivNames | awk '{print $1}')
        famLen=$(wc -l FamNames | awk '{print $1}')
        if [[ $givLen != $famLen ]]; then
            echo "Missing family ($famLen) or given names ($givLen)"
            exit
        fi
    fi
    paste -d " " GivNames FamNames > resultNames

    # Find the line that the <Result> starts on
    firstRes=$(grep -n "<Result>" $resultFile | awk 'BEGIN {FS=":"} {print $1}' | head -n 1)
    firstRes=$(expr $firstRes + 1)

    fileLen=$(wc -l resultNames | awk '{print $1}')
    echo $fileLen
    tenPer=$(expr $fileLen / 10 )
    echo $tenPer
    echo "modifying $fileLen Entries"

    echo "line ${lineList[0]}"
    echo "first $firstRes"
    resultDisp=$(expr $firstRes - ${lineList[0]})
    echo $resultDisp

    # Loop over winplits names and give them an si card number
    echo "Adding si card numbers..."
    i=0
    if [[ $siCheck == 1 ]]; then
        echo "Please enter si card for the not found names as they appear. Enter -1 if you would like to auto generate from now on:"
    fi
    while read fullName; do
    #    nameNoSpace="$(echo -e "${fullName}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        #FIXME What if matching names?
        # should use eventor unique id
        grep "$fullName" forename_surname_si.txt > tmp
        success=$?
        found=$(grep "$fullName" forename_surname_si.txt | wc -l)
        if [[ $found > 1 ]]; then
            echo "found multiple entries for $fullName:"
            cat tmp
            echo "type the row number you would like to use this time, with 1 being the first or 0 to enter manually"
            read rowNo < /dev/tty
            if [[ $rowNo == 0 ]]; then
                echo "enter the SI number"
                read siNo < /dev/tty
            else
                siNo=$(head -n $rowNo tmp | tail -n 1 | awk 'BEGIN {FS=";"} {print $2}' )
            fi
        elif [[ $success == 0 ]]; then
            siNo=$(grep "$fullName" forename_surname_si.txt | awk 'BEGIN {FS=";"} {print $2}' )
        elif [[ $siCheck == 0 ]]; then
            siNo=$(expr $i + 100000000 )
        else
            echo $fullName
            read siNo < /dev/tty
            if [[ $siNo == -1 ]]; then
                siCheck=0
                siNo=$(expr $i + 100000000 )
            fi
        fi
        # Deal with blank si numbers in start list by giving random
        if [[ $siNo == " " ]]; then
            if [[ $siCheck == 0 ]]; then
                siNo=$(expr $i + 100000000 )
            else
                read siNo < /dev/tty
                if [[ $siNo == -1 ]]; then
                    siCheck=0
                    siNo=$(expr $i + 100000000 )
                fi
            fi
        fi
        siNoSpace="$(echo -e "${siNo}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        lineNo=$(expr ${lineList[$i]} + $i)
        lineInsert=$(expr $lineNo + $resultDisp)
        sed -i "${lineInsert}i        <ControlCard>$siNoSpace</ControlCard>" $resultFile
        i=$(expr $i + 1 )
        if (( i % tenPer == 0 )); then
            echo "done $i of $fileLen"
        fi 
    done < resultNames

    #Remove tmp files
    rm -rf sed* tmp
    cd ..
fi


