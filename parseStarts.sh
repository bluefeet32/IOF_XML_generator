#! /bin/bash
# Documentation for winsplits api
# http://obasen.orientering.se/winsplits/api/documentation

eventName=$1
winEventId=$2
siSource=$3

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

if [[ $siSource == "eventor" ]]; then
    if [[ $4 == "" ]]; then
        echo "Usage: ./parseStarts eventName winsplitsEventID eventor eventorId [extraStartsFile]"
        exit
    fi
    eventorId=$4
    extraStarts=$5
    # Extract the names and SI card numbers from an eventor entry list

    startFile=startList$eventName

    # Download the start list with si card numbers from eventor
    echo https://eventor.orientering.se/Events/Entries?eventId=${eventorId}&groupBy=EventClass 
    curl -o $startFile "https://eventor.orientering.se/Events/Entries?eventId=${eventorId}&groupBy=EventClass" &

    wait
    dos2unix $startFile

    # http://stackoverflow.com/questions/1251999/how-can-i-replace-a-newline-n-using-sed
    grep name $startFile | awk 'BEGIN {FS="<"}; {print $2, ";", $11}' | sed 's/td class="name">//' | sed 's/td class="punchingCard">//' | sed ':a;N;$!ba;s/th class="name">Namn ; \n//g' > forename_surname_si.txt

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

while read code letter; do
    sed -i "s/$code/$letter/g" forename_surname_si.txt
done < ../swed_codes 

# Add any extra starts
if [[ $extraStarts != "" ]]; then
    cat ../$extraStarts >> forename_surname_si.txt
fi

# check for unknown HTML codes
grep "&#" forename_surname_si.txt
if [[ $? == 0 ]]; then
    echo "found unknown HTML codes"
    exit
fi

if [[ $extraStarts == "" ]]; then
    echo "Would you like to give all unknown runners random si card numbers?"
    echo "y/n"
    read randomSi < /dev/tty
    if [[ $randomSi == "y" ]]; then
        siCheck=1
    else
        siCheck=0
    fi
else
    siCheck=0
    echo "Will add the following names to the start list and will insert random si numbers for any missing"
    cat $extraStarts
fi

# Download from winsplits an event xml. eventId is specified by the user
# e.g curl http://obasen.orientering.se/winsplits/api/events/{eventId}/resultlist/{format}
curl -o $eventName.xml http://obasen.orientering.se/winsplits/api/events/${winEventId}/resultlist/xml &

#Down;pad for just one class
#classId=2
#curl -o $eventName.xml http://obasen.orientering.se/winsplits/api/events/${winEventId}/classes/${classId}/resultlist/xml &

# Download the start list with si card numbers from eventor
echo https://eventor.orientering.se/Events/Entries?eventId=${eventorId}&groupBy=EventClass 
curl -o startList$eventName "https://eventor.orientering.se/Events/Entries?eventId=${eventorId}&groupBy=EventClass" &

wait
dos2unix $eventName.xml

cp $eventName.xml ${eventName}Input.xml

echo "Creating list of names in results..."
# Create a list of the names present in the  xml result file
grep -n Given $resultFile | sed 's:          <Given>::' | sed 's:</Given>::' | awk 'BEGIN {FS=":"} {print $1}' > LineNos
grep Given $resultFile | sed 's:          <Given>::' | sed 's:</Given>::' > GivNames
grep Family $resultFile | sed 's:          <Family>::' | sed 's:</Family>::' > FamNames
paste -d " " GivNames FamNames > resultNames

# Find the line that the <Result> starts on
firstRes=$(grep -n "<Result>" $resultFile | awk 'BEGIN {FS=":"} {print $1}' | head -n 1)
firstRes=$(expr $firstRes + 1)

fileLen=$(wc -l resultNames | awk '{print $1}')
echo $fileLen
tenPer=$(expr $fileLen / 10 )
echo $tenPer
echo "modifying $fileLen Entries"

lineList=()
while read line; do
    lineList+=($line)
done < LineNos

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
    nameNoSpace="$(echo -e "${fullName}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    grep "$fullName" forename_surname_si.txt > tmp
    if [[ $? == 0 ]]; then
        siNo=$(grep "$fullName" forename_surname_si.txt | awk 'BEGIN {FS=";"} {print $2}' )
    elif [[ $siCheck == 0 ]]; then
        siNo=$(expr $i + 100000000 )
    else 
        echo "$fullName"
        read siNo < /dev/tty
        if [[ $siNo == -1 ]]; then
            siCheck=0
            siNo=$(expr $i + 100000000 )
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

cd ..


