local socket = require("socket")
local json = require("dependencies/json")
local table = require("table")

local luarpc = {}

local servantList = {}

local error_msg_table = {
  {E00 = "Could not connect client to server \n"},
  {E01 = "Wrong number of arguments \n"},
  {E02 = "Invalid argument type \n"},
  {E03 = "Connection timed out \n"},
  {E04 = "Empty interface \n"},
  {E05 = "Struct without name \n"},
  {E06 = "Struct name cannot be a type \n"}
}

-- TODO: REMOVE THIS
local function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    local formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    else
      print(formatting .. tostring(v))
    end
  end
end
------------------------------ HELPER FUNCTIONS -------------------------------
local giveConnectionInfo = function(client)
  local serv_ip, serv_port = client:getsockname()
  local client_ip, client_port = client:getpeername()
  print("Client " .. tostring(client_ip) .. ":" .. tostring(client_port) ..
        " connected on " .. tostring(serv_ip) .. ":" .. tostring(serv_port))
end
------------------------------ ERROR FUNCTIONS -------------------------------
local getError = function (type)
  local msg = error_msg_table[type]
  if not msg then
    msg = "Unexpected error"
  end
  return msg
end
---------------------------- MARSHALLING FUNCTIONS ----------------------------
local marshall = function(t)
  return json.encode(t)
end

local unmarshall = function(t)
  return json.decode(t)
end

----------------------------- VALIDATION FUNCTIONS ----------------------------
local validateIDL = function(props)
  local types_match, same_numb_of_args = true, true

  return types_match, same_numb_of_args
end
------------------------------ PARSING FUNCTIONS ------------------------------
local parseStruct = function(sz_struct)
  local struct = {}

  struct.name = string.match(sz_struct, "name%s*=%s*\"(%w*)\"")
  if (not struct.name or struct.name == "") then
    error("struct without a name field isn't permitted. Aborting")
  end

  if (struct.name == "int" or struct.name == "char" or
      struct.name == "string" or struct.name == "double" or
      struct.name == "void") then
    error("structs's name cannot be " .. struct.name .. "!!!")
  end

  local sz_fields = string.match(sz_struct, "fields%s*=%s*(%b{})")
  sz_fields = string.sub(sz_fields, 2, -2)

  struct.fields = {}
  for sz_field in string.gmatch(sz_fields, "%{[^{}]*%}") do
    local field = {}
    field.name = string.match(sz_field, "name%s*=%s*\"(%w*)\"")

    if field.name == "name" then
      error("Struct's field cannot be named 'name'")
    end

    field.type = string.match(sz_field, "type%s*=%s*\"(%w*)\"")
    table.insert(struct.fields, field)
  end

  return struct
end

local parseInterface = function (sz_interface)
	local interface = {}

  interface.name = string.match(sz_interface, "name%s*=%s*\"(%w*)\"")
	if (not interface.name or interface.name == "") then
    error("IDL without a name field isn't permitted. Aborting")
  end
	local sz_methods = string.match(sz_interface, "methods%s*=%s*(%b{})")

	interface.methods = {}
	for sz_methodname in string.gmatch(sz_methods, "%w*%s* =%s*%b{}") do
		local name = string.match(sz_methodname, "(%w*)%s*=%s*%b{}")
		if (not name or name == "") then
      error("Unnamed method isn't permitted. Aborting")
    end

    local method = {}

		method.resulttype = string.match(sz_methodname, "resulttype%s*=%s*\"(%w+)\"")
		if not (method.resulttype or method.resulttype == "") then
      error("Method with no resulttype specification isn't permitted. Aborting")
    end

		method.args = {}

		local sz_args = string.match(sz_methodname, "args%s*=%s*(%b{})")
		sz_args = string.sub(sz_args, 2, -2)

    for sz_arg in string.gmatch(sz_args, "(%b{})") do
			arg = {}
			arg.direction = string.match(sz_arg, "direction%s*=%s*\"(%w*)\"")
			arg.type = string.match(sz_arg, "type%s*=%s*\"(%w*)\"")

			table.insert(method.args, arg)
		end

		interface.methods[name] = method
	end

  return interface
end

-- @param idl: interface file
local parseInterfaceFile = function(idl)
  local errorMsg = nil

  local structList = {}
  for sz_struct in string.gmatch(idl, "struct%s*(%b{})") do
	  local t_struct = parseStruct(sz_struct)
	  structList[t_struct.name] = t_struct
  end

  local sz_interface = string.match(idl, "interface%s*(%b{})")
  local interface = parseInterface(sz_interface)

  return interface, structList, errorMsg
end
------------------------------ PUBLIC FUNCTIONS -------------------------------

-- @param ip: ip address of the server
-- @param port: port of the server
-- @param idl: interface file
-- @return: proxy object
function luarpc.createProxy(ip, port, idl)
  print("Creating proxy...")

  local interface, structList, err = parseInterfaceFile(idl)

  local proxy_obj = {}
  for method_name, props in pairs(interface.methods) do
    proxy_obj[method_name] = function(self, ...)
      local params = {...}

      -- TODO: validation

      -- Establish connection to the server
      local client = assert(
        socket.connect(ip, port),
        "Could not connect client to the server"
      )

      client:settimeout(2.0)

      -- Send request to server
      local req_json = marshall({
        method = method_name,
        params = params
      })

      local _, err = client:send(req_json .. "\n")
      if err then
        print("Could not send message to server")
      end

      -- Receive response from server
      local s_response = client:receive()
      print(s_response)
      local unpacked_resp = unmarshall(s_response)
      return unpacked_resp
    end
  end

  return proxy_obj
end

-- @param object: table containing the implementation of all functions
-- of the interface
-- @param idl: interface file
-- @return: ip and port of the servant
function luarpc.createServant(object, idl)
  print("Creating servant number " .. #servantList + 1 .. ".")

  -- create socket and bind to server
  local server = assert(socket.bind("*", 0),
                        "Error: createServant failed binding")
  server:setoption("keepalive", true)

  -- create servant
  local newServant = {
    serv = server,
    obj = object
  }

  -- Add to servantList
  table.insert(servantList, newServant)

  return server:getsockname()
end

function luarpc.waitIncoming()
  print("Waiting requests...")

  while true do
    for _, servant in pairs(servantList) do
      -- Check which servers are available to connect with clients
      local server_ready, _, err = socket.select({servant.serv})

      for _, server in pairs(server_ready) do
        if type(server) ~= "number" then
        local client = server:accept()
        if client then
          client:settimeout(2.0)
          client:setoption("keepalive", true)

          -- Connection info. TODO: remove later
          giveConnectionInfo(client)

          -- receive request from client
          local req_json, err = client:receive()

          print(req_json)
          -- Unmarshall request
          local req = unmarshall(req_json)

          -- Compute response
          local response = {servant.obj[req.method](table.unpack(req.params))}

          -- Marshall result
          local response_json = marshall(response)

          -- Send result to client
          local _, err = client:send(response_json .. "\n")

          -- Close connection
          client:close()
        end
      end
      end
    end
  end
end

return luarpc

