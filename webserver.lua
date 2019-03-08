-- webserver.lua
--webserver sample from the nodemcu github
print(wifi.sta.getip())
sntp.sync(nil,nil,function() print("sntp failed") end,nil)
if srv~=nil then
 srv:close()
end

gpio.mode(1, gpio.OUTPUT)

swhour=nil
swmin=nil
swpin=nil

function tryonofftime(hv, mv, sv, onoff)
    tm = rtctime.epoch2cal(rtctime.get()+32400)
    hs = tm["hour"]
    ms = tm["min"]
    ss = tm["sec"]
    setflag=false
    if hv~=nil and hs==tonumber(hv) then
      if mv~=nil and ms==tonumber(mv) then
        if sv==nil or (sv~=nil and ss==tonumber(sv)) then
          setflag=true
        end
      end
    end
    if onoff~=nil and setflag then
      gpio.write(1, onoff)
    end
    return setflag
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
              tmr.stop(1)
              _on = " selected=\"true\""              
              gpio.write(1, gpio.HIGH)
        elseif(_GET.pin == "OFF")then
              tmr.stop(1)
              _off = " selected=\"true\""
              gpio.write(1, gpio.LOW)
        else
          if gpio.read(1)==1 then
            _on = " selected=\"true\""
          else
            _off = " selected=\"true\""
          end
        end
        -- hour, min
        if _GET.hour~=nil then
          swhour=_GET.hour
        end
        if _GET.min~=nil then
          swmin=_GET.min
        end
        if _GET.swpin~=nil then
          if _GET.swpin=="ON" then
            swpin=gpio.HIGH
          else
            swpin=gpio.LOW
          end
          tmr.stop(1)
          tmr.alarm(1, 1000, tmr.ALARM_AUTO, function()
            if tryonofftime(swhour, swmin, nil, swpin)==true then
              tmr.stop(1)
            end
          end)
        end
        buf = buf.."<option".._on..">ON</opton><option".._off..">OFF</option></select></form>"
        buf = buf.."<form id=form2 src=\"/\">Time<select name=\"hour\">"
        for timehour=0,23 do
          buf = buf.."<option"
          if (swhour~=nil and timehour==tonumber(swhour)) or (swhour==nil and timehour==tm["hour"]) then
            buf=buf.." selected=true"
          end
          buf=buf..">"..tostring(timehour).."</option>"
        end
        buf = buf.."</select>:<select name=\"min\">"
        for timemin=0,59 do
          buf = buf.."<option"
          if (swmin~=nil and timemin==tonumber(swmin)) or (swmin==nil and timemin==tm["min"]) then
            buf=buf.." selected=true"
          end
          buf=buf..">"..tostring(timemin).."</option>"
        end
        buf = buf.."</select>SW<select name=\"swpin\">"
        buf = buf.."<option"
        if swpin~=nil and swpin==gpio.HIGH then
          buf=buf.." selected=true"
        end
        buf = buf..">ON</option><option"
        if swpin==nil or (swpin~=nil and swpin==gpio.LOW) then
          buf=buf.." selected=true"
        end
        buf = buf..">OFF</option></select> <button type=submit>Set</button></form>"
        client:send(buf)
    end)
    conn:on("sent", function (c) c:close() end)
end)
