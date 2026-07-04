; ============================================================
;  Main.ahk  —  Sigmacro v2.1 (Modular Edition, Scrollable Tabs)
;  Requires AHK v2.0+
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

; ── FIX: DPI awareness ──────────────────────────────────────
if !DllCall("SetProcessDpiAwarenessContext", "Ptr", -4, "Int")
    DllCall("SetProcessDPIAware")

CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")
SendMode("Input")

; ── FIX: klik & gerak mouse instan, tanpa animasi Windows default ──
SetDefaultMouseSpeed(0)
SetMouseDelay(-1)
SetControlDelay(-1)
SetWinDelay(-1)

#Include shared\Constants.ahk
#Include shared\Config.ahk
#Include shared\Stats.ahk
#Include shared\Update.ahk
#Include core\Logger.ahk
#Include core\Mouse.ahk
#Include core\ImageSearch.ahk
#Include core\Logic.ahk
#Include ui\SettingsDialog.ahk

if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp()
}

EnsureDefaultConfig()
LoadConfig()
LoadStats()

iconPath := A_MyDocuments "\..\Downloads\OnlyDits\assets\sticker.ico"
if FileExist(iconPath)
    TraySetIcon(iconPath)

global g_IsRunning   := false
global g_TotalAttempts
global g_SuccessCount
global g_ActiveTab   := 1

; ============================================================
;  SCROLLABLE TAB BUILDER
; ============================================================
class ScrollTabBuilder {
    __New(gui, viewportTop := 42, viewportBottom := 358) {
        this.gui         := gui
        this.startY      := viewportTop
        this.viewTop     := viewportTop
        this.viewBottom  := viewportBottom
        this.y           := viewportTop
        this.rowH        := 36
        this.controls    := []
        this.scrollOffset := 0
        this.contentHeight := 0
    }

    _Track(ctrl, x, y, w, h) {
        this.controls.Push({ctrl: ctrl, x: x, y: y, w: w, h: h})
        return ctrl
    }

    Section(label) {
        this.gui.SetFont("s8 c888888 Bold", "Segoe UI")
        lbl := this.gui.Add("Text", "x10 y" this.y " w380 Background" this.gui.BackColor, label)
        this._Track(lbl, 10, this.y, 380, 13)
        sep := this.gui.Add("Text", "x10 y" (this.y+13) " w380 h1 Background" this.gui.BackColor " 0x10")
        this._Track(sep, 10, this.y+13, 380, 1)
        this.y += 20
        return this
    }

    Row(labels, cols := 2) {
        w := (380 - (cols-1)*8) / cols
        btns := []
        for i, label in labels {
            col := Mod(i-1, cols)
            x := Round(10 + col * (w + 8))
            if (i > 1 && col = 0)
                this.y += this.rowH
            this.gui.SetFont("s9 c000000 Norm", "Segoe UI")
            b := this.gui.Add("Button", "x" x " y" this.y " w" Round(w) " h30", label)
            this._Track(b, x, this.y, Round(w), 30)
            btns.Push(b)
        }
        this.y += this.rowH
        return btns
    }

    Finalize() {
        this.contentHeight := this.y - this.startY
        return this
    }

    MaxScroll() => Max(0, this.contentHeight - (this.viewBottom - this.viewTop))

    Scroll(delta) {
        newOffset := this.scrollOffset - delta
        this.scrollOffset := Max(0, Min(this.MaxScroll(), newOffset))
        this.ApplyScroll()
    }

    ApplyScroll() {
        for item in this.controls {
            newY := item.y - this.scrollOffset
            visible := (newY + item.h > this.viewTop) && (newY < this.viewBottom)
            item.ctrl.Visible := visible
            if visible
                item.ctrl.Move(item.x, newY)
        }
    }

    SetVisible(v) {
        if v
            this.ApplyScroll()
        else
            for item in this.controls
                item.ctrl.Visible := false
    }
}

; ============================================================
;  GUI
; ============================================================
global AppGui := Gui("+AlwaysOnTop", "Sigmacro v2.1")
global EditLog, StatsText, LogGroupBox
global TabBtns := []
global TabControls := Map()
global TabBuilders := Map()

