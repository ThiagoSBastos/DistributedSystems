local socket = require("socket")
local json = require("dependencies/json")
local table = require("table")

local luarpc = {}

local servantList = {}

local error_msg_table = {
  CL01 = "Error in Client: Could not connect to server \n",
  CL02 = "Error in Client: Wrong number of arguments \n",
  CL03 = "Error in Client: Invalid argument type \n",
  CL04 = "Error in Client: Connection timed out \n",
  CL05 = "Error in Client: Invalid argument type in struct \n",
  SV01 = "Error in Server: Function not implemented on the server \n",
  SV02 = "Error in Server: Unexpected problem while receiving message \n",
  SV03 = "Error in Server: Unexpected problem while unmarshalling message \n",
  SV04 = "Error in Server: Unexpected problem while sending message \n",
  IF01 = "Error in Interface file: Interface without name \n",
  IF02 = "Error in Interface file: Struct without name \n",
  IF03 = "Error in Interface file: Invalid struct name \n",
  IF04 = "Error in Interface file: Invalid struct field name \n",
  IF05 = "Error in Interface file: Interface method without name \n",
  IF06 = "Error in Interface file: Interface method without result type \n",
  IF07 = "Error in Interface file: No interface in the interface file \n"
}

------------------------------ HELPER FUNCTIONS -------------------------------

local printConnectionInfo = function(client)
  local serv_ip, serv_port = client:getsockname()
  local client_ip, client_port = client:getpeername()
  print("Client " .. tostring(client_ip) .. ":" .. tostring(client_port) ..
  " connected on " .. tostring(serv_ip) .. ":" .. tostring(serv_port))
end

local printReceivingMessageInfo = function(client)
  local serv_ip, serv_port = client:getsockname()
  local client_ip, client_port = client:getpeername()
  print("Servant " .. tostring(serv_ip) .. ":" .. tostring(serv_port) ..
        " receiving message from Client " .. tostring(client_ip) .. ":" ..
        tostring(client_port))
end

local printSendingMessageInfo = function(client)
  local serv_ip, serv_port = client:getsockname()
  local client_ip, client_port = client:getpeername()
  print("Servant " .. tostring(serv_ip) .. ":" .. tostring(serv_port) ..
  " sending message to Client " .. tostring(client_ip) .. ":" .. tostring(client_port))
end

local closeClient = function(client, servant)
  for k, v in pairs(servant.clientQueue) do
    if client == v then
      table.remove(servant.clientQueue, k)
    end
  end

  client:close()
end

------------------------------ ERROR FUNCTIONS -------------------------------

-- @param type: string with the type of the error (@see error_msg_table)
local getError = function (type)
  local msg = error_msg_table[type]
  if not msg then
    msg = "Unexpected error"
  end
  return msg
end

---------------------------- MARSHALLING FUNCTIONS ----------------------------

-- Converts a Lua table to JSON (serialize)
-- @param t: lua table
local marshall = function(t)
  return json.encode(t)
end

-- Converts JSON to a Lua table (deserialize)
-- @param j: json
local unmarshall = function(j)
  return json.decode(j)
end

------------------------------ PARSING FUNCTIONS ------------------------------

-- @param sz_struct: string that contain the struct of the interface file
local parseStruct = function(sz_struct)
  local struct = {}
  local err = nil

  struct.name = string.match(sz_struct, "name%s*=%s*\"(%w*)\"")
  if (not struct.name or struct.name == "") then
    err = getError("IF02")
  end

  if (struct.name == "int" or struct.name == "char" or
      struct.name == "string" or struct.name == "double" or
      struct.name == "void" or struct.name == "number") then
    err = getError("IF03")
  end

  local sz_fields = string.match(sz_struct, "fields%s*=%s*(%b{})")
  sz_fields = string.sub(sz_fields, 2, -2)

  struct.fields = {}
  for sz_field in string.gmatch(sz_fields, "%{[^{}]*%}") do
    local field = {}
    field.name = string.match(sz_field, "name%s*=%s*\"(%w*)\"")

    if field.name == "name" then
      err = getError("IF04")
    end

    field.type = string.match(sz_field, "type%s*=%s*\"(%w*)\"")
    if field.type == "int" or field.type == "double" then
      field.type = "number"
    end

    table.insert(struct.fields, field)
  end

  return struct, err
end

-- @param sz_interface: the string that contains the interface in the interface
-- file
local parseInterface = function (sz_interface)
  local interface = {}
  local err = nil

  interface.name = string.match(sz_interface, "name%s*=%s*\"(%w*)\"")
  if (not interface.name or interface.name == "") then
    err = getError("IF01")
  end

  local sz_methods = string.match(sz_interface, "methods%s*=%s*(%b{})")
  interface.methods = {}
  for sz_methodname in string.gmatch(sz_methods, "%w*%s* =%s*%b{}") do
    local name = string.match(sz_methodname, "(%w*)%s*=%s*%b{}")
    if (not name or name == "") then
      err = getError("IF05")
    end

    local method = {}

    method.resulttype = string.match(sz_methodname, "resulttype%s*=%s*\"(%w+)\"")
    if not (method.resulttype or method.resulttype == "") then
      err = getError("IF06")
    end

    method.args = {}
    local sz_args = string.match(sz_methodname, "args%s*=%s*(%b{})")
    sz_args = string.sub(sz_args, 2, -2)
    for sz_arg in string.gmatch(sz_args, "(%b{})") do
      arg = {}
      arg.direction = string.match(sz_arg, "direction%s*=%s*\"(%w*)\"")
      arg.type = string.match(sz_arg, "type%s*=%s*\"(%w*)\"")
      if arg.type == "double" or arg.type == "int" then
        arg.type = "number"
      end

      table.insert(method.args, arg)
    end

    interface.methods[name] = method
  end

  return interface, err
