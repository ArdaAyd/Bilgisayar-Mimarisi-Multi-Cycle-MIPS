# ═══════════════════════════════════════════════════════════════════════════
# test_edge.asm — UÇ DURUM (edge case) TESTİ (Faz 6)
# ───────────────────────────────────────────────────────────────────────────
# Bilerek riskli köşeleri zorlar: negatif sayılar, $0 koruması, işaretli
# karşılaştırma, eşitlikte dallanmama, geriye dallanma, nested stack.
#
# ── BEKLENEN SON DEĞERLER ──
#   $zero=0  (yazma denemesine rağmen)
#   $t0=7   $t1=-5  $t2=1   $t3=0   $t4=3   $t5=10  $t6=-7  $t7=3
#   $s0=-15 $s1=-1  $s2=10  $s3=-11 $s4=-1  $s5=9   $s6=1   $s7=77
#   $t8=0   $t9=5
#   $k0=100 $k1=200 $gp=100 $fp=300 $ra=200
#   $sp=400
# ═══════════════════════════════════════════════════════════════════════════

        loadi $sp, 400

        # ── TEST 1: $zero korumasi ──
        loadi $t0, 7
        addi  $zero, $t0, 5     # $zero=12 OLMAYA calisir, 0 KALMALI

        # ── TEST 2: negatif loadi (16-bit sign-extend) ──
        loadi $t1, -5           # $t1 = -5

        # ── TEST 3: slt isaretli ──
        slt   $t2, $t1, $zero   # -5 < 0  -> 1
        slt   $t3, $zero, $t1   #  0 < -5 -> 0

        # ── TEST 4: sub -> negatif ──
        loadi $t4, 3
        loadi $t5, 10
        sub   $t6, $t4, $t5     # 3 - 10 = -7

        # ── TEST 5: mul negatif ──
        loadi $t7, 3
        mul   $s0, $t1, $t7     # -5 * 3 = -15

        # ── TEST 6: and/or/xor, -1 (0xFFFFFFFF) ile ──
        loadi $s1, -1           # tum bitler 1
        and   $s2, $t5, $s1     # 10 & -1 = 10
        xor   $s3, $t5, $s1     # 10 ^ -1 = ~10 = -11
        or    $s4, $zero, $s1   #  0 | -1 = -1

        # ── TEST 7: addi3 negatif imm (11-bit sign-extend) ──
        addi3 $s5, $t5, $t4, -4 # 10 + 3 + (-4) = 9

        # ── TEST 8a: bgt isaretli, taken (0 > -5) ──
        loadi $s6, 1            # isaret (marker)
        bgt   $zero, $t1, BGT_OK
        loadi $s6, 99           # ATLANMALI -> $s6 = 1 kalir
BGT_OK:
        # ── TEST 8b: bgt esitlikte dallanMAMALI ──
        bgt   $t5, $t5, BGT_BAD # 10 > 10 ? HAYIR
        loadi $s7, 77           # CALISMALI -> $s7 = 77
        j     AFTER_BGT
BGT_BAD:
        loadi $s7, 55           # ATLANMALI
AFTER_BGT:

        # ── TEST 9: geriye dallanma (bne countdown) ──
        loadi $t8, 5            # sayac
        loadi $t9, 0            # kac kez dondu
COUNTDOWN:
        addi  $t8, $t8, -1      # t8 -= 1
        addi  $t9, $t9, 1       # t9 += 1
        bne   $t8, $zero, COUNTDOWN   # GERIYE branch (negatif offset)
        # t8=0, t9=5

        # ── TEST 10: 3-derin nested push/pop (LIFO) ──
        loadi $k0, 100
        loadi $k1, 200
        loadi $gp, 300
        push  $k0              # MEM[396]=100, sp=396
        push  $k1              # MEM[392]=200, sp=392
        push  $gp              # MEM[388]=300, sp=388
        pop   $fp             # $fp=300, sp=392
        pop   $ra            # $ra=200, sp=396
        pop   $gp            # $gp=100, sp=400  ($gp 300->100)

HALT:
        j     HALT
