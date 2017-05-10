#! /bin/bash
# Documentation for winsplits api
# http://obasen.orientering.se/winsplits/api/documentation

winEventId=$1
eventorId=$2
eventName=$3
extraStarts=$4

if [[ $extraStarts == "" ]]; then
    siCheck=1
else
    siCheck=0
    echo "Will add the following names to the start list and will insert random si numbers for any missing"
    cat $extraStarts
fi

rm -r $eventName
mkdir $eventName
cd $eventName

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
dos2unix startList$eventName

cp $eventName.xml ${eventName}Input.xml

#cp ${eventName}Input.xml ${eventName}.xml


# Extract the names and SI card numbers from an eventor entry list

startFile=startList$eventName
resultFile=$eventName.xml

# http://stackoverflow.com/questions/1251999/how-can-i-replace-a-newline-n-using-sed
grep name $startFile | awk 'BEGIN {FS="<"}; {print $2, ";", $11}' | sed 's/td class="name">//' | sed 's/td class="punchingCard">//' | sed ':a;N;$!ba;s/th class="name">Namn ; \n//g' > forename_surname_si.txt

#../convert.sh

while read code letter; do
    sed -i "s/$code/$letter/g" forename_surname_si.txt
done < ../swed_codes 

cat ../extraStarts >> forename_surname_si.txt

# check for unknown HTML codes
grep "&#" forename_surname_si.txt
if [[ $? == 0 ]]; then
    echo "found unknown HTML codes"
    exit
fi

echo "did convert"

# Create a list of the names present in the  xml result file
grep -n Given $resultFile | sed 's:          <Given>::' | sed 's:</Given>::' | awk 'BEGIN {FS=":"} {print $1}' > LineNos
grep Given $resultFile | sed 's:          <Given>::' | sed 's:</Given>::' > GivNames
grep Family $resultFile | sed 's:          <Family>::' | sed 's:</Family>::' > FamNames
paste -d " " GivNames FamNames > resultNames

fileLen=$(wc -l resultNames | awk '{print $1}')
echo $fileLen
tenPer=$(expr $fileLen / 10 )
echo $tenPer
echo "modifying $fileLen Entries"

lineList=()
while read line; do
    lineList+=($line)
done < LineNos

# Loop over winplits names and give them an si card number
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
    lineNo=${lineList[$i]}
    lineInsert=$(expr $lineNo + $i + 8 )
    sed -i "${lineInsert}i        <ControlCard>$siNoSpace</ControlCard>" $resultFile
    i=$(expr $i + 1 )
    if (( i % tenPer == 0 )); then
        echo "done $i of $fileLen"
    fi 
done < resultNames


cd ..


