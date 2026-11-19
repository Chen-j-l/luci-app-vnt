
module("luci.controller.vnt", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/vnt") then
		return
	end
	
	entry({"admin", "vpn", "vnt"}, alias("admin", "vpn", "vnt", "vnt"),_("VNT"), 44).dependent = true
	entry({"admin", "vpn", "vnt", "vnt"}, cbi("vnt"),_("VNT"), 45).leaf = true
	entry({"admin", "vpn", "vnt", "get_log"}, call("get_log")).leaf = true
	entry({"admin", "vpn", "vnt", "clear_log"}, call("clear_log")).leaf = true
	entry({"admin", "vpn", "vnt", "status"}, call("act_status")).leaf = true
	entry({"admin", "vpn", "vnt", "vnt_info"}, call("vnt_info")).leaf = true
	entry({"admin", "vpn", "vnt", "vnt_all"}, call("vnt_all")).leaf = true
	entry({"admin", "vpn", "vnt", "vnt_route"}, call("vnt_route")).leaf = true
end

function act_status()
	local e = {}
	local sys  = require "luci.sys"
	local uci  = require "luci.model.uci".cursor()
	e.running = luci.sys.call("pgrep vnt-cli >/dev/null") == 0
	local tagfile = io.open("/tmp/vnt_time", "r")
	if tagfile then
		local tagcontent = tagfile:read("*all")
		tagfile:close()
		if tagcontent and tagcontent ~= "" then
			os.execute("start_time=$(cat /tmp/vnt_time) && time=$(($(date +%s)-start_time)) && day=$((time/86400)) && [ $day -eq 0 ] && day='' || day=${day}天 && time=$(date -u -d @${time} +'%H小时%M分%S秒') && echo $day $time > /tmp/command_vnt 2>&1")
			local command_output_file = io.open("/tmp/command_vnt", "r")
			if command_output_file then
				e.vntSta = command_output_file:read("*all")
				command_output_file:close()
			end
		end
	end
	local command1 = io.popen('test ! -z "`pidof vnt-cli`" && (top -b -n1 | grep -E "$(pidof vnt-cli)" 2>/dev/null | grep -v grep | awk \'{for (i=1;i<=NF;i++) {if ($i ~ /vnt-cli/) break; else cpu=i}} END {print $cpu}\')')
	e.vntCpu = command1:read("*all")
	command1:close()
	local command2 = io.popen("test ! -z `pidof vnt-cli` && (cat /proc/$(pidof vnt-cli | awk '{print $NF}')/status | grep -w VmRSS | awk '{printf \"%.2f MB\", $2/1024}')")
	e.vntRam = command2:read("*all")
	command2:close()
	local command3 = io.popen("([ -s /tmp/vnt.tag ] && cat /tmp/vnt.tag ) || (echo `$(uci -q get vnt.@vnt-cli[0].clibin) -h |grep 'version:'| awk -F 'version:' '{print $2}'` > /tmp/vnt.tag && cat /tmp/vnt.tag)")
	e.vntTag = command3:read("*all")
	command3:close()
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function get_log()
	local log = ""
	local files = {"/tmp/vnt.log"}
	for i, file in ipairs(files) do
		if luci.sys.call("[ -f '" .. file .. "' ]") == 0 then
			log = log .. luci.sys.exec("cat " .. file)
		end
	end
	luci.http.write(log)
end

function clear_log()
	luci.sys.call("rm -rf /tmp/vnt.log")
end

function vnt_info()
	local info = luci.sys.exec("/usr/bin/vnt-cli --info 2>&1")
	info = info:gsub("Connection status", "连接状态")
	info = info:gsub("Virtual ip", "虚拟IP")
	info = info:gsub("Virtual gateway", "虚拟网关")
	info = info:gsub("Virtual netmask", "虚拟网络掩码")
	info = info:gsub("NAT type", "NAT类型")
	info = info:gsub("Relay server", "服务器地址")
	info = info:gsub("Public ips", "外网IP")
	info = info:gsub("Local addr", "WAN口IP")
	luci.http.prepare_content("application/json")
	luci.http.write_json({ info = info })
end

function vnt_all()
	local all = luci.sys.exec("/usr/bin/vnt-cli --all 2>&1")
	all = all:gsub("Virtual Ip", "虚拟IP")
	all = all:gsub("NAT Type", "NAT类型")
	all = all:gsub("Public Ips", "外网IP")
	all = all:gsub("Local Ip", "WAN口IP")
	local rows = {} 
	for line in all:gmatch("[^\r\n]+") do
		local cols = {} 
		for col in line:gmatch("%S+") do
			table.insert(cols, col)
		end
		table.insert(rows, cols) 
	end

	local html_table = "<table>"
	for i, row in ipairs(rows) do
		html_table = html_table .. "<tr>"
		for j, col in ipairs(row) do
	 
			local colors = {"#FFA500", "#800000", "#0000FF", "#3CB371", "#00BFFF", "#DAA520", "#48D1CC", "#6600CC", "#2F4F4F"}
			local color = colors[(j % 9) + 1] 
			html_table = html_table .. "<td><font color='" .. color .. "'>" .. col .. "</font></td>"
		end
		html_table = html_table .. "</tr>"
	end
	html_all = html_table .. "</table>"

	luci.http.prepare_content("application/json")
	luci.http.write_json({ all = html_all })
end

function vnt_route()
	local route = luci.sys.exec("/usr/bin/vnt-cli --route 2>&1")
	route = route:gsub("Next Hop", "下一跳地址")
	route = route:gsub("Interface", "连接地址")
	local rows = {} 
	for line in route:gmatch("[^\r\n]+") do
		local cols = {} 
		for col in line:gmatch("%S+") do
			table.insert(cols, col)
		end
		table.insert(rows, cols) 
	end

	local html_table = "<table>"
	for i, row in ipairs(rows) do
		html_table = html_table .. "<tr>"
		for j, col in ipairs(row) do
			local colors = {"#FFA500", "#800000", "#0000FF", "#3CB371", "#00BFFF"}
			local color = colors[(j % 5) + 1] 
			html_table = html_table .. "<td><font color='" .. color .. "'>" .. col .. "</font></td>"
		end
		html_table = html_table .. "</tr>"
	end
	html_route = html_table .. "</table>"
	luci.http.prepare_content("application/json")
	luci.http.write_json({ route = html_route })
end
