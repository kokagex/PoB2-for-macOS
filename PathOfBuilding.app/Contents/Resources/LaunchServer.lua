local ffi = require("ffi")
local bit = require("bit")

local M = {}

ffi.cdef[[
typedef unsigned short sa_family_t;
typedef unsigned int socklen_t;
typedef uint16_t in_port_t;
typedef uint32_t in_addr_t;
struct in_addr { in_addr_t s_addr; };
struct sockaddr { sa_family_t sa_family; char sa_data[14]; };
struct sockaddr_in { sa_family_t sin_family; in_port_t sin_port; struct in_addr sin_addr; unsigned char sin_zero[8]; };
int socket(int domain, int type, int protocol);
int bind(int sockfd, const struct sockaddr* addr, socklen_t addrlen);
int listen(int sockfd, int backlog);
int accept(int sockfd, struct sockaddr* addr, socklen_t* addrlen);
int close(int fd);
int fcntl(int fd, int cmd, int arg);
int setsockopt(int sockfd, int level, int optname, const void* optval, socklen_t optlen);
uint16_t htons(uint16_t hostshort);
uint32_t htonl(uint32_t hostlong);
int recv(int sockfd, void* buf, size_t len, int flags);
int send(int sockfd, const void* buf, size_t len, int flags);
]]

local C = ffi.C

local AF_INET = 2
local SOCK_STREAM = 1
local SOL_SOCKET = 1
local SO_REUSEADDR = 2
local F_GETFL = 3
local F_SETFL = 4
local O_NONBLOCK = 0x0004
local EAGAIN = 35

local function set_nonblock(fd)
	local flags = C.fcntl(fd, F_GETFL, 0)
	if flags ~= -1 then
		C.fcntl(fd, F_SETFL, bit.bor(flags, O_NONBLOCK))
	end
end

local function close_fd(fd)
	if fd and fd >= 0 then
		C.close(fd)
	end
end

local function url_decode(str)
	str = tostring(str or ""):gsub("+", " ")
	return (str:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

local function parse_query(path)
	local query = path:match("%?(.*)")
	local params = {}
	if not query then
		return params
	end
	for key, val in query:gmatch("([^&=]+)=([^&=]*)") do
		params[key] = url_decode(val)
	end
	return params
end

local function bind_port(port)
	local fd = C.socket(AF_INET, SOCK_STREAM, 0)
	if fd < 0 then
		return nil, "socket failed"
	end
	local opt = ffi.new("int[1]", 1)
	C.setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, opt, ffi.sizeof(opt))

	local addr = ffi.new("struct sockaddr_in")
	addr.sin_family = AF_INET
	addr.sin_port = C.htons(port)
	addr.sin_addr.s_addr = C.htonl(0x7f000001)
	if C.bind(fd, ffi.cast("struct sockaddr*", addr), ffi.sizeof(addr)) ~= 0 then
		close_fd(fd)
		return nil, "bind failed"
	end
	if C.listen(fd, 1) ~= 0 then
		close_fd(fd)
		return nil, "listen failed"
	end
	set_nonblock(fd)
	return fd
end

function M.StartServer()
	local lastErr
	for p = 49082, 49084 do
		local fd, err = bind_port(p)
		if fd then
			return { listen_fd = fd, port = p, client_fd = nil, buffer = "" }
		end
		lastErr = err
	end
	return nil, lastErr or "Failed to bind local port 49082-49084"
end

function M.Poll(server)
	if not server then
		return nil
	end

	if not server.client_fd then
		local addr = ffi.new("struct sockaddr_in")
		local addrlen = ffi.new("socklen_t[1]", ffi.sizeof(addr))
		local fd = C.accept(server.listen_fd, ffi.cast("struct sockaddr*", addr), addrlen)
		if fd == -1 then
			local err = ffi.errno()
			if err == EAGAIN then
				return nil
			end
			return nil, "accept failed"
		end
		server.client_fd = fd
		set_nonblock(fd)
	end

	local buf = ffi.new("char[4096]")
	local n = C.recv(server.client_fd, buf, 4095, 0)
	if n == -1 then
		local err = ffi.errno()
		if err == EAGAIN then
			return nil
		end
		return nil, "recv failed"
	elseif n == 0 then
		return nil, "client closed"
	end

	server.buffer = server.buffer .. ffi.string(buf, n)
	local line = server.buffer:match("^(.-)\r?\n")
	if not line then
		return nil
	end

	local path = line:match("GET%s+([^%s]+)")
	if not path then
		return nil, "invalid request"
	end

	local params = parse_query(path)
	local result = {
		code = params.code,
		state = params.state,
		err = params.error_description or params.error,
	}
	return result
end

function M.Finish(server, ok, msg)
	if not server then
		return
	end
	if server.client_fd then
		local body
		if ok then
			body = "<html><body><h3>Authentication complete.</h3>You can close this window.</body></html>"
		else
			body = "<html><body><h3>Authentication failed.</h3>" .. tostring(msg or "") .. "</body></html>"
		end
		local headers = {
			"HTTP/1.1 200 OK",
			"Content-Type: text/html; charset=utf-8",
			"Content-Length: " .. tostring(#body),
			"Connection: close",
			"",
			"",
		}
		local resp = table.concat(headers, "\r\n") .. body
		C.send(server.client_fd, resp, #resp, 0)
	end
	M.Close(server)
end

function M.Close(server)
	if not server then
		return
	end
	close_fd(server.client_fd)
	close_fd(server.listen_fd)
	server.client_fd = nil
	server.listen_fd = nil
end

return M
