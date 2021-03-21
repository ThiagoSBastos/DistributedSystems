local socket = require("socket")

local luarpc = {}
local servantList = {}

-- @param ip:
-- @param port:
-- @param interface:
-- @return :
function luarpc.createProxy(ip, port)
  print("Creating proxy...")
  --dofile(interface)
  --local functions = {}

  -- create request
  local request = 2

  -- Create client
  -- Establish connection to the server
  local client, err = socket.connect(ip, port)

  if err then
    print("Could not create client")
  end

  local _, err = client:send(request .. "\n")
  if err then
    print("Error in sending message o server")
  end

  local response, err = client:receive("*l")
  if err then
    print("Error from server response")
  end
  print(response)

  return 1--functions
end

-- @param object:
-- @param interface:
-- @return ip and port of the servant
function luarpc.createServant(object)--, interface)

  -- create socket and bind to server
  local server = assert(socket.bind("*", 0), "Error: createServant failed binding")
  --server:setoption("keepalive", true)
  --server:setoption("tcp-nodelay", true)

  --dofile(interface)

  local newServant = {
    clientList = {},
    server = server,
    object = object,
    --interface = interface,
  }

  -- Add to servantList
  table.insert(servantList, newServant)

  -- Print info about the server
  local ip, port = server:getsockname()
  print("Server IP: " .. ip)
  print("Server port: " .. port)

  return newServant
end

function luarpc.waitIncoming()
  print("Waiting requests...")

  while true do
    for _, servant in pairs(servantList) do
      local client = servant.server:accept()
      --if client then
      --  client:setoption("keepalive", true)
      --  client:setoption("tcp-nodelay", true)
      --end

      -- Connection info.
      local l_ip, l_port = client:getsockname()
      local r_ip, r_port = client:getpeername()
      print("Client " .. tostring(r_ip) .. ":" .. tostring(r_port) .. " connected on " .. tostring(l_ip) .. ":" .. tostring(l_port))

      -- receive message from client
      local message, err = client:receive()

      -- Unmarshall message
      -- Validate messageS
      if err then
        -- Send error to client
        print('Unexpected message')



      else
        -- Compute result
        -- Send result to client
        local _, err = client:send("Server received the following value " .. message .. "\n")
        if not err then
          print("Success in sending response")
        end
      end

      -- Close connection
      client:close()

    end
  end
end

return luarpc

