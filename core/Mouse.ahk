; ============================================================
;  core/Mouse.ahk — Human-like mouse movement
;  FIX: Click() harus pakai koordinat eksplisit di AHK v2
;       Click() kosong = klik di posisi mouse saat itu,
;       tapi ada race condition dengan MouseMove speed=0.
;       Solusi: selalu pass x,y ke Click langsung.
; ============================================================

RandInt(lo, hi) {
    return Integer(Round(Random(lo, hi)))
}

RandOff(base, variance) {
    return Integer(Round(base + Random(-variance, variance)))
}

RandSleep(lo, hi) {
    Sleep(RandInt(lo, hi))
}

Delay() {
    global CFG
    RandSleep(CFG["delay_min"], CFG["delay_max"])
}

BezierMove(x1, y1, x2, y2, steps, sleepMs) {
    global CFG

    dist := Sqrt((x2-x1)**2 + (y2-y1)**2)

    ; ── Scale offset proporsional ke jarak ────────────────
    ; Ini fix utama: offset tidak boleh melebihi 25% jarak
    ; Kalau fixed 12-28px tapi jarak cuma 20px → overshoot/muter
    rawOff := RandInt(CFG["bez_offset_min"], CFG["bez_offset_max"])
    maxAllowed := Integer(Round(dist * 0.25))
    if (maxAllowed < 4)
        maxAllowed := 4
    offX := (rawOff > maxAllowed) ? maxAllowed : rawOff
    offY := (rawOff > maxAllowed) ? maxAllowed : rawOff

    ; Midpoint dasar
    midX := Integer(Round((x1+x2)/2))
    midY := Integer(Round((y1+y2)/2))

    ; Control point dengan offset acak
    mx := midX + RandInt(-offX, offX)
    my := midY + RandInt(-offY, offY)

    ; ── KUNCI: clamp control point ke bounding box x1..x2, y1..y2 ──
    ; Ini yang mencegah kurva "muter" — kalau mx/my keluar dari
    ; rentang antara start dan end, bezier bisa bikin loop
    minX := (x1 < x2) ? x1 : x2
    maxX := (x1 > x2) ? x1 : x2
    minY := (y1 < y2) ? y1 : y2
    maxY := (y1 > y2) ? y1 : y2

    ; Beri sedikit ruang agar masih ada lengkungan
    pad := Integer(Round(dist * 0.15))
    mx := Max(minX - pad, Min(maxX + pad, mx))
    my := Max(minY - pad, Min(maxY + pad, my))

    Loop steps {
        t  := A_Index / steps
        ; Jitter hanya di tengah perjalanan (t 0.2–0.8), bukan di ujung
        ; Ini biar gerakan tetap natural tapi endpoint akurat
        jx := (t > 0.2 && t < 0.8) ? RandInt(-1, 1) : 0
        jy := (t > 0.2 && t < 0.8) ? RandInt(-1, 1) : 0
        cx := Integer(Round((1-t)**2 * x1 + 2*(1-t)*t * mx + t**2 * x2)) + jx
        cy := Integer(Round((1-t)**2 * y1 + 2*(1-t)*t * my + t**2 * y2)) + jy
        MouseMove(cx, cy, 0)
        Sleep(sleepMs)
    }
    ; Hard snap ke target — hapus semua accumulated error
    MouseMove(x2, y2, 0)
    ; Settle sebelum klik: app UWP/XAML butuh waktu buat "sadar" cursor
    ; udah pindah (proses hover/hit-test di UI thread-nya) sebelum klik
    ; ditembak, kalau kepepet klik jatuh ke elemen lama.
    ; Dirandom (bukan fixed 120ms) biar gak jadi fingerprint timing yang
    ; kelewat presisi/robotic — manusia juga gak pernah diam persis
    ; sekian ms yang sama tiap kali.
    Sleep(RandInt(90, 150))
}

; ── FIX UTAMA: pass tx/ty langsung ke Click ──────────────────
HumanClick(x, y, variance := 8) {
    global CFG
    MouseGetPos(&sx, &sy)
    tx := RandOff(x, variance)
    ty := RandOff(y, variance)
    BezierMove(Integer(sx), Integer(sy), tx, ty,
               RandInt(CFG["bez_steps_min"], CFG["bez_steps_max"]),
               RandInt(CFG["bez_sleep_min"], CFG["bez_sleep_max"]))
    Sleep(RandInt(CFG["click_pre"], CFG["click_pre"] + 15))
    ; Paksa event hover baru (MouseMove ke posisi identik kadang gak
    ; menghasilkan event baru), sambil dirandom biar gak seragam:
    ; arah nudge (+1/-1) dan jeda antar-step di-random tipis.
    nudgeX := (RandInt(0, 1) = 0) ? tx + 1 : tx - 1
    MouseMove(nudgeX, ty, 0)
    Sleep(RandInt(15, 30))
    MouseMove(tx, ty, 0)
    Sleep(RandInt(15, 30))
    Click()
    Sleep(RandInt(CFG["click_post"], CFG["click_post"] + 25))
}

HumanDoubleClick(x, y, variance := 8) {
    global CFG
    MouseGetPos(&sx, &sy)
    tx := RandOff(x, variance)
    ty := RandOff(y, variance)
    BezierMove(Integer(sx), Integer(sy), tx, ty,
               RandInt(CFG["bez_steps_min"], CFG["bez_steps_max"]),
               RandInt(CFG["bez_sleep_min"], CFG["bez_sleep_max"]))
    Sleep(RandInt(CFG["click_pre"], CFG["click_pre"] + 15))
    ; Sama seperti HumanClick — paksa event hover baru, timing dirandom
    nudgeX := (RandInt(0, 1) = 0) ? tx + 1 : tx - 1
    MouseMove(nudgeX, ty, 0)
    Sleep(RandInt(15, 30))
    MouseMove(tx, ty, 0)
    Sleep(RandInt(15, 30))
    Click(, , , 2)
    Sleep(RandInt(CFG["click_post"], CFG["click_post"] + 25))
}

; DirectClick: tanpa bezier, langsung ke koordinat
; Tetap pakai koordinat eksplisit
DirectClick(x, y) {
    ix := Integer(x)
    iy := Integer(y)
    MouseMove(ix, iy, 0)
    ; FIX: sama, paksa refresh hover + kasih waktu app sadar posisi baru
    Sleep(20)
    MouseMove(ix + 1, iy, 0)
    Sleep(20)
    MouseMove(ix, iy, 0)
    Sleep(100)
    Click()
    Sleep(30)
}

DirectDoubleClick(x, y) {
    ix := Integer(x)
    iy := Integer(y)
    MouseMove(ix, iy, 0)
    Sleep(20)
    MouseMove(ix + 1, iy, 0)
    Sleep(20)
    MouseMove(ix, iy, 0)
    Sleep(100)
    Click(, , , 2)
    Sleep(30)
}
