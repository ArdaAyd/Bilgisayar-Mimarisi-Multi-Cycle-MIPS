# ═══════════════════════════════════════════════════════════════════════════
# test_cpu.asm — tam CPU entegrasyon testi
# ───────────────────────────────────────────────────────────────────────────
# Tüm register'lar 0'dan başlar. Her değer loadi ile kurulur.
# Program sonunda beklenen register değerleri (testbench bunları kontrol eder):
#   $t0=5  $t1=7  $t2=12 $t3=2  $t4=5  $t5=7  $t6=2  $t7=1
#   $s0=35 $s1=15 $s2=15 $s3=12 $s4=0  $s5=0  $s6=0  $s7=0
# Program sonsuz döngüde durur (j HALT).
# ═══════════════════════════════════════════════════════════════════════════

        loadi $t0, 5            # $t0 = 5
        loadi $t1, 7            # $t1 = 7

        # ── R-type aritmetik / mantık ──
        add   $t2, $t0, $t1     # 5+7  = 12
        sub   $t3, $t1, $t0     # 7-5  = 2
        and   $t4, $t0, $t1     # 5&7  = 5
        or    $t5, $t0, $t1     # 5|7  = 7
        xor   $t6, $t0, $t1     # 5^7  = 2
        slt   $t7, $t0, $t1     # 5<7  = 1
        mul   $s0, $t0, $t1     # 5*7  = 35

        # ── I-type ve yeni komutlar ──
        addi  $s1, $t0, 10      # 5+10 = 15
        addi3 $s2, $t0, $t1, 3  # 5+7+3 = 15

        # ── Bellek: sw/lw (veri adresi 200 = word 50, kodu ezmez) ──
        sw    $t2, 200($zero)   # MEM[200] = 12
        lw    $s3, 200($zero)   # $s3 = 12

        # ── Branch testleri: alınırsa "bozucu" loadi atlanır, register 0 kalır ──
        beq   $t0, $t0, SKIP1   # 5==5 → alınır
        loadi $s4, 99           # ATLANMALI
SKIP1:
        bne   $t0, $t1, SKIP2   # 5!=7 → alınır
        loadi $s5, 88           # ATLANMALI
SKIP2:
        bgt   $t1, $t0, SKIP3   # 7>5  → alınır
        loadi $s6, 77           # ATLANMALI
SKIP3:
        j     SKIP4             # koşulsuz atlama
        loadi $s7, 66           # ATLANMALI
SKIP4:

HALT:
        j     HALT              # sonsuz döngü (CPU burada "durur")