AppGui.BackColor := "F0F0F0"

; ── TAB BUTTONS (baris paling atas) ─────────────────────────
tabLabels := ["Website", "Tele", "Backup Code", "Tools"]
tabX      := [10, 105, 200, 295]

AppGui.SetFont("s9 c000000 Norm", "Segoe UI")
loop 4 {
    i   := A_Index
    btn := AppGui.Add("Button", "x" tabX[i] " y10 w92 h24", tabLabels[i])
    btn.OnEvent("Click", TabClick.Bind(i))
    TabBtns.Push(btn)
}

VIEW_TOP    := 42
VIEW_BOTTOM := 358

; ============================================================
;  TAB 1 — WEBSITE
; ============================================================
{
    tb := ScrollTabBuilder(AppGui, VIEW_TOP, VIEW_BOTTOM)
    c := []

    tb.Section("LOGIN (WEB)")
    c.Push(tb.Row(["Login Website", "Clip Login Web"])*)
    c.Push(tb.Row(["Auto Web", "Login di Web"])*)

    tb.Section("ROBUX PURCHASE")
    c.Push(tb.Row(["Buy 80R", "Buy 500R"])*)
    c.Push(tb.Row(["Buy 1000R", "Buy 2000R"])*)

    tb.Section("SHEET")
    c.Push(tb.Row(["Done Web", "Belom Web"])*)

    tb.Section("TOOLS")
    c.Push(tb.Row(["↺ Reload", "✕ Exit", "⚙ Settings"], 3)*)

    tb.Finalize()

    c[1].OnEvent("Click",  (*) => GuiAction("Login Website", DoLoginWebsite))
    c[2].OnEvent("Click",  (*) => GuiAction("Clip Login Web", DoLoginClipboardWeb))
    c[3].OnEvent("Click",  (*) => GuiAction("Auto Web", AutoWeb))
    c[4].OnEvent("Click",  (*) => GuiAction("Login di Web", LoginWebRoblox))
    c[5].OnEvent("Click",  (*) => GuiAction("Buy 80 Robux", Beli80Robux))
    c[6].OnEvent("Click", (*) => GuiAction("Buy 500 Robux", Beli500Robux))
    c[7].OnEvent("Click", (*) => GuiAction("Buy 1000 Robux", Beli1000Robux))
    c[8].OnEvent("Click", (*) => GuiAction("Buy 2000 Robux", Beli2000Robux))
    c[9].OnEvent("Click", (*) => SheetDoneWeb())
    c[10].OnEvent("Click", (*) => SheetBelomWeb())
    c[11].OnEvent("Click", (*) => Reload())
    c[12].OnEvent("Click", (*) => ExitApp())
    c[13].OnEvent("Click", (*) => ShowSettingsDialog())

    TabControls[1] := c
    TabBuilders[1] := tb
}

; ============================================================
;  TAB 2 — TELE
; ============================================================
{
    tb := ScrollTabBuilder(AppGui, VIEW_TOP, VIEW_BOTTOM)
    c := []

    tb.Section("LOGIN (TELE)")
    c.Push(tb.Row(["Auto Tele", "Clip Login Tele"])*)

    tb.Section("ROBUX PURCHASE")
    c.Push(tb.Row(["Buy 80R", "Buy 500R"])*)
    c.Push(tb.Row(["Buy 1000R", "Buy 2000R"])*)

    tb.Section("SHEET")
    c.Push(tb.Row(["Done Tele", "Belom Tele"])*)

    tb.Section("TOOLS")
    c.Push(tb.Row(["↺ Reload", "✕ Exit", "⚙ Settings"], 3)*)

    tb.Finalize()

    c[1].OnEvent("Click",  (*) => GuiAction("Auto Tele", AutoTele))
    c[2].OnEvent("Click",  (*) => GuiAction("Clip Login Tele", DoLoginClipboard))
    c[3].OnEvent("Click",  (*) => GuiAction("Buy 80 Robux", Beli80Robux))
    c[4].OnEvent("Click",  (*) => GuiAction("Buy 500 Robux", Beli500Robux))
    c[5].OnEvent("Click",  (*) => GuiAction("Buy 1000 Robux", Beli1000Robux))
    c[6].OnEvent("Click", (*) => GuiAction("Buy 2000 Robux", Beli2000Robux))
    c[7].OnEvent("Click", (*) => SheetDoneTele())
    c[8].OnEvent("Click", (*) => SheetBelomTele())
    c[9].OnEvent("Click", (*) => Reload())
    c[10].OnEvent("Click", (*) => ExitApp())
    c[11].OnEvent("Click", (*) => ShowSettingsDialog())

    TabControls[2] := c
    TabBuilders[2] := tb
}

