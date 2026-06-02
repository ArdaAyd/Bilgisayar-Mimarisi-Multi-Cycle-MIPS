# ═══════════════════════════════════════════════════════════════════════════
# test_itype.asm — slti / andi / ori / xori testi (Faz 6 — eksik komutlar)
# ───────────────────────────────────────────────────────────────────────────
# Bu 4 standart I-type komut diğer test programlarında hiç kullanılmamıştı.
# PDF: "Her komut için ayrı test senaryosu". Bu test o boşluğu kapatır.
#
# NOT: andi/ori/xori immediate'leri KÜÇÜK POZİTİF seçildi; böylece
#      sign-extend / zero-extend farkı sonucu etkilemez (güvenli).
#
# ── BEKLENEN SON DEĞERLER ──
#   $t0=12  $t1=1   $t2=0   $t3=0   $t4=8   $t5=15  $t6=6
#   $t7=-3  $s0=1   $s1=0
# ═══════════════════════════════════════════════════════════════════════════

        loadi $t0, 12           # 0b1100 — temel operand

        # ── SLTI (set less than immediate, işaretli) ──
        slti  $t1, $t0, 20      # 12 < 20 ? -> 1
        slti  $t2, $t0, 5       # 12 < 5  ? -> 0
        slti  $t3, $t0, 12      # 12 < 12 ? -> 0  (eşitlik küçük değildir)

        # ── ANDI / ORI / XORI (bit-bazlı immediate) ──
        andi  $t4, $t0, 10      # 12 & 10 = 0b1100 & 0b1010 = 0b1000 = 8
        ori   $t5, $t0, 3       # 12 | 3  = 0b1100 | 0b0011 = 0b1111 = 15
        xori  $t6, $t0, 10      # 12 ^ 10 = 0b1100 ^ 0b1010 = 0b0110 = 6

        # ── SLTI negatif operandla (işaretli karşılaştırma kanıtı) ──
        loadi $t7, -3
        slti  $s0, $t7, 0       # -3 < 0  ? -> 1
        slti  $s1, $t7, -5      # -3 < -5 ? -> 0

HALT:
        j     HALT
