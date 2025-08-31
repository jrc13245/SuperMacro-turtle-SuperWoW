-- Vanilla 1.12.1 (Lua 5.0) safe SuperMacro ESC fix that avoids global ToggleGameMenu hooks.

local _G = getfenv(0)

local function GetKBFocus()
  if type(_G.GetCurrentKeyBoardFocus) == "function" then return _G.GetCurrentKeyBoardFocus() end
  if type(_G.GetCurrentKeyboardFocus) == "function" then return _G.GetCurrentKeyboardFocus() end
end

local function IsFrame(obj)
  return type(obj) == "table" and type(obj.GetParent) == "function"
end

local function GetObjectTypeName(f)
  if type(f.GetObjectType) == "function" then
    return f:GetObjectType()
  end
  if type(f.IsObjectType) == "function" then
    if f:IsObjectType("EditBox") == 1 then return "EditBox" end
  end
  return nil
end

local function IsUnderSuperMacroFrame(f)
  local p = f
  while IsFrame(p) do
    if type(p.GetName) == "function" and p:GetName() == "SuperMacroFrame" then
      return true
    end
    p = p:GetParent()
  end
  return false
end

local function IsSuperMacroEditBox(f)
  return IsFrame(f) and GetObjectTypeName(f) == "EditBox" and IsUnderSuperMacroFrame(f)
end

local function HookEditBox(e)
  if not IsSuperMacroEditBox(e) then return end
  if type(e.SetScript) ~= "function" or type(e.GetScript) ~= "function" then return end
  local oldEsc = e:GetScript("OnEscapePressed")
  e:SetScript("OnEscapePressed", function()
    if this and type(this.ClearFocus) == "function" then this:ClearFocus() end
    if type(oldEsc) == "function" then pcall(oldEsc) end
  end)
end

local function HookAllSuperMacroEditBoxes()
  if type(_G.EnumerateFrames) ~= "function" then return end
  local f = nil
  while true do
    f = _G.EnumerateFrames(f)
    if not f then break end
    HookEditBox(f)
  end
end

local function HookSuperMacro()
  local SMF = _G.SuperMacroFrame
  if not IsFrame(SMF) then return end

  -- pcall-wrap OnHide (defensive)
  if type(SMF.GetScript) == "function" and type(SMF.SetScript) == "function" then
    local oldHide = SMF:GetScript("OnHide")
    SMF:SetScript("OnHide", function()
      if type(oldHide) == "function" then
        local ok, err = pcall(oldHide)
        if not ok and _G.DEFAULT_CHAT_FRAME then
          _G.DEFAULT_CHAT_FRAME:AddMessage("DBG: SuperMacro OnHide error: "..tostring(err), 1, 0.3, 0.3)
        end
      end
    end)
    local oldShow = SMF:GetScript("OnShow")
    SMF:SetScript("OnShow", function()
      if type(oldShow) == "function" then pcall(oldShow) end
      HookAllSuperMacroEditBoxes()
    end)
  end

  HookAllSuperMacroEditBoxes()
end

-- Defer until UI is live / SuperMacro is present.
local loader = _G.CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
  if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and arg1 == "SuperMacro") then
    this:SetScript("OnUpdate", function()
      HookSuperMacro()
      this:SetScript("OnUpdate", nil)
    end)
  end
end)
