local lualdap = require 'lualdap';
local timer = require 'util.timer';

-- Get LDAP parameters from mod_auth_ldap settings
local ldap_server   = module:get_option_string("ldap_server", "localhost");
local ldap_base     = assert(module:get_option_string("ldap_base"), "ldap_base is a required option for ldap");
local ldap_tls      = module:get_option_boolean("ldap_tls");
local ldap_filter   = module:get_option_string("ldap_filter", "(uid=*)");
local ldap_binddn   = module:get_option_string("ldap_rootdn", "");
local ldap_bindpass = module:get_option_string("ldap_password", "");
local ldap_scope    = module:get_option_string("ldap_scope", "subtree");

-- Get mod_roster_ldap ones from our own configuration container
local options       = module:get_option('ldap_roster') or {}
local ldap_uidattr  = options.ldap_uidattr or 'uid';
local ldap_nameattr = options.ldap_nameattr or 'cn';
local group_name    = options.group_name or 'Shared roster';
local refresh_time  = options.refresh_time or 60;

module:log('debug', 'Module enabled, searching for \''..ldap_filter..'\' in '..ldap_base..' ('..ldap_server..')')
module:log('debug', 'Refreshing shared roster every '..refresh_time..' seconds')

local lc = assert(lualdap.open_simple(ldap_server, ldap_binddn, ldap_bindpass, ldap_tls),
	'Could not connect to LDAP server');

local ldap_roster = {}

local function split(st, sep)
	local i = 0
	return function()
		if i < string.len(st) then
			local s, e = string.find(st, sep, i)
			s, e = s or 0, e or string.len(st)
			local r = string.sub(st, i, s - 1)
			i = e + 1
			return r
		end
	end
end

local function dc_to_host(dn)
	local host, comps = '', {};
	for comp in split(dn, ',') do
		table.insert(comps, comp);
	end
	for i = #comps, 1, -1 do
		local comp = comps[i];
		if not string.match(comp, 'dc=') then
			return string.sub(host, 1, -2);
		end
		host = string.sub(comp, string.find(comp, '=') + 1)..'.'..host;
	end
end

local function ldap_to_entry(dn, attrs)
	local host = dc_to_host(dn);
	local na = attrs[ldap_nameattr];
	local name = type(na) == 'table' and na[1] or na;
	return { jid = attrs[ldap_uidattr]..'@'..host, name=name };
end

local function inject_roster_contacts(username, host, roster)
	for jid, entry in pairs(ldap_roster) do
		if not (jid == username..'@'..host or roster[jid]) then
			module:log('debug', 'injecting '..jid..' as '..entry.name)
			roster[jid] = {};
			local r = roster[jid];
			r.subscription = 'both';
			r.name = entry.name;
			r.groups = { [group_name] = true };
			r.persist = false;
		end
	end

	if roster[false] then
		roster[false].version = true;
	end
end


local function push_all_rosters()
	for host in pairs(hosts) do
		for username, session in pairs(hosts[host].sessions) do
			local roster, new_roster = session.roster, {}
			for jid, entry in pairs(roster) do
				if entry.persist ~= false then
					new_roster[jid] = entry
				end
			end
			inject_roster_contacts(username, host, new_roster)
		end
	end
end

local function update_roster()
	local iter, err = lc:search { 
		base = ldap_base;
		scope = ldap_scope;
		filter = ldap_filter;
	}
	if not iter then
		print('error', err);
	end
	for dn, attrs in iter do
		local entry = ldap_to_entry(dn, attrs);
		ldap_roster[entry.jid] = entry
	end
	module:log('debug', 'LDAP roster has been refreshed')
	--push_all_rosters()
	--module:log('info', 'LDAP roster has been pushed')
	return refresh_time
end

local function remove_virtual_contacts(username, host, datastore, data)
	if datastore == 'roster' then
		local new_roster =  {};
		for jid, contact in pairs(data) do
			if contact.persist ~= false then
				new_roster[jid] = contact
			end
		end
		if new_roster[false] then
			new_roster[false].version = nil;
		end
		return username, host, datastore, new_roster;
	end

	return username, host, datastore, data
end

function module.load()
	update_roster()
	timer.add_task(refresh_time, update_roster)
	module:hook('roster-load', inject_roster_contacts);
	datamanager.add_callback(remove_virtual_contacts);
end

function module.unload()
	datamanager.remove_callback(remove_virtual_contacts);
end
