-- ============================================================
-- loader.lua – Fetches and runs the other files from GitHub
-- ============================================================
local USER = "am080103"          -- CHANGE to your GitHub username
local REPO = "TAPPER"      -- CHANGE to your repository name
local BRANCH = "main"                  -- or "master" / "release"

local BASE = "https://raw.githubusercontent.com/" .. USER .. "/" .. REPO .. "/" .. BRANCH .. "/"

local function fetch_and_run(file)
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
    print("[loader] Loaded " .. file)
    return true
end

local files = { "guilib.lua", "changer.lua", "main.lua" }
for _, f in ipairs(files) do
    if not fetch_and_run(f) then
        print("[loader] Aborting due to failure loading " .. f)
        return
    end
end

print("[loader] All files loaded successfully")
