#!/usr/bin/awk -f

#reserved    = gen-delims / sub-delims
#      gen-delims  = ":" / "/" / "?" / "#" / "[" / "]" / "@"
#      sub-delims  = "!" / "$" / "&" / "'" / "(" / ")"
#                  / "*" / "+" / "," / ";" / "="
function encodeURI(val) {
   gsub(/\:/,"%3A",val)
   gsub(/\//,"%5C",val)
   gsub(/\?/,"%3F",val)
   gsub(/\#/,"%23",val)
   gsub(/\[/,"%5B",val)
   gsub(/\]/,"%5D",val)
   gsub(/\@/,"%40",val)
   gsub(/\!/,"%21",val)
   gsub(/\$/,"%24",val)
   gsub(/\&/,"%26",val)
   gsub(/'/,"%27",val)
   gsub(/\(/,"%28",val)
   gsub(/\)/,"%29",val)
   gsub(/\*/,"%2A",val)
   gsub(/\+/,"%2B",val)
   gsub(/\,/,"%2C",val)
   gsub(/\;/,"%3B",val)
   gsub(/\=/,"%3D",val)
   return val
}
function decodeURI(val) {
   gsub(/\%3A/,":",val)
   gsub(/\%5C/,"/",val)
   gsub(/\%3F/,"?",val)
   gsub(/\%23/,"#",val)
   gsub(/\%5B/,"[",val)
   gsub(/\%5D/,"]",val)
   gsub(/\%40/,"@",val)
   gsub(/\%21/,"!",val)
   gsub(/\%24/,"$",val)
   gsub(/\%26/,"&",val)
   gsub(/\%27/,"'",val)
   gsub(/\%28/,"(",val)
   gsub(/\%29/,")",val)
   gsub(/\%2A/,"*",val)
   gsub(/\%2B/,"+",val)
   gsub(/\%2C/,",",val)
   gsub(/\%3B/,";",val)
   gsub(/\%3D/,"=",val)
	return val
}

function processCommandLine(   i,p,u) {
    p = ""
    u = ""
    for(i = 0; i < ARGC; i++) {
        if(index(ARGV[i],"encode") > 0) {
        	return encodeURI(ARGV[i+1])
        }
        if(index(ARGV[i],"decode") > 0) {
           return decodeURI(ARGV[i+1])
        }
    }
    return "usage = urlencode [encode|decode] data"
}
BEGIN {
    print processCommandLine()
    exit 0
}
