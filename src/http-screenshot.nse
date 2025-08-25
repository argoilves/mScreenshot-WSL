-- Copyright (C) 2019 Securifera
-- http://www.securifera.com
-- 
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; version 2 dated June, 1991 or at your option
-- any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
-- 
-- A copy of the GNU General Public License is available in the source tree;
-- if not, write to the Free Software Foundation, Inc.,
-- 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

local shortport = require "shortport"
local stdnse = require "stdnse"
local nmap = require "nmap"

description = [[
Takes a screenshot of HTTP/HTTPS services and embeds it as Base64 image in Nmap XML.
]]

author = "Ryan Wincey"
license = "GPLv2"

categories = {"default", "discovery", "safe"}

portrule = shortport.http

local function base64_encode(data)
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
        local r,bits='',x:byte()
        for i=8,1,-1 do r = r .. (bits % 2^i - bits % 2^(i-1) > 0 and '1' or '0') end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c = c + (x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data % 3 + 1])
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local c = f:read("*all")
    f:close()
    return c
end

action = function(host, port)

    local script_dir = stdnse.get_script_args("scriptdir")
    if not script_dir then
      return stdnse.format_output(false, "Viga: 'scriptdir' argument on puudu. Palun edasta see nmap'i käsuga.")
    end
    local screenshot_py = script_dir .. "/screenshot.py"

    local outdir = stdnse.get_script_args("outdir") or script_dir .. "/scan-results"
    os.execute("mkdir -p " .. outdir)

    local outfile = string.format("%s_%d.png", host.ip, port.number)
    local file_path = outdir .. "/" .. outfile

	local cmd = string.format("/usr/bin/python3 %s -u %s -p %d -o %s > /dev/null 2>&1",
		screenshot_py, host.ip, port.number, file_path)
	local ret = os.execute(cmd)

	local data = read_file(file_path)
    if not data then
        return stdnse.format_output(false, "Screenshot missing: " .. file_path)
    end

    local b64 = base64_encode(data)
    local img = '<img src="data:image/png;base64,' .. b64 .. '" width="300"/>'

    return stdnse.format_output(true, img)
end
