# ═══════════════════════════════════════════════════════════════════════════
# test_master.asm — KAPSAMLI "MASTER" TEST (Faz 6)
# ───────────────────────────────────────────────────────────────────────────
# Tek programda TÜM komut tiplerini gerçekçi bir akışta kullanır:
#   - Bellekte 4 elemanlı bir dizi kurar         (loadi, sw)
#   - DÖNGÜ ile toplam + maksimum bulur          (beq, bgt, j, add, lw, addi)
#   - Kalan aritmetik/mantık komutlarını işler   (sub, and, or, xor, slt, mul, addi3)
#   - Sonuçları yığına it/çek ve takasla         (push, pop, swap)
#
# Dizi: [5, 8, 3, 10]  →  toplam = 26, maksimum = 10
#
# ── BEKLENEN SON DEĞERLER ──
#   $t0=200  $t1=3   $t2=16  $t3=16  $t4=212  $t5=10
#   $t6=16   $t7=10
#   $s0=26   $s1=10  $s2=26  $s3=16  $s4=1   $s5=30  $s6=40
#   $t8=26   $t9=10
#   $sp=400
# ═══════════════════════════════════════════════════════════════════════════

        loadi $sp, 400          # yığın işaretçisi (word 100, koddan uzak)

        # ── Belleğe dizi kur: base = byte 200 (word 50) ──
        loadi $t0, 200          # dizi taban adresi
        loadi $t1, 5
        sw    $t1, 0($t0)       # MEM[200] = 5
        loadi $t1, 8
        sw    $t1, 4($t0)       # MEM[204] = 8
        loadi $t1, 3
        sw    $t1, 8($t0)       # MEM[208] = 3
        loadi $t1, 10
        sw    $t1, 12($t0)      # MEM[212] = 10

        # ── Döngü değişkenleri ──
        loadi $s0, 0            # sum = 0
        loadi $s1, 0            # max = 0
        loadi $t2, 0            # i   = 0  (byte offset)
        loadi $t3, 16           # son = 16 (4 eleman * 4 byte)

LOOP:
        beq   $t2, $t3, DONE    # i == 16 ise döngü biter
        add   $t4, $t0, $t2     # addr = base + i
        lw    $t5, 0($t4)       # val  = MEM[addr]
        add   $s0, $s0, $t5     # sum += val
        bgt   $t5, $s1, NEWMAX  # val > max ise yeni maksimum
        j     SKIP
NEWMAX:
        add   $s1, $t5, $zero   # max = val
SKIP:
        addi  $t2, $t2, 4       # i += 4
        j     LOOP

DONE:
        # sum=$s0=26, max=$s1=10 — kalan komutları zorla
        sub   $t6, $s0, $s1     # 26 - 10 = 16
        and   $t7, $s0, $s1     # 26 & 10 = 10
        or    $s2, $s0, $s1     # 26 | 10 = 26
        xor   $s3, $s0, $s1     # 26 ^ 10 = 16
        slt   $s4, $s1, $s0     # 10 < 26 ? -> 1
        loadi $t1, 3
        mul   $s5, $s1, $t1     # 10 * 3 = 30
        addi3 $s6, $s0, $s1, 4  # 26 + 10 + 4 = 40

        # ── Yığın testi ──
        push  $s0              # MEM[396]=26, $sp=396
        push  $s1              # MEM[392]=10, $sp=392
        pop   $t8             # $t8=10, $sp=396  (LIFO: son itilen ilk çıkar)
        pop   $t9             # $t9=26, $sp=400

        swap  $t8, $t9         # $t8=26, $t9=10

HALT:
        j     HALT
