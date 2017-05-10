#! /bin/bash

# Read from each line of the HTML codes file and use sed to fix the characters
while read code letter; do
    sed -i "s/$code/$letter/g" forename_surname_si.txt
done < swed_codes 

 
