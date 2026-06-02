# ═══════════════════════════════════════════════════════════════════════════
# test_stack.asm — push / pop / swap (Faz 5 yeni komutları) testi
# ───────────────────────────────────────────────────────────────────────────
# $sp = 400 (yığın işaretçisi, word 100 — koddan uzak güvenli bölge).
#
# Akış:
#   swap $t0,$t1  → $t0=22, $t1=11
#   push $t0 (22) → $sp=396, MEM[396]=22
#   push $t1 (11) → $sp=392, MEM[392]=11
#   pop  $t2      → $t2=MEM[392]=11, $sp=396   (LIFO: son itilen ilk çıkar)
#   pop  $t3      → $t3=MEM[396]=22, $sp=400
#
# Beklenen son değerler:
#   $t0=22 $t1=11 $t2=11 $t3=22 $sp=400
# ═══════════════════════════════════════════════════════════════════════════

        loadi $sp, 400          # yığın işaretçisi
        loadi $t0, 11
        loadi $t1, 22

        swap  $t0, $t1          # $t0=22, $t1=11

        push  $t0               # MEM[396]=22, $sp=396
        push  $t1               # MEM[392]=11, $sp=392

        pop   $t2               # $t2=11, $sp=396
        pop   $t3               # $t3=22, $sp=400

HALT:
        j     HALT
