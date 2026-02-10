local base64 = require("base64")
local sha = require("sha2")
local dkjson = require "dkjson"

local scopesOAuth = {
	"account:profile",
	"account:characters",
}

local filename = "poe_api_response.json"

local function build_header_list(headerText)
	local list = {}
	if headerText then
		for line in tostring(headerText):gmatch("[^\r\n]+") do
			table.insert(list, line)
		end
	end
	return list
end

local function url_encode(str)
	return (tostring(str):gsub("([^%w%-_%.~])", function(c)
		return string.format("%%%02X", c:byte())
	end))
end

local function url_decode(str)
	str = tostring(str or ""):gsub("+", " ")
	return (str:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

local PoEAPIClass = newClass("PoEAPI", function(self, authToken, refreshToken, tokenExpiry)
	self.retries = 0
	self.authToken = authToken
	self.refreshToken = refreshToken
	self.tokenExpiry = tokenExpiry or 0
	self.baseUrl = "https://api.pathofexile.com"
	self.rateLimiter = new("TradeQueryRateLimiter")

	self.ERROR_NO_AUTH = "No auth token"
end)

function PoEAPIClass:HttpRequest(url, headerText, body)
	local ok, curl = pcall(require, "lcurl.safe")
	if not ok then
		return nil, "lcurl.safe not available"
	end

	local responseHeader = ""
	local responseBody = ""
	local easy = curl.easy()

	if headerText then
		local header = build_header_list(headerText)
		if #header > 0 then
			easy:setopt(curl.OPT_HTTPHEADER, header)
		end
	end

	local userAgent = "Path of Building"
	if launch and launch.versionNumber then
		userAgent = "Path of Building/" .. tostring(launch.versionNumber)
	end

	easy:setopt_url(url)
	easy:setopt(curl.OPT_USERAGENT, userAgent)
	easy:setopt(curl.OPT_ACCEPT_ENCODING, "")
	easy:setopt(curl.OPT_FOLLOWLOCATION, 1)

	if body then
		easy:setopt(curl.OPT_POST, true)
		easy:setopt(curl.OPT_POSTFIELDS, body)
	end

	if launch and launch.connectionProtocol then
		easy:setopt(curl.OPT_IPRESOLVE, launch.connectionProtocol)
	end
	if launch and launch.proxyURL then
		easy:setopt(curl.OPT_PROXY, launch.proxyURL)
	end
	if launch and launch.noSSL then
		easy:setopt(curl.OPT_SSL_VERIFYPEER, 0)
		easy:setopt(curl.OPT_SSL_VERIFYHOST, 0)
	end

	easy:setopt_headerfunction(function(data)
		responseHeader = responseHeader .. data
		return true
	end)
	easy:setopt_writefunction(function(data)
		responseBody = responseBody .. data
		return true
	end)

	local _, error = easy:perform()
	local code = easy:getinfo(curl.INFO_RESPONSE_CODE)
	easy:close()

	local errMsg
	if error then
		errMsg = error:msg()
	elseif code ~= 200 then
		errMsg = "Response code: " .. tostring(code)
	elseif #responseBody == 0 then
		errMsg = "No data returned"
	end

	return { header = responseHeader, body = responseBody }, errMsg
end

-- func callback(valid, updateSettings)
function PoEAPIClass:ValidateAuth(callback)
	if self.authToken and self.refreshToken and self.tokenExpiry then
		if self.tokenExpiry < os.time() then
			local formText = "client_id=pob&grant_type=refresh_token&refresh_token=" .. self.refreshToken
			local response, errMsg = self:HttpRequest("https://www.pathofexile.com/oauth/token", nil, formText)
			if errMsg then
				callback(false, false)
				return
			end
			local responseLua = dkjson.decode(response.body)
			if not responseLua or not responseLua.access_token then
				callback(false, false)
				return
			end
			self.authToken = responseLua.access_token
			self.refreshToken = responseLua.refresh_token
			self.tokenExpiry = os.time() + responseLua.expires_in
			self.retries = 0
			callback(true, true)
		else
			callback(true, false)
		end
	else
		callback(false, false)
	end
end

local function base64_encode(secret)
	return base64.encode(secret):gsub("+","-"):gsub("/","_"):gsub("=$", "")
end

function PoEAPIClass:BeginAuth(redirectUri)
	math.randomseed(os.time())
	local secret = math.random(2^32-1)
	local code_verifier = base64_encode(tostring(secret))
	local code_challenge = base64_encode(sha.hex_to_bin(sha.sha256(code_verifier)))

	-- 16 character hex string
	local initialState = string.gsub('xxxxxxxxxxxxxxxx', 'x', function()
		return string.format('%x', math.random(0, 0xf))
	end)

	local redirect_uri = redirectUri or "http://127.0.0.1:45000"
	local authUrl = string.format(
		"https://www.pathofexile.com/oauth/authorize?client_id=pob&response_type=code&scope=%s&state=%s&code_challenge=%s&code_challenge_method=S256&redirect_uri=%s",
		table.concat(scopesOAuth, "%%20"),
		initialState,
		code_challenge,
		url_encode(redirect_uri)
	)

	self.pendingAuth = {
		state = initialState,
		code_verifier = code_verifier,
		redirect_uri = redirect_uri,
	}

	return authUrl
end

function PoEAPIClass:ParseAuthResponse(text)
	local input = tostring(text or "")
	local code = input:match("code=([^&%s]+)")
	local state = input:match("state=([^&%s]+)")
	if code then
		code = url_decode(code)
	end
	if state then
		state = url_decode(state)
	end
	if not code then
		code = input:match("%S+")
	end
	return code, state
end

function PoEAPIClass:CompleteAuth(code, state, callback)
	if not self.pendingAuth then
		if callback then
			callback(nil, "No auth in progress")
		end
		return nil, "No auth in progress"
	end
	if state and self.pendingAuth.state ~= state then
		if callback then
			callback(nil, "State mismatch")
		end
		return nil, "State mismatch"
	end
	if not code or code == "" then
		if callback then
			callback(nil, "Missing authorization code")
		end
		return nil, "Missing authorization code"
	end

	local formText = "client_id=pob&grant_type=authorization_code&code=" .. code ..
		"&redirect_uri=" .. url_encode(self.pendingAuth.redirect_uri) ..
		"&scope=" .. table.concat(scopesOAuth, " ") ..
		"&code_verifier=" .. self.pendingAuth.code_verifier

	local response, errMsg = self:HttpRequest("https://www.pathofexile.com/oauth/token", nil, formText)
	self.pendingAuth = nil
	if errMsg then
		self.authToken = nil
		self.refreshToken = nil
		self.tokenExpiry = nil
		if callback then
			callback(nil, errMsg)
		end
		return nil, errMsg
	end
	local responseLua = dkjson.decode(response.body)
	if not responseLua or not responseLua.access_token then
		self.authToken = nil
		self.refreshToken = nil
		self.tokenExpiry = nil
		local msg = "Invalid token response"
		if callback then
			callback(nil, msg)
		end
		return nil, msg
	end
	self.authToken = responseLua.access_token
	self.refreshToken = responseLua.refresh_token
	self.tokenExpiry = os.time() + responseLua.expires_in
	self.retries = 0
	if callback then
		callback(true)
	end
	return true
end

function PoEAPIClass:FetchAuthToken(callback)
	if self.authServer then
		return nil, "Auth already in progress"
	end
	local ok, mod = pcall(dofile, "LaunchServer.lua")
	if not ok or type(mod) ~= "table" then
		return nil, "Failed to load LaunchServer"
	end
	local server, errMsg = mod.StartServer()
	if not server then
		return nil, errMsg or "Failed to start auth server"
	end
	local authUrl = self:BeginAuth("http://localhost:" .. tostring(server.port))
	if OpenURL then
		OpenURL(authUrl)
	end
	self.authServer = server
	self.authServerModule = mod
	self.authDeadline = os.time() + 120
	return true
end

function PoEAPIClass:PollAuth()
	if not self.authServer or not self.authServerModule then
		return nil
	end
	if self.authDeadline and os.time() > self.authDeadline then
		self.authServerModule.Finish(self.authServer, false, "Timeout waiting for OAuth redirect")
		self.authServer = nil
		self.authServerModule = nil
		return false, "Timeout waiting for OAuth redirect"
	end

	local result, errMsg = self.authServerModule.Poll(self.authServer)
	if not result and not errMsg then
		return nil
	end
	if errMsg then
		self.authServerModule.Finish(self.authServer, false, errMsg)
		self.authServer = nil
		self.authServerModule = nil
		return false, errMsg
	end
	if result.err then
		self.authServerModule.Finish(self.authServer, false, result.err)
		self.authServer = nil
		self.authServerModule = nil
		return false, result.err
	end
	if not result.code or result.code == "" then
		self.authServerModule.Finish(self.authServer, false, "Missing code in redirect")
		self.authServer = nil
		self.authServerModule = nil
		return false, "Missing code in redirect"
	end

	self.authServerModule.Finish(self.authServer, true)
	self.authServer = nil
	self.authServerModule = nil

	local ok, authErr = self:CompleteAuth(result.code, result.state)
	if not ok then
		return false, authErr
	end
	return true
end

function PoEAPIClass:CancelAuth()
	if self.authServer and self.authServerModule then
		self.authServerModule.Finish(self.authServer, false, "Cancelled")
	end
	self.authServer = nil
	self.authServerModule = nil
	self.authDeadline = nil
	return true
end

-- func callback(response, errorMsg, updateSettings)
function PoEAPIClass:DownloadWithRefresh(endpoint, callback)
	self:ValidateAuth(function(valid, updateSettings)
		if not valid then
			-- Clean info about token and refresh token
			self.authToken = nil
			self.refreshToken = nil
			self.tokenExpiry = nil
			callback(nil, self.ERROR_NO_AUTH, true)
			return
		end

		local response, errMsg = self:HttpRequest(self.baseUrl .. endpoint, "Authorization: Bearer " .. self.authToken)
		if errMsg and errMsg:match("401") and self.retries < 1 then
			-- try once again with refresh token
			self.retries = 1
			self.tokenExpiry = 0
			self:DownloadWithRefresh(endpoint, callback)
		else
			self.retries = 0
			if errMsg then
				ConPrintf("Failed to download %s: %s", tostring(endpoint), tostring(errMsg))
			elseif response and response.body then
				-- create the file and log the name file
				local file = io.open(filename, "w")
				if file then
					file:write(response.body)
					file:close()
				end
				ConPrintf("Download %s:\n%s\n", tostring(endpoint), filename)
			end
			callback(response, errMsg, updateSettings)
		end
	end)
end

function PoEAPIClass:DownloadWithRateLimit(policy, url, callback)
	local now = os.time()
	local timeNext = self.rateLimiter:NextRequestTime(policy, now)
	if now >= timeNext then
		local requestId = self.rateLimiter:InsertRequest(policy)
		local onComplete = function(response, errMsg)
			self.rateLimiter:FinishRequest(policy, requestId)
			if not response or not response.header then
				callback(nil, errMsg or "No response")
				return
			end
			self.rateLimiter:UpdateFromHeader(response.header)
			if response.header:match("HTTP/[%d%.]+ (%d+)") == "429" then
				timeNext = self.rateLimiter:NextRequestTime(policy, now)
				callback(timeNext, "Response code: 429")
				return
			end
			callback(response.body, errMsg)
		end
		self:DownloadWithRefresh(url, onComplete)
	else
		callback(timeNext, "Response code: 429")
	end
end

---Fetches character list from PoE's OAuth api
---@param realm string Realm to fetch the list from (always poe2)
---@param callback function callback(response, errorMsg, updateSettings)
function PoEAPIClass:DownloadCharacterList(realm, callback)
	self:DownloadWithRateLimit("character-list-request-limit-poe2", "/character" .. (realm == "pc" and "" or "/" .. realm), callback)
end


---Fetches character from PoE's OAuth api
---@param realm string Realm to fetch the character from (always poe2)
---@param name string Character name to fetch
---@param callback function callback(response, errorMsg, updateSettings)
function PoEAPIClass:DownloadCharacter(realm, name, callback)
	self:DownloadWithRateLimit("character-request-limit-poe2", "/character" .. (realm == "pc" and "" or "/" .. realm) .. "/" .. name, callback)
end
