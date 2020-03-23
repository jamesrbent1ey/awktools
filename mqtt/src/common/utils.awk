################## utility #######################
function executeCommand(cmd,		result, lines) {
	lines = ""
	while( ( cmd | getline result ) > 0 ) {
		gsub(/\n/,"",result)
		gsub(/\r/,"",result)
		lines = lines result "\n"
	}
		
	#close command
	close(cmd)
	
	return lines
}
# Bitwise AND between 2 variables - var AND x
function and64(var, x,   l_res, l_i)
{
	l_res=0;
	
	for (l_i=0; l_i < 8; l_i++){
	        if (var%2 == 1 && x%2 == 1) l_res=l_res/2 + 128;
	        else l_res/=2;
	        var=int(var/2);
	        x=int(x/2);
	}
	return l_res;
}
# Rotate var left x times
function lshift64(var, x)
{
	while(x > 0){
	    var*=2;
	    x--;
	}
	return var;
}
# Rotate var right x times
function rshift64(var, x)
{
	while(x > 0){
	    var=int(var/2);
	    x--;
	}
	return var;
}
function dumpHex(arr,   i) {
   for( i = 1; i <= length(arr); i++) {
       printf("0x%.2x", arr[i])
       if(i+1 <= length(arr)) {
          printf(",")
       }
   } 
   print
}
# after much experimentation, the best approach
# appears to be to send the decimal equivalent string
# into this app, in the background.
# send an array of characters over the connection
# arr - array to send
# bkgnd - if true then asynch non-block, else blocking
function sendHex(arr, bkgnd,  i,s) {
   s = ""
   for( i = 1; i <= length(arr); i++) {
       if(i == 1)
          s = sprintf("%s%d",s,arr[i])
       else
          s = sprintf("%s.%d",s,arr[i])
   }
   if(bkgnd) {
      system("./mqtt.awk send "s" &")
   } else {
      system("./mqtt.awk send "s)
   }
}
# convert utf8 string to integer array
function strToIntArray(s,a,offset,  a2,i) {
   delete a2
   split(s,a2,"")
   for(i = 0; i < length(a2); i++) {
      a[offset+i] = MQTT_CHAR_TO_INT[a2[i+1]]
   }
}
# convert integer array to utf8 string
function intArrayToStr(a, pos, len,   s, i) {
   s = ""
   for( i = 1; i <= len; i++) {
       s = sprintf("%s%c",s,a[i+(pos-1)])
   }
   return s
}
# check for file existence
function fileExists(filename,   s) {
   s = "du "filename
   s = executeCommand(s)
   gsub(/\n/,"",s)
   if( length(s) <= 1 || index(s,"o such") > 0) {
      return 1==0
   }
   return 1==1
}
# encode a length value per spec
function mqttEncodeMBI(number, output,   numBytes, digit) {
    numBytes = 1
	do {
		digit = number % 128
		number = rshift64(number, 7)
		if (number > 0) {
			digit = or(digit,128)
		}
		output[numBytes++] = digit;
	} while ( (number > 0) && (numBytes<=4) )

    # can't return arrays but it should be populated
	#return output
}
# add src array to dst array
# src source array
# srcpos position in src to start copy from
# dst destination array
# dstpos position in dst to copy into
# cnt number of bytes to copy
function mqttAddArray(src, srcpos, dst, dstpos, cnt,    i,j) {
   j=dstpos
   for(i=srcpos; i<=(srcpos+cnt); i++) {
      dst[j] = src[i]
      j = j + 1
   }
}
# write a 16bit value into the given array MSB
# val integer to write
# dst array to write into, 2 bytes will be written
# dstpos position in dst to write the 2 bytes into
function mqttWriteUint16 (val, dst, dstpos) {
   dst[dstpos++] = and64(rshift64(val,8),255)
   dst[dstpos++] = and64(val,255)
   return dstpos
}
# read a 16bit integer from the given array
# src array to read bytes from, must be at least 2 bytes long
# srcpos position in src to read from
function mqttReadUint16 (src, srcpos    ) {
   return lshift(src[srcpos],8) + src[srcpos+1]
}
#
