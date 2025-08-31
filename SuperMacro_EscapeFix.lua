-- SuperMacro_EscapeFix.lua
-- Vanilla 1.12.1 safe ESC handling for SuperMacro editors.
-- Does NOT override ToggleGameMenu(), so CloseAllWindows() (and Bagshui) keep working.

local _G = getfenv(0)

-- ---- utils ----
local function isFunc(f) return type(f) == "function" end

local function isUIFrame(o)
  return type(o) == "table" and (isFunc(o.GetObjectType) or isFunc(o.IsObjectType))
end

local function getObjectTypeName(f)
  if isFunc(f.GetObjectType) then
    return f:GetObjectType()
  end
  if isFunc(f.IsObjectType) and f:IsObjectType("EditBox") == 1 then
    return "EditBox"
  end
  return nil
end

local function isUnderNamedFrame(f, rootName)
  if not isUIFrame(f) then return false end
  local p = f
  while isUIFrame(p) do
    if isFunc(p.GetName) and p:GetName() == rootName then
      return true
    end
    p = isFunc(p.GetParent) and p:GetParent() or nil
  end
  return false
end

local function isSuperMacroEditBox(f)
  return isUIFrame(f) and getObjectTypeName(f) == "EditBox" and isUnderNamedFrame(f, "SuperMacroFrame")
end

-- ---- hookers ----
local function hookEditBox(e)
  if not isSuperMacroEditBox(e) then return end
  if e._SM_ESC_HOOKED then return end
  if not (isFunc(e.SetScript) and isFunc(e.GetScript)) then return end

  local oldEsc = e:GetScript("OnEscapePressed")
  e:SetScript("OnEscapePressed", function()
    -- In 1.12, 'this' is the frame whose script is running.
    if this and isFunc(this.ClearFocus) then this:ClearFocus() end
    if isFunc(oldEsc) then pcall(oldEsc) end
  end)

  e._SM_ESC_HOOKED = true
end

local function scanAndHookAll()
  if not isFunc(_G.EnumerateFrames) then return end
  local f = nil
  while true do
    f = _G.EnumerateFrames(f)
    if not f then break end
    hookEditBox(f)
  end
end

local function tryHookSuperMacroFrame()
  local SMF = _G.SuperMacroFrame
  if not isUIFrame(SMF) then return end

  -- Defensive pcall-wrap around OnHide (harmless, prevents rare issues).
  if isFunc(SMF.GetScript) and isFunc(SMF.SetScript) then
    local oldHide = SMF:GetScript("OnHide")
    SMF:SetScript("OnHide", function()
      if isFunc(oldHide) then
        local ok, err = pcall(oldHide)
        if not ok and _G.DEFAULT_CHAT_FRAME then
          _G.DEFAULT_CHAT_FRAME:AddMessage("SuperMacro ESC fix: OnHide error: "..tostring(err), 1, 0.3, 0.3)
        end
      end
    end)

    -- When the frame shows (or re-shows), re-scan in case edit boxes are created lazily.
    local oldShow = SMF:GetScript("OnShow")
    SMF:SetScript("OnShow", function()
      if isFunc(oldShow) then pcall(oldShow) end
      scanAndHookAll()
    end)
  end

  -- Initial pass
  scanAndHookAll()
end

-- ---- loader ----
local loader = _G.CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
  -- 1.12 uses global 'event','arg1' in handler scope
  if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and arg1 == "SuperMacro") then
    -- Defer one frame to let SuperMacro build its UI
    this:SetScript("OnUpdate", function()
      pcall(tryHookSuperMacroFrame)
      this:SetScript("OnUpdate", nil)
    end)
  end
end)

-- (Optional) If your SuperMacro build names its editor boxes predictably, you could directly hook by name here.
-- e.g., local eb = _G.SuperMacroEditBox; if eb then hookEditBox(eb) end
