local socket = require("socket")
local json = require("dependencies/json")
local table = require("table")

local luarpc = {}

local servantList = {}

-- TODO: REMOVE THIS
local function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    else
      print(formatting .. tostring(v))
    end
  end
end

-- Global idl
rpc_idl = {}
function interface(idl)
  rpc_idl = idl
end
-- TODO: Fazer o mesmo pra structs

---------------------------- MARSHALLING FUNCTIONS ----------------------------
-- TODO: tratamento de erros
local marshall = function(t)
  return (json.encode(t))
end

-- TODO: tratamento de erros
local unmarshall = function(t)
  return (json.decode(t))
end
----------------------------- PARSING FUNCTIONS -------------------------------

local parse_idl = function(params, method_name, t_methods)
  local isok, parsed_params, err_msg = true, params, nil

  return isok, parsed_params, err_msg
end

------------------------------ PUBLIC FUNCTIONS -------------------------------

-- @param ip: ip address of the server
-- @param port: port of the server
-- @param idl: interface file
-- @return: proxy object
function luarpc.createProxy(ip, port, idl)
  print("Creating proxy...")

  dofile(idl)

  local proxy_obj = {}

  for method_name, props in pairs(rpc_idl.methods) do
    proxy_obj[method_name] = function(self, ...)
      local params = {...}

      -- TODO: validate with IDL
      --local isValid = parse_idl(params, method_name, rpc_idl.methods)

      -- Establish connection to the server
      local client = assert(socket.connect(ip, port),
                           "Could not connect client to the server")

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
      return s_response
    end
    --print("method name " .. tostring(method_name))
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

  -- TODO: compare implementation with interface

  -- create servant object
  local newServant = {
    serv = server,
    obj = object,
    interface = idl, -- TODO: check if we need this
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

      for _, server in ipairs(server_ready) do
        local client = server:accept()
        if client then
          client:setoption("keepalive", true)
          client:settimeout(1)

          -- Connection info. TODO: remove later
          local serv_ip, serv_port = client:getsockname()
          local client_ip, client_port = client:getpeername()
          print("Client " .. tostring(client_ip) .. ":" .. tostring(client_port) ..
                " connected on " .. tostring(serv_ip) .. ":" .. tostring(serv_port))

          -- receive request from client
          local req_json, err = client:receive()

          -- Unmarshall request
          local req = unmarshall(req_json)

          -- Compute response
          local response = servant.obj[req.method](table.unpack(req.params))

          ---- Marshall result
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

return luarpc

