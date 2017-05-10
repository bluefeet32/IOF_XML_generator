# Documentation for winsplits api
# http://obasen.orientering.se/winsplits/api/documentation

winEventId=$1
eventorId=$2
eventName=$3

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

# check for unknown HTML codes
grep "&#" forename_surname_si.txt
if [[ $? == 0 ]]; then
    echo "found unknown HTML codes"
    exit
fi


echo "did convert"

awk 'BEGIN {FS=";"} {print $1}' forename_surname_si.txt > tmp
awk '{print $1 ";"}' tmp > tmpF
awk '{print $2, $3 ";"}' tmp > tmpS
awk 'BEGIN {FS=";"}; {print $2}' forename_surname_si.txt > tmpSi
paste tmpF tmpS tmpSi > forename_surname_si.txt
rm tmp tmpF tmpS tmpSi

fileLen=$(wc -l forename_surname_si.txt)
echo "modifying $fileLen Entries"
i=0

IFS=";"
while read fore sur si; do
#    echo "$fore/ $sur/ $si"
    #grep $fore $resultFile
#    echo $fore
    lineList=$(grep -n $fore $resultFile | awk 'BEGIN{ FS=":" }; {print $1}')
    if [[ $lineList != "" ]]; then
        #echo $lineList
        #for lineNo in $lineList; do
        while read -r lineNo; do
#            echo $lineNo
            surNoSpace="$(echo -e "${sur}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
#            echo $surNoSpace
            res=$(head -n $lineNo $resultFile | tail -n 2 | grep $surNoSpace)
            if [[ $? == 0 ]]; then
#                echo $fore $surNoSpace $lineNo
                lineInsert=$(expr $lineNo + 8 )
                siNoSpace="$(echo -e "${si}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
                #echo $lineInsert
                # This puts ^M at the end of every line for some reason
                sed -i "${lineInsert}i        <ControlCard>$siNoSpace</ControlCard>" $resultFile
#                
#                echo "        <ControlCard>$si</ControlCard>"
                continue
            fi
        #done
        done <<< "$lineList"
        #if [[ $? == 0 ]]; then
        #    echo $fore $sur
        #fi
    fi
    i=$(expr $i + 1)
    if (( i % 100 == 0 )); then
        echo "done $i of $fileLen"
    fi 
done < forename_surname_si.txt 
IFS=$OIFS

cd ..
#sed -e "s/\^M//" $resultFile > new$resultFile

#head -n $(grep -n Ruairi UppsalaMoteLangO8.xml | awk 'BEGIN{ FS=":" }; {print $1}') UppsalaMoteLangO8.xml | tail -n 2 | grep check


