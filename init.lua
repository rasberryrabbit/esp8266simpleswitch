-- init.lua
--Access Point management
-- this code from http://www.microdev.it/wp/en/2016/11/28/nodemcu-enduser_setup-module-lua-samplepart2/
pin = 5 --Input PIN
Resetta=0   --Variable used to manage AP reset
gpio.mode(pin,gpio.INPUT)   --Pin 5 in input mode

--If pin input is High let's start the nodemcu portal
if (gpio.read(pin)==gpio.LOW) then 

    Resetta=1
end

-- Check if reset the AP credential
if Resetta==1 then 
    -- Start the nodemcu portal
    tmr.alarm(0, 5000, 0, function() dofile("riazzerawifi.lua") end)

else
    -- Start the webserver wiht ip defined by Wi-Fi router
    tmr.alarm(0, 5000, 0, function() dofile("webserver.lua") end)

end
