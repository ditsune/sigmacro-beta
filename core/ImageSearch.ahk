; ============================================================
;  core/ImageSearch.ahk — Image search helpers
;  Region default baca dari COORD, toleransi dari CFG
; ============================================================

FindImage(imagePath, x1, y1, x2, y2, &outX, &outY, tolerances := "") {
    global CFG
    if (tolerances = "")
        tolerances := CFG["img_tolerances"]
    if !FileExist(imagePath) {
        Log("⚠ Image tidak ada: " imagePath)
        return false
    }
    for tol in StrSplit(tolerances, ",") {
        if ImageSearch(&fx, &fy, x1, y1, x2, y2, "*" tol " " imagePath) {
            outX := Integer(fx)
            outY := Integer(fy)
            return true
        }
    }
    return false
}

FindBottomImage(imagePath, x1, y1, x2, y2, &outX, &outY, tolerances := "") {
    global CFG
    if (tolerances = "")
        tolerances := CFG["img_tolerances"]
    if !FileExist(imagePath) {
        Log("⚠ Image tidak ada: " imagePath)
        return false
    }
    found := false
    bestX := 0
    bestY := 0
    for tol in StrSplit(tolerances, ",") {
        top := y1
        Loop {
            if !ImageSearch(&fx, &fy, x1, top, x2, y2, "*" tol " " imagePath)
                break
            if (Integer(fy) > bestY) {
                bestX := Integer(fx)
                bestY := Integer(fy)
                found := true
            }
            top := Integer(fy) + 5
            if (top >= y2)
                break
        }
        if found
            break
    }
    if found {
        outX := bestX
        outY := bestY
    }
    return found
}

WaitForImage(imagePath, x1, y1, x2, y2, timeoutMs := 0, tolerances := "") {
    global CFG
    if (timeoutMs = 0)
        timeoutMs := CFG["tfa_timeout"]
    if (tolerances = "")
        tolerances := CFG["img_tol_fast"]
    elapsed := 0
    Loop {
        if FindImage(imagePath, x1, y1, x2, y2, &fx, &fy, tolerances)
            return true
        Sleep(100)
        elapsed += 100
        if (elapsed >= timeoutMs)
            return false
    }
}

; ── Region helpers (pakai COORD map) ──────────────────────────

FindInRegion(imagePath, &outX, &outY, tolerances := "") {
    global COORD
    return FindImage(imagePath,
        COORD["region_x1"], COORD["region_y1"],
        COORD["region_x2"], COORD["region_y2"],
        &outX, &outY, tolerances)
}

WaitInRegion(imagePath, timeoutMs := 0, tolerances := "") {
    global COORD
    return WaitForImage(imagePath,
        COORD["region_x1"], COORD["region_y1"],
        COORD["region_x2"], COORD["region_y2"],
        timeoutMs, tolerances)
}

CheckIncompatible() {
    global CFG
    return FindImage(A_ScriptDir "\image\incompatible.png",
        CFG["region_incompat_x1"], CFG["region_incompat_y1"],
        CFG["region_incompat_x2"], CFG["region_incompat_y2"],
        &fx, &fy, "30,50,70,90,110,130")
}

WaitForIncompatible(timeoutMs := 3000) {
    elapsed := 0
    Loop {
        if CheckIncompatible()
            return true
        Sleep(16)
        elapsed += 16
        if (elapsed >= timeoutMs)
            return false
    }
}

WaitForTwoStepPage(timeoutMs := 0) {
    global CFG
    if (timeoutMs = 0)
        timeoutMs := CFG["tfa_timeout"]
    elapsed := 0
    Loop {
        if FindImage(A_ScriptDir "\image\twostep_icon.png",
            CFG["region_2fa_x1"], CFG["region_2fa_y1"],
            CFG["region_2fa_x2"], CFG["region_2fa_y2"],
            &fx, &fy, CFG["img_tol_fast"])
            return true
        Sleep(16)
        elapsed += 16
        if (elapsed >= timeoutMs)
            return false
    }
}


FindPasswordLabel(&outX, &outY) {
    global CFG
    return FindBottomImage(A_ScriptDir "\image\label_password.png",
        CFG["region_pwd_x1"], CFG["region_pwd_y1"],
        CFG["region_pwd_x2"], CFG["region_pwd_y2"],
        &outX, &outY)
}

WaitForPasswordLabel(&outX, &outY, timeoutMs := 5000) {
    elapsed := 0
    Loop {
        if FindPasswordLabel(&outX, &outY)
            return true
        Sleep(80)
        elapsed += 80
        if (elapsed >= timeoutMs)
            return false
    }
}

; ── Invalid BC detection ──────────────────────────────────────
CheckInvalidBC() {
    global CFG
    return FindImage(A_ScriptDir "\image\invalid_bc.png",
        CFG["region_invalidbc_x1"], CFG["region_invalidbc_y1"],
        CFG["region_invalidbc_x2"], CFG["region_invalidbc_y2"],
        &fx, &fy, CFG["img_tol_fast"])
}

