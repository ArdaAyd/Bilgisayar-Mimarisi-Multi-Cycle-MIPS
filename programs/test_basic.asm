# ─── MIPS Multi-Cycle CPU — Temel Test Programı ───────────────────────────────
# Amaç: Her komutu (standart + 6 yeni) bir kez kullanarak doğrulamak.
# Assembler'ı ve ileride donanımı test etmek için tasarlandı.
#
# Başlangıç durumu (register_file'da sabit):
#   $t0 = 0   (başlangıçta sıfır)
#   $t1 = 5
#   $t2 = 7
# ──────────────────────────────────────────────────────────────────────────────

# ── BÖLÜM 1: Standart R-type komutlar ─────────────────────────────────────────

        add  $t3, $t1, $t2      # $t3 = 5 + 7 = 12
        sub  $t4, $t2, $t1      # $t4 = 7 - 5 = 2
        and  $t5, $t1, $t2      # $t5 = 5 & 7 = 5
        or   $t6, $t1, $t2      # $t6 = 5 | 7 = 7
        xor  $t7, $t1, $t2      # $t7 = 5 ^ 7 = 2
        slt  $s0, $t1, $t2      # $s0 = (5 < 7) ? 1 : 0  →  1

# ── BÖLÜM 2: Standart I-type komutlar ─────────────────────────────────────────

        addi $s1, $t1, 10       # $s1 = 5 + 10 = 15
        slti $s2, $t1, 10       # $s2 = (5 < 10) ? 1 : 0  →  1
        andi $s3, $t2, 0x03     # $s3 = 7 & 3 = 3
        ori  $s4, $t1, 0x08     # $s4 = 5 | 8 = 13
        xori $s5, $t1, 0xFF     # $s5 = 5 ^ 255 = 250

# ── BÖLÜM 3: Bellek erişimi (lw/sw) ──────────────────────────────────────────
# Stack pointer'ı bir adrese konumlandır: $sp = 100 (word adresi 25)

        loadi $sp, 100          # YENİ: $sp = 100  (stack base)
        sw    $t3, 0($sp)       # MEM[100] = 12  (t3 kaydet)
        sw    $t4, 4($sp)       # MEM[104] = 2   (t4 kaydet)
        lw    $a0, 0($sp)       # $a0 = MEM[100] = 12  (geri yükle)
        lw    $a1, 4($sp)       # $a1 = MEM[104] = 2

# ── BÖLÜM 4: LOADI — yeni komut ───────────────────────────────────────────────
# rd = imm16 (donanımda rt alanına yazılır, rs=0)

        loadi $v0, 42           # $v0 = 42
        loadi $v1, -1           # $v1 = -1 (0xFFFFFFFF, sign-extended)

# ── BÖLÜM 5: MUL — yeni komut ────────────────────────────────────────────────
# rd = rs * rt  (davranışsal, 32-bit sonuç)

        mul   $s6, $t1, $t2     # $s6 = 5 * 7 = 35

# ── BÖLÜM 6: ADDI3 — yeni komut ──────────────────────────────────────────────
# rd = rs + rt + imm11 (imm işaretli, -1024..1023)

        addi3 $s7, $t1, $t2, 3 # $s7 = 5 + 7 + 3 = 15
        addi3 $t8, $t3, $t4, -2 # $t8 = 12 + 2 + (-2) = 12

# ── BÖLÜM 7: BGT — yeni komut ────────────────────────────────────────────────
# rs > rt ise dallan

        bgt   $t2, $t1, GT_HEDEF  # 7 > 5 → dallan (atlanmalı değil!)
        addi  $t0, $t0, 99         # BU SATIR ATLANMALI (bgt dallanır)

GT_HEDEF:
        addi  $t0, $t0, 1          # $t0 = 1 (buraya gelmeli)

# ── BÖLÜM 8: BEQ / BNE ───────────────────────────────────────────────────────

        beq   $t1, $t1, EQ_HEDEF   # 5 == 5 → dallan
        addi  $t0, $t0, 99         # BU SATIR ATLANMALI

EQ_HEDEF:
        addi  $t0, $t0, 1          # $t0 = 2

        bne   $t1, $t2, NE_HEDEF   # 5 != 7 → dallan
        addi  $t0, $t0, 99         # BU SATIR ATLANMALI

NE_HEDEF:
        addi  $t0, $t0, 1          # $t0 = 3

# ── BÖLÜM 9: SWAP — yeni komut ───────────────────────────────────────────────
# rs ve rt registerlarını takas eder (2 cycle)

        loadi $t1, 10              # $t1 = 10 (test için yeni değer)
        loadi $t2, 20              # $t2 = 20
        swap  $t1, $t2             # sonra: $t1=20, $t2=10

# ── BÖLÜM 10: PUSH / POP — yeni komutlar ─────────────────────────────────────
# PUSH: $sp -= 4; MEM[$sp] = rs
# POP:  rd = MEM[$sp]; $sp += 4

        loadi $sp, 200             # $sp = 200 (stack tabanı)
        push  $v0                  # MEM[196] = 42, $sp = 196
        push  $s6                  # MEM[192] = 35, $sp = 192
        pop   $t9                  # $t9 = 35, $sp = 196
        pop   $k0                  # $k0 = 42, $sp = 200

# ── BÖLÜM 11: J — koşulsuz jump ──────────────────────────────────────────────

        j     BITIS               # programa sonuna atla

        addi  $t0, $t0, 99        # BU SATIR ATLANMALI

BITIS:
        addi  $t0, $t0, 1         # $t0 = 4 (son)

# ─── PROGRAM SONU ─────────────────────────────────────────────────────────────
# Sonsuz döngü (ModelSim'de simülasyon bu noktada durabilir)
SON:
        j     SON                 # sonsuz döngü