; ============================================================
;  TAB 3 — BACKUP CODE
; ============================================================
{
    tb := ScrollTabBuilder(AppGui, VIEW_TOP, VIEW_BOTTOM)
    c := []

    tb.Section("BACKUP CODE (TELE)")
    c.Push(tb.Row(["BC Email", "BC Retry"])*)
    c.Push(tb.Row(["BC Authen Tele", "Copy BC"])*)

    tb.Section("BACKUP CODE (WEB)")
    c.Push(tb.Row(["BC Email Web", "BC Retry Web"])*)
    c.Push(tb.Row(["BC Authen Web", "Copy BC Web"])*)

    tb.Section("TOOLS")
    c.Push(tb.Row(["↺ Reload", "✕ Exit", "⚙ Settings"], 3)*)

    tb.Finalize()

    c[1].OnEvent("Click",  (*) => GuiAction("BC Email Tele", DoProsesBC1))
    c[2].OnEvent("Click",  (*) => GuiAction("BC Retry Tele", BCWithIncompat))
    c[3].OnEvent("Click",  (*) => GuiAction("BC Authen Tele", BCAuthen))
    c[4].OnEvent("Click",  (*) => GuiAction("Copy BC Tele", CopyBackupCodes))
    c[5].OnEvent("Click",  (*) => GuiAction("BC Email Web", DoProsesBC1Web))
    c[6].OnEvent("Click",  (*) => GuiAction("BC Retry Web", BCWithIncompatWeb))
    c[7].OnEvent("Click",  (*) => GuiAction("BC Authen Web", BCAuthenWeb))
    c[8].OnEvent("Click", (*) => GuiAction("Copy BC Web", CopyBCWebsite))
    c[9].OnEvent("Click", (*) => Reload())
    c[10].OnEvent("Click", (*) => ExitApp())
    c[11].OnEvent("Click", (*) => ShowSettingsDialog())

    TabControls[3] := c
    TabBuilders[3] := tb
}

; ============================================================
;  TAB 4 — TOOLS
; ============================================================
{
    tb := ScrollTabBuilder(AppGui, VIEW_TOP, VIEW_BOTTOM)
    c := []

    tb.Section("ROBUX PURCHASE")
    c.Push(tb.Row(["Buy 80R", "Buy 500R"])*)
    c.Push(tb.Row(["Buy 1000R", "Buy 2000R"])*)

    tb.Section("SHEET TELE")
    c.Push(tb.Row(["Done Tele", "Belom Tele"])*)

    tb.Section("SHEET WEB")
    c.Push(tb.Row(["Done Web", "Belom Web"])*)

    tb.Section("DEBUG")
    c.Push(tb.Row(["Mouse Pos", "Find 2FA", "Win Pos", "Incompat"], 4)*)

    tb.Section("TOOLS")
    c.Push(tb.Row(["↺ Reload", "✕ Exit", "⏸ Pause", "⚙ Settings"], 4)*)

    tb.Finalize()

    c[1].OnEvent("Click",  (*) => GuiAction("Buy 80 Robux", Beli80Robux))
    c[2].OnEvent("Click",  (*) => GuiAction("Buy 500 Robux", Beli500Robux))
    c[3].OnEvent("Click",  (*) => GuiAction("Buy 1000 Robux", Beli1000Robux))
    c[4].OnEvent("Click",  (*) => GuiAction("Buy 2000 Robux", Beli2000Robux))
    c[5].OnEvent("Click", (*) => SheetDoneTele())
    c[6].OnEvent("Click", (*) => SheetBelomTele())
    c[7].OnEvent("Click", (*) => SheetDoneWeb())
    c[8].OnEvent("Click", (*) => SheetBelomWeb())
    c[9].OnEvent("Click",  (*) => ShowMousePos())
    c[10].OnEvent("Click", (*) => DebugFind2FA())
    c[11].OnEvent("Click", (*) => DebugWinPos())
    c[12].OnEvent("Click", (*) => MsgBox(CheckIncompatible() ? "Incompatible KEDETECT" : "Tidak kedetect", "Debug"))
    c[13].OnEvent("Click",  (*) => Reload())
    c[14].OnEvent("Click",  (*) => ExitApp())
    c[15].OnEvent("Click",  (*) => TogglePause())
    c[16].OnEvent("Click",  (*) => ShowSettingsDialog())


    TabControls[4] := c
    TabBuilders[4] := tb
}

