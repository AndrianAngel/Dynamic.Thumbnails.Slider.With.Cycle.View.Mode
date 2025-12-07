; AutoHotkey v1 Script
#SingleInstance Force

; Global variables
global viewModeIndex := 0
global viewModes := ["LargeThumbs", "Tiles", "Details", "List"]
global guiVisible := false

; --- GUI Setup ---
Gui, +AlwaysOnTop -Caption +ToolWindow
Gui, Color, 0x282D41

hBitmap := Create_sliderthumb_png()
slider := new CustomSlider("y20 w400 h3 BackGround0x454C5F c0x00BFFF Range1-100", 20, hBitmap, true)

; --- Real-time size display ---
Gui, Add, Text, x430 y15 w120 h24 vSizeDisplay Center c0x00BFFF BackgroundTrans, Size: 96px

; --- Add buttons for view modes ---
Gui, Add, Button, x20  y50 w120 h30 gSetLargeThumbs, Large Thumbnails
Gui, Add, Button, x160 y50 w80  h30 gSetTiles, Tiles
Gui, Add, Button, x260 y50 w80  h30 gSetDetails, Details
Gui, Add, Button, x360 y50 w80  h30 gSetList, List
Gui, Add, Button, x460 y50 w80  h30 gSetCycleViewMode, Cycle

Gui, Show, h100 w560 NA
Gui, Hide   ; start hidden

; --- Hotkeys ---
^F12::ToggleGui()
^w::CycleViewModeHotkey()   ; keep Ctrl+W cycle separate

; Emergency exit
Esc::ExitApp

; --- Toggle GUI visibility ---
ToggleGui() {
    global guiVisible
    if (guiVisible) {
        Gui, Hide
        guiVisible := false
    } else {
        Gui, Show, NA
        guiVisible := true
    }
}

; --- Drag handler for GUI ---
DragMove:
    PostMessage, 0xA1, 2,,, A
Return

; --- Button Handlers ---
SetLargeThumbs:
    CycleViewModeButton(1)
Return

SetTiles:
    CycleViewModeButton(2)
Return

SetDetails:
    CycleViewModeButton(3)
Return

SetList:
    CycleViewModeButton(4)
Return

SetCycleViewMode:
    CycleViewModeHotkey()
Return

; --- Cycle via Hotkey ---
CycleViewModeHotkey() {
    global viewModeIndex, viewModes
    viewModeIndex := Mod(viewModeIndex + 1, viewModes.MaxIndex())
    if (viewModeIndex = 0)
        viewModeIndex := viewModes.MaxIndex()
    mode := viewModes[viewModeIndex]
    CycleViewModeApply(mode)
}

; --- Cycle via Button ---
CycleViewModeButton(index) {
    global viewModeIndex, viewModes
    viewModeIndex := index
    mode := viewModes[viewModeIndex]
    CycleViewModeApply(mode)
}

; --- Apply mode to Explorer ---
CycleViewModeApply(mode) {
    for window in ComObjCreate("Shell.Application").Windows {
        try {
            if (window && window.Document) {
                if (mode = "LargeThumbs") {
                    window.Document.CurrentViewMode := 1
                    window.Document.IconSize := 96
                } else if (mode = "Tiles") {
                    window.Document.CurrentViewMode := 6
                } else if (mode = "Details") {
                    window.Document.CurrentViewMode := 4
                } else if (mode = "List") {
                    window.Document.CurrentViewMode := 3
                }
                ShowNotification("View Mode: " mode)
                return
            }
        } catch {
            ; fallback keystrokes
            if (mode = "LargeThumbs")
                Send ^+6
            else if (mode = "Tiles")
                Send ^+2
            else if (mode = "Details")
                Send ^+4
            else if (mode = "List")
                Send ^+3
            ShowNotification("Fallback: " mode)
            return
        }
    }
}

; --- Show notification function ---
ShowNotification(message) {
    static notifGui := ""

    if (notifGui) {
        Gui, %notifGui%:Destroy
    }

    Gui, 99:+AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, 99:Color, 0x1E1E1E
    Gui, 99:Font, s9 c0xE0E0E0, Segoe UI
    Gui, 99:Margin, 15, 8
    Gui, 99:Add, Text, Center, %message%

    SysGet, MonitorWorkArea, MonitorWorkArea
    xPos := MonitorWorkAreaRight - 200
    yPos := MonitorWorkAreaBottom - 80
    Gui, 99:Show, x%xPos% y%yPos% NA

    notifGui := 99
    SetTimer, DestroyNotif, -1500
    Return

    DestroyNotif:
    Gui, 99:Destroy
    Return
}

