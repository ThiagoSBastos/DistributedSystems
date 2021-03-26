# luarpc

## Description
This library provides an API to perform a Remote Procedure Call (RPC)

## Motivation
This library is the first assigment for the course INF 2545 - Distributed Systems taugh by Professor Noemi Rodriguez at PUC-Rio.

## Dependencies
* Lua 5.4.2

* [LuaSocket 3.0](https://luarocks.org/modules/luasocket/luasocket)

* [json.lua](https://github.com/rxi/json.lua/)


## Usage

Running the client on port 6060:
```
lua client_rpc.lua 6060
```

Running the servers:
```
lua server_rpc.lua
```