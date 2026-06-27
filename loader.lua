-- ============================================================
-- loader.lua – Fetches and runs the other files from GitHub
-- ============================================================
local USER = "MudillaScripts"          -- CHANGE to your GitHub username
local REPO = "aw_cs2v6_femboytap"      -- CHANGE to your repository name
local BRANCH = "main"                  -- or "master" / "release"

local BASE = "https://raw.githubusercontent.com/" .. USER .. "/" .. REPO .. "/" .. BRANCH .. "/"

local function fetch_and_run(file, global_name)
    local url = BASE .. file
    local src = http.Get(url)
    if not src or type(src) ~= "string" then
        print("[loader] Failed to fetch " .. file)
        return false
    end
    local chunk, err = loadstring(src, "=" .. file)
    if not chunk then
        print("[loader] Compile error in " .. file .. ": " .. tostring(err))
        return false
    end
    local ok, ret = pcall(chunk)
    if not ok then
        print("[loader] Runtime error in " .. file .. ": " .. tostring(ret))
        return false
    end
    -- Store the returned value globally if a name is provided
    if global_name then
        _G[global_name] = ret
    end
    print("[loader] Loaded " .. file)
    return true
end

-- Load in correct order, storing returned tables in globals
local files = {
    { "guilib.lua", "FEMBOYTAP_GUI" },
    { "skins_data.lua", nil },        -- this file sets _G.FEMBOYTAP_SKINS internally
    { "changer.lua", "FEMBOYTAP_CHANGER" },
    { "main.lua", nil },              -- main doesn't return anything, it uses the globals
}
for _, entry in ipairs(files) do
    local f, gname = entry[1], entry[2]
    if not fetch_and_run(f, gname) then
        print("[loader] Aborting due to failure loading " .. f)
        return
    end
end

print("[loader] All files loaded successfully")
