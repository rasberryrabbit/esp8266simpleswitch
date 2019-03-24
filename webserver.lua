-- webserver.lua
--webserver sample from the nodemcu github
print(wifi.sta.getip())

sntp.sync(nil,nil,function() print("sntp failed") end,nil)
if srv~=nil then
 srv:close()
end

gpio.mode(1, gpio.OUTPUT)

swhour=""
swmin=""

swhouroff=""
swminoff=""
timeractive=0
dotimer=0

function tryonofftime(hv, mv, sv, onoff)
    tm = rtctime.epoch2cal(rtctime.get()+32400)
    hs = tm["hour"]
    ms = tm["min"]
    ss = tm["sec"]
    setflag=false
    if hv~="" or mv~="" then
        if hv=="" or (hv~="" and hs==tonumber(hv)) then
          if mv=="" or (mv~="" and ms==tonumber(mv)) then
            if sv=="" or (sv~="" and ss>=tonumber(sv)) then
              setflag=true
            end
          end
        end
        if onoff~=nil and setflag then
          gpio.write(1, onoff)
        end
    end
    return setflag
end

function tmrout(s)
  if s~="" then
    return s
  else
    return "**"
  end
end

function toint(s)
  return tonumber(s)
end

srv=net.createServer(net.TCP)
srv:listen(80,function(conn)
    conn:on("receive", function(client,request)
        local buf = ""
        local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP")
        if(method == nil)then
            _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP")
        end
        local _GET = {}
        if (vars ~= nil)then
            for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
                _GET[k] = v
            end
        end
        tm = rtctime.epoch2cal(rtctime.get()+32400)
        buf = buf..string.format("<h1>%04d/%02d/%02d %02d:%02d:%02d</h1>", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"])
        buf = buf.."<h1> Set relay</h1><form id=form1 src=\"/\">Turn PIN1 <select name=\"pin\" onchange=\"form.submit()\">"
        local _on,_off = "",""
        if(_GET.pin == "ON")then
              _on = " selected=true"              
              gpio.write(1, gpio.HIGH)
              tmr.stop(1)
              timeractive=0
        elseif(_GET.pin == "OFF")then
              _off = " selected=true"
              gpio.write(1, gpio.LOW)
              tmr.stop(1)
              timeractive=0
        else
          if gpio.read(1)==1 then
            _on = " selected=true"
          else
            _off = " selected=true"
          end
        end
        -- hour, min
        local newhour=nil
        local newmin=nil
        if _GET.swpin~=nil then
            if _GET.hour~=nil then
              newhour=_GET.hour
              local y, x = pcall(toint,newhour)
              if y==true then
                if x>=24 then
                  newhour="23"
                end
              else
                newhour=""
              end
            else
              newhour=""
            end
            if _GET.min~=nil then
              newmin=_GET.min
              local y,x = pcall(toint,newmin)
              if y==true then
                if x>=60 then
                  newmin="59"
                end
              else
                newmin=""
              end
            else
              newmin=""
            end
            if _GET.swpin=="ON" then
                swhour=newhour
                swmin=newmin
            else
                swhouroff=newhour
                swminoff=newmin
            end
        end
        if _GET.hour~=nil or _GET.min~=nil then
          if newhour~="" or newmin~="" then
              tmr.alarm(1, 1000, tmr.ALARM_AUTO, function()
                tryonofftime(swhour, swmin, "", gpio.HIGH)
                tryonofftime(swhouroff, swminoff, "", gpio.LOW)
              end)
              timeractive=1
          else
              tmr.stop(1)
              timeractive=0
          end
        end
        buf = buf.."<option".._on..">ON</opton><option".._off..">OFF</option></select></form>"
        -- on timer
        buf = buf.."<p>Timer : "
        if timeractive==0 then
          buf = buf.."disabled"
        else
          buf = buf.."enabled"
        end
        local texthour=""
        local textmin=""
        if swhour~="" then
          texthour=swhour
        else
          texthour=swhouroff
        end
        if swmin~="" then
          textmin=swmin
        else
          textmin=swminoff
        end
        buf = buf.."</p>"
        buf = buf.."<form id=form2 src=\"/\">On/Off Time<input type=\"text\" name=\"hour\" value=\""..texthour.."\">"
        buf = buf..":<input type=\"text\" name=\"min\" value=\""..textmin.."\">"
        _swon=""
        _swoff=""
        if swhour~="" or swmin~="" then
          _swoff = " selected=true"
        else
          _swon = " selected=true"
        end        
        buf = buf.."<select name=swpin><option".._swon..">ON</option><option".._swoff..">OFF</option>"
        buf = buf.."</select><button type=submit>Set</button></form>"
        buf = buf.."<form id=form3 src=\"/\"><input type=\"hidden\" name=\"pin\" value=\"OFF\"><input type=\"hidden\" name=\"hour\" value=\"\"><input type=\"hidden\" name=\"min\" value=\"\"><button type=submit>Reset</button></form>"
        buf = buf..string.format("%2s:%2s (on) <br/> %2s:%2s (off)",tmrout(swhour),tmrout(swmin),tmrout(swhouroff),tmrout(swminoff))
        client:send(buf)
    end)
    conn:on("sent", function (c) c:close() end)
end)

-- ssdp

net.multicastJoin(wifi.sta.getip(), "239.255.255.250")

local ssdp_notify = "NOTIFY * HTTP/1.1\r\n"..
"HOST: 239.255.255.250:1900\r\n"..
"CACHE-CONTROL: max-age=100\r\n"..
"NT: upnp:rootdevice\r\n"..
"USN: 6e50e521-6abc-4a06-8f5d-813ee1"..string.format("%x",node.chipid()).."::upnp:rootdevice\r\n"..
"NTS: ssdp:alive\r\n"..
"SERVER: NodeMCU/20190304 UPnP/1.1\r\n"..
"Location: http://"..wifi.sta.getip().."/switch.xml\r\n\r\n"


local ssdp_response = "HTTP/1.1 200 OK\r\n"..
"Cache-Control: max-age=100\r\n"..
"EXT:\r\n"..
"SERVER: NodeMCU/20190304 UPnP/1.1\r\n"..
"ST: upnp:rootdevice\r\n"..
"USN: uuid:6e50e521-6abc-4a06-8f5d-813ee1"..string.format("%x",node.chipid()).."\r\n"..
"Location: http://"..wifi.sta.getip().."/switch.xml\r\n\r\n"

local udp_response = wifi.sta.getip().."\n"..string.format("%x",node.chipid()).."\nSWITCH-INFO\npin[ON|OFF],hour[24],min[60],swpin[ON|OFF]\n"

local function response(connection, payLoad, port, ip)
    if string.match(payLoad,"M-SEARCH") then
        connection:send(port,ip,ssdp_response)
    end
end

UPnPd = net.createUDPSocket()
UPnPd:on("receive", response )
UPnPd:listen(1900,"0.0.0.0")

tmr.alarm(3, 10000, 1, function()
    UPnPd:send(1900,'239.255.255.250',ssdp_notify)
end)

udp50k = net.createUDPSocket()

tmr.alarm(5, 3000, 1, function()
  udp50k:send(50000, wifi.sta.getbroadcast(), udp_response)
end)

