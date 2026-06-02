# ═══════════════════════════════════════════════════════════════════════════
# test_boundary.asm — SINIR DURUMLARI testi (Faz 6)
# ───────────────────────────────────────────────────────────────────────────
# PDF "Sınır Durumları" başlığının saydığı 3 durumu hedefler:
#   1) Overflow        — 32-bit işaretli taşma (two's complement wraparound)
#   2) Bellek sınırları — belleğin en üst word'ü (word 255 = byte 1020)
#   3) Branch alanı     — ileri/geri dallanma mesafe testi
#
# NOT: loadi 16-bit'tir; 32767'den büyük pozitif sabit yüklenemez, bu yüzden
#      büyük sayılar mul ile üretilir.
#
# ── BEKLENEN SON DEĞERLER ──
#   $t0=30000   $t1=900000000   $t2=1800000000   $t3=-1594967296
#   $t4=1020    $t5=12345       $t6=12345
#   $t7=0       $s0=7
# ═══════════════════════════════════════════════════════════════════════════

        # ── 1) OVERFLOW: 32-bit işaretli taşma ──
        loadi $t0, 30000
        mul   $t1, $t0, $t0     # 30000*30000 = 900,000,000 (sığar)
        add   $t2, $t1, $t1     # 1,800,000,000 (hâlâ pozitif, sığar)
        add   $t3, $t2, $t1     # 2,700,000,000 > 2^31-1 -> TAŞAR
                                # -> -1,594,967,296 (wraparound, exception yok)

        # ── 2) BELLEK SINIRI: en üst word (255) ──
        loadi $t4, 1020         # byte 1020 -> word 255 (belleğin tepesi)
        loadi $t5, 12345
        sw    $t5, 0($t4)       # MEM[1020] = 12345
        lw    $t6, 0($t4)       # geri oku -> $t6 = 12345

        # ── 3) BRANCH ALANI: ileri dallanma (mesafe atla) ──
        loadi $t7, 0
        beq   $t7, $t7, FAR     # her zaman dallan (ileri, birkaç komut atla)
        loadi $s0, 99           # ATLANMALI
        loadi $s0, 88           # ATLANMALI
        loadi $s0, 77           # ATLANMALI
FAR:
        loadi $s0, 7            # $s0 = 7 (branch buraya atladı)

HALT:
        j     HALT
