repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

-- executor moment
if identifyexecutor then
	if table.find({'Argon', 'Volt', 'Wave'}, ({identifyexecutor()})[1]) then
		getgenv().setthreadidentity = nil
	end
end

-- ========================
-- SAFE FILE HELPERS
-- ========================

local function safeReadFile(path)
	local ok, res = pcall(function()
		return readfile(path)
	end)
	if ok and type(res) == "string" and res ~= "" then
		return res
	end
	return nil
end

local function ensureFile(path, default)
	if not isfile(path) then
		writefile(path, default)
	end
end

-- ensure required files
ensureFile('newvape/profiles/commit.txt', 'main')
ensureFile('newvape/profiles/gui.txt', 'new')

local COMMIT = safeReadFile('newvape/profiles/commit.txt') or 'main'
local GUI_NAME = safeReadFile('newvape/profiles/gui.txt') or 'new'

-- ========================
-- CORE SETUP
-- ========================

local vape
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(o) return o end
local playersService = cloneref(game:GetService('Players'))

local loadstring = function(src, name)
	local fn, err = loadstring(src, name)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load: '..err, 30, 'alert')
	end
	return fn
end

-- ========================
-- DOWNLOAD FIXED
-- ========================

local function downloadFile(path, reader)
	if not isfile(path) then
		local url =
			'https://raw.githubusercontent.com/b-ltdev/ClosetVapeV4/' ..
			COMMIT .. '/' ..
			select(1, path:gsub('newvape/', ''))

		local ok, res = pcall(function()
			return game:HttpGet(url, true)
		end)

		if not ok or not res or res == '404: Not Found' then
			error('Failed to download: '..path)
		end

		if path:find('%.lua$') then
			res =
				'-- watermark, removing breaks cache invalidation\n' ..
				res
		end

		writefile(path, res)
	end

	return (reader or readfile)(path)
end

-- ========================
-- LOAD GUI
-- ========================

if not isfolder('newvape/assets/'..GUI_NAME) then
	makefolder('newvape/assets/'..GUI_NAME)
end

vape = loadstring(
	downloadFile('newvape/guis/'..GUI_NAME..'.lua'),
	'gui'
)()

shared.vape = vape

-- ========================
-- FINISH LOADING
-- ========================

local function finishLoading()
	vape.Init = nil
	vape:Load()

	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleported
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if teleported or shared.VapeIndependent then return end
		teleported = true

		local script = [[
			shared.vapereload = true
			loadstring(game:HttpGet(
				'https://raw.githubusercontent.com/b-ltdev/ClosetVapeV4/]] .. COMMIT .. [[/loader.lua',
				true
			))()
		]]

		vape:Save()
		queue_on_teleport(script)
	end))

	if not shared.vapereload
	and vape.Categories
	and vape.Categories.Main
	and vape.Categories.Main.Options['GUI bind indicator']
	and vape.Categories.Main.Options['GUI bind indicator'].Enabled then
		vape:CreateNotification(
			'Finished Loading',
			vape.VapeButton
				and 'Press the button in the top right to open GUI'
				or 'Press '..table.concat(vape.Keybind, ' + '):upper()..' to open GUI',
			5
		)
	end
end

-- ========================
-- LOAD GAME SCRIPTS
-- ========================

if not shared.VapeIndependent then
	loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()

	local gamePath = 'newvape/games/'..game.PlaceId..'.lua'

	if isfile(gamePath) then
		loadstring(readfile(gamePath), tostring(game.PlaceId))(...)
	else
		local ok, src = pcall(function()
			return game:HttpGet(
				'https://raw.githubusercontent.com/b-ltdev/ClosetVapeV4/' ..
				COMMIT .. '/games/' .. game.PlaceId .. '.lua',
				true
			)
		end)

		if ok and src and src ~= '404: Not Found' then
			writefile(gamePath, src)
			loadstring(src, tostring(game.PlaceId))(...)
		end
	end

	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