end

-- Parses and validates the interface file on the client side
-- @param idl: interface file (.txt)
local parseInterfaceFile = function(idl)
  local errorMsg = nil

  local structList = {}
  for sz_struct in string.gmatch(idl, "struct%s*(%b{})") do
    local t_struct, err = parseStruct(sz_struct)

    if err then
      errorMsg = err
    else
      structList[t_struct.name] = t_struct
    end
  end

  local sz_interface = string.match(idl, "interface%s*(%b{})")
  local interface = {}
  if sz_interface then
    local iface, err = parseInterface(sz_interface)
    if err then
      errorMsg = err
    else
      interface = iface
    end
  else
    errorMsg = getError("IF07")
  end

  return interface, structList, errorMsg
end

----------------------------- VALIDATION FUNCTIONS ----------------------------

local validateStruct = function (struct_fields, param_spec)
  local errMsg = nil

  for _, field in ipairs(struct_fields) do
    if field.type ~= type(param_spec[field.name]) then
      print(field.type)
      print(param_spec[field.name])
      return getError("CL05")
    end
  end

  return errMsg
end

local validateArgsByType = function(params, idl_args, structList)
  local errMsg = nil

  for i, v in ipairs(idl_args) do
    if v.direction == "in" then
      if v.type == type(params[i]) then
        errMsg = nil
      elseif type(params[i]) == "table" and structList then
        for _, val in pairs(structList) do
          if val.name == v.type then
            errMsg = validateStruct(val.fields, params[i])
            if errMsg then
              return errMsg
            end
          end
        end
      else
        errMsg = getError("CL03")
      end
    end
  end

  return errMsg
end

local validateArgsByNumber = function(params, idl_args)
  local count = 0
  for _, v in ipairs(idl_args) do
    if v.direction == "in" then
      count = count + 1
    end
  end

  if count ~= #params then
    return getError("CL02")
  end

  return nil
end

local validate = function(params, idl_args, structList)
  local errMsg = nil
  errMsg = validateArgsByNumber(params, idl_args)
  if not errMsg then
    errMsg = validateArgsByType(params, idl_args, structList)
  end
  return errMsg
end

------------------------------ PUBLIC FUNCTIONS -------------------------------

-- @param ip: ip address of the server
-- @param port: port of the server
-- @param idl: interface file
-- @return: proxy object
function luarpc.createProxy(ip, port, idl)
  print("Creating proxy...")

  local interface, structList, errMsg = parseInterfaceFile(idl)
  if errMsg then
    error(errMsg)
  end

  local proxy_obj = {}
  for method_name, props in pairs(interface.methods) do
    proxy_obj[method_name] = function(self, ...)
      local params = {...}

      local err1 = validate(params, props.args, structList)
      if err1 then
        error(err1)
      end

      -- Establish connection to the server
      local client, err2 = socket.connect(ip, port)
      if err2 then
        error(getError("CL01"))
      end

      client:settimeout(10.0)

      local req_json = marshall({
        method = method_name,
        params = params
      })

      local _, err = client:send(req_json .. "\n")
      if err then
        error(getError("CL01"))
      end

      -- Receive response from server
      local s_response, err = client:receive()
      if err then
        error(err)
      end

      local unpacked_resp = unmarshall(s_response)
      return table.unpack(unpacked_resp)
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
  local server = assert(
    socket.bind("*", 0),
    "Error: createServant failed binding"
  )

  server:setoption("keepalive", true)

  -- create servant
  local newServant = {
    clientQueue = {},
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
      local server_ready, _, err = socket.select({servant.serv},nil, 0)
      for _, server in pairs(server_ready) do
        if type(server) ~= "number" then
          local client = server:accept()
          if client then
            client:setoption("keepalive", true)

            -- Giving feedback
            printConnectionInfo(client)

            -- Add client to client queue
            table.insert(servant.clientQueue, client)
          end
        end
      end

      -- Check which clients are ready to send a message
      local client_ready, _, err = socket.select(servant.clientQueue, nil, 0)
      for _, client in pairs(client_ready) do
        if type(client) ~= "number" then
          client:settimeout(2.0)

          -- receive request from client
          local req_json, err = client:receive()
          if err then
            client:send(getError("SV02"))
            closeClient(client, servant)
          end

          -- Unmarshall request
          local req = unmarshall(req_json)

          -- Compute response
          local response = {servant.obj[req.method](table.unpack(req.params))}

          -- Marshall result
          local response_json = marshall(response)

          -- Giving server-side feedback
          printReceivingMessageInfo(client)

          -- Send result to client
          local _, err = client:send(response_json .. "\n")
          if err then
            client:send(getError("SV04"))
            closeClient(client, servant)
          end

          -- Giving server-side feedback
          printSendingMessageInfo(client)

          -- Remove client from the queue and close the connection
          closeClient(client, servant)
        end
      end
    end
  end
end

return luarpc
