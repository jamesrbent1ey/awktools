#!/bin/sh

# the following works taking the input 1 char at a time
# may use -N instead of -n to ignore delimeter which is typically a newline
# -N not supported in mac, may not be supported everywhere
# using -d '\0' appears to work for everything - because zero matches zero and is the delimeter
while IFS= read -r -n1 -d '\0' char
do
   #echo "$char\n"
   # the following works formatting char to hex on separate line
   #printf "%.2x\n" "'$char"
   printf "%d\n" "'$char"
   # this was interspersed which likely indicates close: read:errno=0
   # errno may have been on stderr
   # looks like linefeed is reported as 0, can see x0d carrage return followed by x00
done