; ── LOG (satu-satunya GroupBox LOG, status terintegrasi di title) ──
AppGui.SetFont("s9 c444444 Bold", "Segoe UI")
LogGroupBox := AppGui.Add("GroupBox", "x10 y363 w380 h90 vLogGroupBox", "LOG  —  ● Ready")

AppGui.SetFont("s8 c222222 Norm", "Consolas")
EditLog := AppGui.Add("Edit", "x20 y381 w362 h62 vEditLog ReadOnly -VScroll")

; ── FOOTER ─────────────────────────────────────────────────
AppGui.SetFont("s7 c888888 Norm", "Segoe UI")
StatsText := AppGui.Add("Text", "x12 y461 w220 vStatsText BackgroundTrans",
    "Sessions: 0 success / 0 total  (0%)")

AppGui.SetFont("s7 cAAAAAA Norm", "Segoe UI")
AppGui.Add("Text", "x190 y461 w200 BackgroundTrans Right",
    "Ctrl+B Reload | Ctrl+Esc Exit | Ctrl+F12 Pause")

AppGui.OnEvent("Close", (*) => ExitApp())

; ── Tampilkan hanya tab 1 saat startup ──────────────────────
loop 4 {
    if (A_Index != 1)
        TabBuilders[A_Index].SetVisible(false)
    else
        TabBuilders[A_Index].SetVisible(true)
}
UpdateTabButtonStyle(1)

; ============================================================
;  TAB SWITCHING
; ============================================================
TabClick(tabIndex, *) {
    SwitchTab(tabIndex)
}

SwitchTab(tabIndex) {
    global g_ActiveTab, TabBuilders
    TabBuilders[g_ActiveTab].SetVisible(false)
    TabBuilders[tabIndex].SetVisible(true)
    g_ActiveTab := tabIndex
    UpdateTabButtonStyle(tabIndex)
}

; Bold-kan tombol tab yang lagi aktif, normal-kan yang lain
UpdateTabButtonStyle(activeIndex) {
    global TabBtns
    for i, btn in TabBtns {
        if (i = activeIndex)
            btn.SetFont("s9 c000000 Bold", "Segoe UI")
        else
            btn.SetFont("s9 c000000 Norm", "Segoe UI")
    }
}

; ============================================================
;  MOUSE WHEEL SCROLL
; ============================================================
OnMessage(0x020A, WM_MouseWheel)

WM_MouseWheel(wParam, lParam, msg, hwnd) {
    global g_ActiveTab, TabBuilders
    delta := (wParam >> 16) & 0xFFFF
    delta := delta > 32767 ? delta - 65536 : delta
    step := (delta > 0) ? 24 : -24
    TabBuilders[g_ActiveTab].Scroll(step)
}

; ============================================================
;  START
; ============================================================
SetLogCallback(UILog)
EnableFileLog(false)
UpdateStats()
AppGui.Show("x700 y719 w400 h480")
UILog("[" FormatTime(, "HH:mm:ss") "] Hotkeys enabled — Sigmacro v2.1 ready")

SetTimer(() => CheckForUpdate(true), -3000)