WaitForInvalidBC(timeoutMs := 2000) {
    elapsed := 0
    Loop {
        if CheckInvalidBC()
            return true
        Sleep(16)
        elapsed += 16
        if (elapsed >= timeoutMs)
            return false
    }
}


; ── Roblox detection ─────────────────────────────────────────
CheckRobloxHome() {
    global CFG
    return FindImage(A_ScriptDir "\image\roblox_home.png",
        CFG["region_robloxhome_x1"], CFG["region_robloxhome_y1"],
        CFG["region_robloxhome_x2"], CFG["region_robloxhome_y2"],
        &fx, &fy, CFG["img_tol_fast"])
    || FindImage(A_ScriptDir "\image\roblox_home_dark.png",
        CFG["region_robloxhome_x1"], CFG["region_robloxhome_y1"],
        CFG["region_robloxhome_x2"], CFG["region_robloxhome_y2"],
        &fx, &fy, CFG["img_tol_fast"])
}

CheckRobloxHome2() {
    global CFG
    return FindImage(A_ScriptDir "\image\roblox_home_dark.png",        ; ← ganti nama file sesuai punyamu
        CFG["region_robloxhome_x1"], CFG["region_robloxhome_y1"],
        CFG["region_robloxhome_x2"], CFG["region_robloxhome_y2"],
        &fx, &fy, CFG["img_tol_fast"])
}

FindRobuxItem(imageName, &outX, &outY) {
    global CFG
    ; FIX: tolerance list dipangkas dari 13 nilai (10..130) jadi 5.
    ; Sebelumnya tiap panggilan bisa sampai 13x ImageSearch (light) +
    ; 13x lagi (dark) = 26 scan per percobaan. Ini bikin:
    ;  1) Pencarian jadi lambat → pas ketemu, halaman/scroll udah
    ;     bergerak lagi duluan (ikut andil di bug "ketemu tapi klik
    ;     meleset").
    ;  2) Rentan numpuk handle GDI kalau dipanggil berkali-kali dalam
    ;     sesi panjang (butuh restart PC baru normal lagi).
    ; 5 nilai ini (dipilih dari rentang yg sama) sudah cukup mewakili
    ; rentang toleransi tanpa bikin scan jadi berat.
    tol := "20,40,70,100,130"
    ; Coba light dulu
    if FindImage(A_ScriptDir "\image\" imageName,
        CFG["region_80robux_x1"], CFG["region_80robux_y1"],
        CFG["region_80robux_x2"], CFG["region_80robux_y2"],
        &outX, &outY, tol)
        return true
    ; Coba dark
    darkName := StrReplace(imageName, ".png", "_dark.png")
    return FindImage(A_ScriptDir "\image\" darkName,
        CFG["region_80robux_x1"], CFG["region_80robux_y1"],
        CFG["region_80robux_x2"], CFG["region_80robux_y2"],
        &outX, &outY, tol)
}

; ── FIX bug "ketemu tapi klik meleset karena masih scroll" ────────
; Cari gambar 2x dengan jeda pendek. Kalau posisi hasil ke-2 beda jauh
; dari hasil ke-1, berarti halaman masih bergerak (inertia scroll) —
; jangan klik dulu, tunggu settle. Kalau posisi sama (±3px), aman diklik.
FindRobuxItemStable(imageName, &outX, &outY, maxWaitMs := 1200) {
    elapsed := 0
    if !FindRobuxItem(imageName, &x1, &y1)
        return false
    Loop {
        Sleep(120)
        elapsed += 120
        if !FindRobuxItem(imageName, &x2, &y2) {
            ; sempat hilang lagi (masih scroll lewat) → anggap belum stabil
            x1 := x2 := y1 := y2 := 0
            if (elapsed >= maxWaitMs)
                return false
            continue
        }
        if (Abs(x2-x1) <= 3 && Abs(y2-y1) <= 3) {
            outX := x2
            outY := y2
            return true
        }
        x1 := x2
        y1 := y2
        if (elapsed >= maxWaitMs) {
            ; timeout tapi masih ketemu → pakai posisi terakhir, better than nothing
            outX := x2
            outY := y2
            return true
        }
    }
}

CheckDontBuy() {
    global CFG
    return FindImage(A_ScriptDir "\image\dont_buy.png",
        CFG["region_dontbuy_x1"], CFG["region_dontbuy_y1"],
        CFG["region_dontbuy_x2"], CFG["region_dontbuy_y2"],
        &fx, &fy, CFG["img_tol_fast"])
}

WaitForDontBuy(timeoutMs := 5000) {
    elapsed := 0
    Loop {
        if CheckDontBuy()
            return true
        Sleep(200)
        elapsed += 200
        if (elapsed >= timeoutMs)
            return false
    }
}