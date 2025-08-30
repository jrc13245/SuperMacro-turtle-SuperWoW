-- SuperMacro_EscapeFix.lua — Vanilla 1.12.1 (Lua 5.0) safe
-- Integrates into SuperMacro to stop ESC-from-editor crashes.

local _G = getfenv(0)

local function CurrentKBFocus()
  -- Vanilla used GetCurrentKeyBoardFocus; some servers expose both
  if type(_G.GetCurrentKeyBoardFocus) == "function" then
    return _G.GetCurrentKeyBoardFocus()
  end
  if type(_G.GetCurrentKeyboardFocus) == "function" then
    return _G.GetCurrentKeyboardFocus()
  end
end

local function IsFrame(obj)
  return obj and type(obj.IsObjectType) == "function"
end

local function IsUnderSuperMacroFrame(f)
  if not IsFrame(f) then return false end
  local p = f
  while IsFrame(p) do
    if type(p.GetName) == "function" and p:GetName() == "SuperMacroFrame" then
      return true
    end
    p = (type(p.GetParent) == "function") and p:GetParent() or nil
  end
  return false
end

local function IsSuperMacroEditBox(f)
  return IsFrame(f) and f:IsObjectType("EditBox") == 1 and IsUnderSuperMacroFrame(f)
end

-- Guard ToggleGameMenu: if ESC comes while editing in SuperMacro, just clear focus.
local orig_ToggleGameMenu = _G.ToggleGameMenu
_G.ToggleGameMenu = function(...)
  local focus = CurrentKBFocus()
  if IsSuperMacroEditBox(focus) then
    if type(focus.ClearFocus) == "function" then focus:ClearFocus() end
    return
  end
  if type(orig_ToggleGameMenu) == "function" then
    return orig_ToggleGameMenu(unpack(arg))
  end
end

local function HookSuperMacro()
  local SMF = _G.SuperMacroFrame
  if not IsFrame(SMF) then return end

  -- 1) pcall-wrap OnHide so a bad handler won’t crash the client
  if type(SMF.GetScript) == "function" and type(SMF.SetScript) == "function" then
    local oldOnHide = SMF:GetScript("OnHide")
    SMF:SetScript("OnHide", function()
      if type(oldOnHide) == "function" then
        local ok, err = pcall(oldOnHide)
        if not ok and DEFAULT_CHAT_FRAME then
          DEFAULT_CHAT_FRAME:AddMessage("DBG: SuperMacro OnHide error: "..tostring(err), 1, 0.3, 0.3)
        end
      end
    end)
  end

  -- 2) Make all edit boxes inside SuperMacroFrame consume ESC locally
  local function hookEditBox(e)
    if not IsSuperMacroEditBox(e) then return end
    if type(e.SetScript) ~= "function" or type(e.GetScript) ~= "function" then return end
    local oldEsc = e:GetScript("OnEscapePressed")
    e:SetScript("OnEscapePressed", function()
      if this and type(this.ClearFocus) == "function" then this:ClearFocus() end
      if type(oldEsc) == "function" then pcall(oldEsc) end
    end)
  end

  -- Enumerate all frames once SuperMacro is built; Vanilla provides EnumerateFrames
  if type(EnumerateFrames) == "function" then
    local f = nil
    while true do
      f = EnumerateFrames(f)
      if not f then break end
      if IsSuperMacroEditBox(f) then hookEditBox(f) end
    end
  end
end

-- Defer hooks until SuperMacro is loaded and its UI exists
local loader = CreateFrame("Frame")
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