; ── HOTKEYS ────────────────────────────────────────────────
^!u:: HotkeyAction("Login Clipboard",  DoLoginClipboard)
^!p:: HotkeyAction("PW Tele",          PwdThenBC)
^!o:: HotkeyAction("BC Email",         DoProsesBC1)
^!e:: HotkeyAction("BC Retry",         BCWithIncompat)
^!k:: HotkeyAction("BC Authen",        BCAuthen)
^!i:: HotkeyAction("Copy BC",          CopyBackupCodes)
^!+t:: HotkeyAction("Auto Tele",        AutoTele)

^!+u:: HotkeyAction("Login Clipboard Web", DoLoginClipboardWeb)
^!m:: HotkeyAction("Login Website",        DoLoginWebsite)
^!q:: HotkeyAction("PW Web",               PastePwClipboard)
^!+o:: HotkeyAction("BC Email Web",        DoProsesBC1Web)
^!+e:: HotkeyAction("BC Retry Web",        BCWithIncompatWeb)
^!+k:: HotkeyAction("BC Authen Web",       BCAuthenWeb)
^!1:: HotkeyAction("Copy BC Web",          CopyBCWebsite)

^!r:: HotkeyAction("Buy 80 Robux",   Beli80Robux)
^!5:: HotkeyAction("Buy 500 Robux",  Beli500Robux)
^!2:: HotkeyAction("Buy 1000 Robux", Beli1000Robux)
^!3:: HotkeyAction("Buy 2000 Robux", Beli2000Robux)
^+l:: HotkeyAction("Login di Web", LoginWebRoblox)
^+w:: HotkeyAction("Auto Web", AutoWeb)

#!e:: HotkeyAction("Sheet Done", SheetDoneTele)
#!q:: HotkeyAction("Sheet Belom ", SheetBelomTele)
#!d:: HotkeyAction("Sheet Done Web", SheetDoneWeb)
#!s:: HotkeyAction("Sheet Belom Web", SheetBelomWeb)

^k:: PutusXbox()
^l:: LogoutRoblox()

F12:: Reload()
^Esc:: ExitApp()
^B:: TogglePause()

^!j:: ShowMousePos()
^!t:: DebugFind2FA()
^!y:: DebugWinPos()
^!0:: DebugIncompatible()
^j:: DebugCoorPixel()

PrintScreen:: HotkeyAction("Screenshot", CaptureScreenshotRegion)

; ============================================================
;  PAUSE
; ============================================================
global _paused := false

TogglePause() {
    global _paused
    _paused := !_paused
    if _paused {
        UpdateStatus("Paused")
        UILog("[" FormatTime(, "HH:mm:ss") "] [PAUSE] Script paused")
        Pause(true)
    } else {
        UpdateStatus("Ready")
        UILog("[" FormatTime(, "HH:mm:ss") "] [RESUME] Script resumed")
        Pause(false)
    }
}

; ============================================================
;  DEBUG
; ============================================================
ShowMousePos() {
    MouseGetPos(&mx, &my)
    UILog("[DEBUG] Mouse: " mx ", " my)
    MsgBox("Posisi Mouse: " mx ", " my, "Debug")
}

DebugFind2FA() {
    if WaitForTwoStepPage(3000) {
        UILog("[DEBUG] 2FA terdeteksi!")
        MsgBox("2FA kedetect!", "Find 2FA")
    } else {
        UILog("[DEBUG] 2FA tidak terdeteksi")
        MsgBox("2FA TIDAK kedetect", "Find 2FA")
    }
}

DebugWinPos() {
    WinGetPos(&tx, &ty, &tw, &th, "A")
    title := WinGetTitle("A")
    UILog("[DEBUG] Window: " SubStr(title, 1, 30) " | " tw "x" th)
    MsgBox("Window: " title "`nX: " tx " Y: " ty " W: " tw " H: " th, "Window Pos")
}

DebugCoorPixel() {
    try {
        MouseGetPos(&mx, &my)
        col := PixelGetColor(mx, my, "RGB")
        hex := Format("0x{:06X}", col)
        UILog("[PIXEL] x=" mx " y=" my " color=" hex)
        MsgBox("X: " mx "`nY: " my "`nColor: " hex, "PixelGetColor Debug")
        A_Clipboard := hex
    } catch as e {
        UILog("[PIXEL] ERROR: " e.Message)
        MsgBox("Gagal ambil warna pixel: " e.Message, "PixelGetColor Debug", "Icon!")
    }
}

