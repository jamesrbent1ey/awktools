#!/usr/bin/awk -f

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

# Rotate bytevalue left x times
function lshift64(var, x)
{
	while(x > 0){
	    var*=2;
	    x--;
	}
	return var;
}

# Rotate bytevalue right x times
function rshift64(var, x)
{
	while(x > 0){
	    var=int(var/2);
	    x--;
	}
	return var;
}
function b64_buildTables(   i) {
	if(length(B64_TABLE)==0) {
		delete B64_TABLE
		split("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",B64_TABLE,"")
	}
	if(length(B64_C_TO_I) == 0) {
	    delete B64_C_TO_I
		for(i=0; i<256; i++) {
			B64_C_TO_I[sprintf("%c",i)] = i
		}
	}
	if(length(B64_I_TO_C) == 0) {
	    delete B64_I_TO_C
		for(i=0; i<256; i++){
			B64_I_TO_C[i] = sprintf("%c",i)
		}
	}
}
function Base64_encode(toencode,   data, buffer, pad, i, j, i1, i2, i3, i4) {
    b64_buildTables()
    delete data
    split(toencode,data,"")
    buffer=""
    pad = 6 - (length(data) % 6)
    for(i=1; i <= length(data); i+=3) {
        i1 = rshift64(B64_C_TO_I[data[i]],2)
        i1 = i1 + 1 #because the table is from 1..n not 0..n
        buffer = buffer""B64_TABLE[i1]
    	if( i+1 <= length(data)) {
           i2 = lshift64(and64(B64_C_TO_I[data[i]], 3),4)
           i2 = i2 + rshift64(B64_C_TO_I[data[i+1]],4)
           i2 = i2 + 1
           buffer = buffer""B64_TABLE[i2]
    	} else {
           i2 = lshift64(and64(B64_C_TO_I[data[i]], 3),4)
           i2 = i2 + 1
           buffer = buffer""B64_TABLE[i2]
	    }
	    if(i+2 <= length(data)) {
           i3 = and64(B64_C_TO_I[data[i+1]],15)
           i3 = lshift64(i3, 2)
           i3 = i3 + rshift64(B64_C_TO_I[data[i+2]],6)
           i3 = i3 + 1
           buffer = buffer""B64_TABLE[i3]
           i4 = and64(B64_C_TO_I[data[i+2]], 63)
           i4 = i4 + 1
           buffer = buffer""B64_TABLE[i4]
	    } else {
           i3 = and64(B64_C_TO_I[data[i+1]],15)
           i3 = lshift64(i3, 2)
           i3 = i3 + 1
           buffer = buffer""B64_TABLE[i3]
           i4 = 0
           buffer = buffer""B64_TABLE[i4]
           # TODO appear to have login problems when we hit this point
	    }
    }
    for(j=0; j < pad; j++) {
       buffer = buffer"="
    }
    return buffer
}

function Base64_decode(todecode   ){
   return "not implemented"
}

function processCommandLine(   i,p,u) {
    p = ""
    u = ""
    for(i = 0; i < ARGC; i++) {
        if(index(ARGV[i],"encode") > 0) {
        	return Base64_encode(ARGV[i+1])
        }
        if(index(ARGV[i],"decode") > 0) {
           return Base64_decode(ARGV[i+1])
        }
    }
    return "usage = base64 [encode|decode] data"
}
BEGIN {
    delete B64_C_TO_I
    delete B64_I_TO_C
    delete B64_TABLE
    
    print processCommandLine()
    exit 0
}
