# awktools - MQTT
MQTT (MQ Telemetry Transport) AWK implementation

to build:  
1) change to the src directory
2) execute './build <appname.awk>'

output will be stored in the output directory

chrdr.sh is a utility used by the mqtt script to capture data in a consumable form.

Modify MQTT files to call your awk implementations for:
 - connect acknowledgement
 - subscribe acknowledgement
 - publish messages
 - any other message you wish to handle.
 
 Feel free to extend this system with your code to enable your solution. The build script simply concatenates awk files (.awk) together to produce a single awk script. This is sometimes better for deployment. You can enable other forms of integration
 s