DebugIncompatible() {
    MsgBox(CheckIncompatible() ? "Incompatible KEDETECT" : "Tidak kedetect", "Debug")
}

; ============================================================
;  UI HELPERS
; ============================================================
GuiAction(name, fn) {
    global g_IsRunning
    if (g_IsRunning)
        return
    g_IsRunning := true
    UpdateStatus("Running")
    UILog("[" FormatTime(, "HH:mm:ss") "] [START] " name)
    success := false
    try {
        ; FIX: sebelumnya "success" cuma dicek dari ada/gaknya exception,
        ; return value fn (misal BeliRobux() yang return false kalau
        ; item gak ketemu) gak pernah dicek -- kegagalan logis (bukan
        ; error) tetap kehitung SUKSES di statistik.
        ; Sekarang: kalau fn balikin nilai eksplisit falsy (false/0),
        ; itu dihitung gagal. Kalau fn gak return apa-apa (kosong),
        ; tetap dianggap sukses seperti sebelumnya.
        ret := fn.Call()
        success := (ret != "" && !ret) ? false : true
        UILog("[" FormatTime(, "HH:mm:ss") "] [" (success ? "OK" : "FAIL") "] " name
            (success ? " selesai" : " gagal (tidak ditemukan/tidak berhasil)"))
        UpdateStatus(success ? "Ready" : "Error")
        if !success
            Sleep(1000)
    } catch as e {
        UILog("[" FormatTime(, "HH:mm:ss") "] [ERROR] " e.Message)
        UpdateStatus("Error")
        Sleep(2000)
        UpdateStatus("Ready")
    }
    RecordSession(success)
    g_IsRunning := false
}

HotkeyAction(name, fn) {
    global g_IsRunning
    if (g_IsRunning)
        return
    g_IsRunning := true
    UpdateStatus("Running")
    UILog("[" FormatTime(, "HH:mm:ss") "] [START] " name)
    success := false
    try {
        ; FIX: sebelumnya "success" cuma dicek dari ada/gaknya exception,
        ; return value fn (misal BeliRobux() yang return false kalau
        ; item gak ketemu) gak pernah dicek -- kegagalan logis (bukan
        ; error) tetap kehitung SUKSES di statistik.
        ; Sekarang: kalau fn balikin nilai eksplisit falsy (false/0),
        ; itu dihitung gagal. Kalau fn gak return apa-apa (kosong),
        ; tetap dianggap sukses seperti sebelumnya.
        ret := fn.Call()
        success := (ret != "" && !ret) ? false : true
        UILog("[" FormatTime(, "HH:mm:ss") "] [" (success ? "OK" : "FAIL") "] " name
            (success ? " selesai" : " gagal (tidak ditemukan/tidak berhasil)"))
        UpdateStatus(success ? "Ready" : "Error")
        if !success
            Sleep(1000)
    } catch as e {
        UILog("[" FormatTime(, "HH:mm:ss") "] [ERROR] " e.Message)
        UpdateStatus("Error")
        Sleep(2000)
        UpdateStatus("Ready")
    }
    RecordSession(success)
    g_IsRunning := false
}

UpdateStatus(status) {
    global LogGroupBox
    if (status = "Running")
        LogGroupBox.Text := "LOG  —  ● Running"
    else if (status = "Error")
        LogGroupBox.Text := "LOG  —  ● Error"
    else if (status = "Paused")
        LogGroupBox.Text := "LOG  —  ● Paused"
    else
        LogGroupBox.Text := "LOG  —  ● Ready"
}

UILog(line) {
    current := EditLog.Value
    newText  := current . (current = "" ? "" : "`n") . line
    EditLog.Value := newText
    SendMessage(0x115, 7, 0, EditLog)
}

UpdateStats() {
    global g_SuccessCount, g_TotalAttempts
    StatsText.Text := "Sessions: " g_SuccessCount " success / " g_TotalAttempts " total"
        . "  (" GetSuccessRate() ")"
}