; --- Custom Slider Class ---
class CustomSlider
{
    __New(Options := "", val := "", hBitmap_thumb := "", ShowTooltip := false) {
        ; Create progress bar - now 3x thicker (h3) and bright sky blue
        Gui, Add, Progress, h3 %Options% hwndHPROG Disabled -E0x20000 c0x00BFFF Background0x00BFFF, % val
        
        ; Create transparent trigger area
        Gui, Add, Text, xp yp-10 h24 wp BackgroundTrans HWNDhpgTrigger
        
        ; Get progress bar position
        GuiControlGet, pg, Pos, %HPROG%
        x := pgX + (pgW * val / 100)
        
        ; Create RED thumb - use Progress control with red color for better visibility
        Gui, Add, Progress, yp x%x% w8 h24 HWNDhBtn c0xFF0000 Background0xFF0000, 100
        
        this.hProg := HPROG
        this.hBtn := hBtn
        this.pgVal := val
        this.ShowTooltip := ShowTooltip
        this.lastVal := val

        fn := this.OnClick.Bind(this)
        GuiControl, +g, %hBtn%, %fn%
        GuiControl, +g, %hpgTrigger%, %fn%
    }

    OnClick() {
        ; Ensure thumb stays on top during interaction
        GuiControl, MoveDraw, % this.hBtn
        GuiControl, Focus, % this.hBtn
        
        hSlider := this.hProg
        pre_CoordModeMouse := A_CoordModeMouse
        CoordMode, Mouse, Relative
        MouseGetPos,,,, ClickedhWnd, 2
        GuiControlGet, SliderLine, %A_Gui%:Pos, % hSlider
        GuiControlGet, sliderVal, %A_Gui%:, %hSlider%
        V := sliderVal

        while (GetKeyState("LButton")) {
            Sleep, 10
            MouseGetPos, XM, YM
            V := Round((XM - SliderLineX) / SliderLineW * 100)
            V := V < 1 ? 1 : V > 100 ? 100 : V
            if (V != this.lastVal) {
                this.lastVal := V
                this.pos := V
                if this.ShowTooltip
                    ToolTip % V
                this.ApplyToExplorer(V)
            }
        }
        if this.ShowTooltip
            ToolTip
        CoordMode, Mouse, %pre_CoordModeMouse%
    }

    ; --- ApplyToExplorer using continuous IconSize ---
    ApplyToExplorer(newValue) {
        size := Round(16 + (newValue / 100) * (256 - 16))
        for window in ComObjCreate("Shell.Application").Windows {
            try {
                if (window && window.Document) {
                    window.Document.CurrentViewMode := 1
                    window.Document.IconSize := size
                    GuiControl,, SizeDisplay, % "Size: " size "px"
                    ShowNotification("Thumbnail size: " size "px")
                    break
                }
            }
        }
    }

    pos {
        set {
            GuiControl,, % this.hProg, % value
            GuiControlGet, pg, Pos, % this.hProg
            x := pgX + (pgW * value / 100)
            GuiControl, MoveDraw, % this.hBtn, x%x%
            this.pgVal := value
        }
        get {
            return this.pgVal
        }
    }
}

; ##################################################################################
; # This #Include file was generated by Image2Include.ahk, you must not change it! #
; ##################################################################################
Create_sliderthumb_png(NewHandle := False) {
Static hBitmap := 0
If (NewHandle)
   hBitmap := 0
If (hBitmap)
   Return hBitmap
VarSetCapacity(B64, 3864 << !!A_IsUnicode)
B64 := "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"
If !DllCall("Crypt32.dll\CryptStringToBinary", "Ptr", &B64, "UInt", 0, "UInt", 0x01, "Ptr", 0, "UIntP", DecLen, "Ptr", 0, "Ptr", 0)
   Return False
VarSetCapacity(Dec, DecLen, 0)
If !DllCall("Crypt32.dll\CryptStringToBinary", "Ptr", &B64, "UInt", 0, "UInt", 0x01, "Ptr", &Dec, "UIntP", DecLen, "Ptr", 0, "Ptr", 0)
   Return False
hData := DllCall("Kernel32.dll\GlobalAlloc", "UInt", 2, "UPtr", DecLen, "UPtr")
pData := DllCall("Kernel32.dll\GlobalLock", "Ptr", hData, "UPtr")
DllCall("Kernel32.dll\RtlMoveMemory", "Ptr", pData, "Ptr", &Dec, "UPtr", DecLen)
DllCall("Kernel32.dll\GlobalUnlock", "Ptr", hData)
DllCall("Ole32.dll\CreateStreamOnHGlobal", "Ptr", hData, "Int", True, "PtrP", pStream)
hGdip := DllCall("Kernel32.dll\LoadLibrary", "Str", "Gdiplus.dll", "UPtr")
VarSetCapacity(SI, 16, 0), NumPut(1, SI, 0, "UChar")
DllCall("Gdiplus.dll\GdiplusStartup", "PtrP", pToken, "Ptr", &SI, "Ptr", 0)
DllCall("Gdiplus.dll\GdipCreateBitmapFromStream",  "Ptr", pStream, "PtrP", pBitmap)
DllCall("Gdiplus.dll\GdipCreateHBITMAPFromBitmap", "Ptr", pBitmap, "PtrP", hBitmap, "UInt", 0)
DllCall("Gdiplus.dll\GdipDisposeImage", "Ptr", pBitmap)
DllCall("Gdiplus.dll\GdiplusShutdown", "Ptr", pToken)
DllCall("Kernel32.dll\FreeLibrary", "Ptr", hGdip)
DllCall(NumGet(NumGet(pStream + 0, 0, "UPtr") + (A_PtrSize * 2), 0, "UPtr"), "Ptr", pStream)
Return hBitmap
}