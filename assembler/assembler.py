#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MIPS Multi-Cycle CPU — İki Geçişli Assembler
=============================================
Desteklenen komutlar:
  Standart: add, sub, and, or, xor, slt, addi, slti, andi, ori, xori,
            lw, sw, beq, bne, j
  Yeni (6 adet): addi3, mul, swap, loadi, bgt, push, pop

Çıktı: ModelSim $readmemh formatında .hex dosyası
       Her satır → bir 32-bit kelime (8 hex karakter)

Kullanım:
  python3 assembler.py program.asm          → program.hex üretir
  python3 assembler.py program.asm -v       → detaylı (verbose) çıktı
"""

import sys
import re

# ─── REGISTER ALIASLAR ────────────────────────────────────────────────────────
# MIPS mimarisinde 32 register var; hem $0..$31 hem de isimle yazılabilir.

REG_ALIASES = {
    'zero': 0,  'at': 1,  'v0': 2,  'v1': 3,
    'a0':   4,  'a1': 5,  'a2': 6,  'a3': 7,
    't0':   8,  't1': 9,  't2': 10, 't3': 11,
    't4':  12,  't5': 13, 't6': 14, 't7': 15,
    's0':  16,  's1': 17, 's2': 18, 's3': 19,
    's4':  20,  's5': 21, 's6': 22, 's7': 23,
    't8':  24,  't9': 25, 'k0': 26, 'k1': 27,
    'gp':  28,  'sp': 29, 'fp': 30, 'ra': 31,
}

# ─── ISA OPCODE TABLOSU (TEK KAYNAK NOKTA) ────────────────────────────────────
# Bu tablo donanım ile assembler arasındaki sözleşme.
# VHDL control_unit ve alu_control de BU değerleri kullanmalı.

# R-type komutlar: opcode her zaman 0x00, funct alanı komutu belirler
R_FUNCT = {
    'add':  0x20,   # 0b100000
    'sub':  0x22,   # 0b100010
    'and':  0x24,   # 0b100100
    'or':   0x25,   # 0b100101
    'xor':  0x26,   # 0b100110
    'slt':  0x2a,   # 0b101010
    # ── YENİ R-type komutlar ──
    'mul':  0x2c,   # 0b101100 — rd = rs * rt (davranışsal)
    'swap': 0x2d,   # 0b101101 — rs ↔ rt (2 cycle, 2 register yazımı)
}

# I-type komutlar: opcode alan komutu belirler
I_OPCODE = {
    'addi': 0x08,   # 0b001000
    'slti': 0x0a,   # 0b001010
    'andi': 0x0c,   # 0b001100
    'ori':  0x0d,   # 0b001101
    'xori': 0x0e,   # 0b001110
    'lw':   0x23,   # 0b100011
    'sw':   0x2b,   # 0b101011
    'beq':  0x04,   # 0b000100
    'bne':  0x05,   # 0b000101
    # ── YENİ I-type benzeri komutlar ──
    'loadi': 0x11,  # 0b010001 — rd = imm16 (rs=0, hedef rt alanında)
    'bgt':   0x12,  # 0b010010 — rs > rt ise dallan
    'push':  0x13,  # 0b010011 — $sp-=4; MEM[$sp]=rs
    'pop':   0x14,  # 0b010100 — rd=MEM[$sp]; $sp+=4 (hedef rt alanında)
}

# J-type komutlar
J_OPCODE = {
    'j': 0x02,      # 0b000010
}

# ADDI3 özel format: op=0x10 | rs(5) | rt(5) | rd(5) | imm(11, işaretli)
ADDI3_OP = 0x10     # 0b010000  — rd = rs + rt + imm

# ─── YARDIMCI FONKSİYONLAR ────────────────────────────────────────────────────

def parse_reg(s):
    """
    Register ifadesini sayıya çevirir.
    '$t0' → 8, '$29' → 29, '$sp' → 29
    """
    s = s.strip()
    if s.startswith('$'):
        s = s[1:]
    if s in REG_ALIASES:
        return REG_ALIASES[s]
    try:
        n = int(s)
        if 0 <= n <= 31:
            return n
        raise ValueError(f"Register numarası 0-31 arasında olmalı, alınan: {n}")
    except ValueError:
        raise ValueError(f"Geçersiz register: '${s}'")


def parse_imm(s):
    """
    Anlık (immediate) değeri parse eder.
    Desteklenen: decimal (42, -5), hex (0xFF, -0x10)
    """
    s = s.strip()
    try:
        if s.startswith('-0x') or s.startswith('-0X'):
            return -int(s[1:], 16)
        if s.startswith('0x') or s.startswith('0X'):
            return int(s, 16)
        return int(s)
    except ValueError:
        raise ValueError(f"Geçersiz anlık değer: '{s}'")


def to_unsigned(val, bits):
    """
    İşaretli tamsayıyı n-bit two's complement unsigned'a çevirir.
    Örnek: to_unsigned(-1, 16) → 0xFFFF
    """
    mask = (1 << bits) - 1
    return val & mask


def check_signed_range(val, bits, label=""):
    """İşaretli değerin n-bit'e sığıp sığmadığını kontrol eder."""
    lo = -(1 << (bits - 1))
    hi =  (1 << (bits - 1)) - 1
    if not (lo <= val <= hi):
        raise ValueError(
            f"Anlık değer {val} {bits}-bit işaretli alana sığmıyor "
            f"(aralık: {lo}..{hi}){' @ ' + label if label else ''}"
        )


def parse_mem_operand(s):
    """
    Bellek erişim operandını parse eder.
    '100($t0)' → (100, '$t0')
    '-4($sp)' → (-4, '$sp')
    """
    m = re.match(r'^(-?(?:0x[0-9a-fA-F]+|\d+))\((\$\w+)\)$', s.strip())
    if not m:
        raise ValueError(
            f"Bellek operand formatı hatalı: '{s}'\n"
            f"Beklenen format: 'offset($register)' örn. '4($sp)'"
        )
    return parse_imm(m.group(1)), m.group(2)


def strip_comment(line):
    """Satırdaki # yorumunu ve baştaki/sondaki boşlukları temizler."""
    idx = line.find('#')
    if idx != -1:
        line = line[:idx]
    return line.strip()


def tokenize(line):
    """
    Assembly satırını token listesine çevirir.
    'add $t0, $t1, $t2' → ['add', '$t0', '$t1', '$t2']
    """
    line = line.replace(',', ' ')
    return line.split()

# ─── KOMUT KODLAYICILAR ───────────────────────────────────────────────────────

def encode_r(rs, rt, rd, shamt, funct):
    """
    R-type: op=0(6) | rs(5) | rt(5) | rd(5) | shamt(5) | funct(6)
    """
    return (0 << 26 | (rs & 0x1F) << 21 | (rt & 0x1F) << 16 |
            (rd & 0x1F) << 11 | (shamt & 0x1F) << 6 | (funct & 0x3F))


def encode_i(op, rs, rt, imm):
    """
    I-type: op(6) | rs(5) | rt(5) | imm(16, işaretli)
    """
    return ((op & 0x3F) << 26 | (rs & 0x1F) << 21 | (rt & 0x1F) << 16 |
            to_unsigned(imm, 16))


def encode_j(op, word_addr):
    """
    J-type: op(6) | address(26)
    address: hedef byte adresinin bit[27:2]'si yani (addr >> 2) & 0x3FFFFFF
    """
    return ((op & 0x3F) << 26 | (word_addr & 0x3FFFFFF))


def encode_addi3(rs, rt, rd, imm):
    """
    ADDI3 özel format: op=0x10(6) | rs(5) | rt(5) | rd(5) | imm(11, işaretli)
    rd = rs + rt + imm
    """
    check_signed_range(imm, 11, "addi3 imm")
    return ((ADDI3_OP & 0x3F) << 26 | (rs & 0x1F) << 21 | (rt & 0x1F) << 16 |
            (rd & 0x1F) << 11 | to_unsigned(imm, 11))

# ─── ANA ASSEMBLER SINIFI ─────────────────────────────────────────────────────

class Assembler:
    def __init__(self, verbose=False):
        self.verbose = verbose
        self.label_table = {}    # label → byte adresi
        self.instructions = []   # (satır_no, byte_addr, token_listesi)

    def log(self, msg):
        if self.verbose:
            print(msg)

    # ── 1. GEÇİŞ: Label topla ─────────────────────────────────────────────────
    def pass1(self, lines):
        """
        Her satırı tarar:
        - Yorum ve boş satırları atlar
        - 'LABEL:' gördüğünde label_table'a yazar
        - Komut satırlarını self.instructions'a ekler
        Byte adresi her komuttan sonra +4 artar (32-bit = 4 byte).
        """
        byte_addr = 0
        for lineno, raw in enumerate(lines, start=1):
            line = strip_comment(raw)
            if not line:
                continue

            # Label kontrolü: 'LOOP:' veya 'LOOP: add $t0, $t1, $t2'
            if ':' in line:
                label_part, _, rest = line.partition(':')
                label = label_part.strip()
                if label and re.match(r'^[A-Za-z_]\w*$', label):
                    if label in self.label_table:
                        raise SyntaxError(
                            f"Satır {lineno}: '{label}' etiketi zaten tanımlı "
                            f"(önceki: 0x{self.label_table[label]:08x})"
                        )
                    self.label_table[label] = byte_addr
                    self.log(f"  LABEL: {label} → 0x{byte_addr:08x}")
                    line = rest.strip()  # etiketten sonraki kısmı al
                    if not line:
                        continue

            tokens = tokenize(line)
            if not tokens:
                continue

            self.instructions.append((lineno, byte_addr, tokens))
            byte_addr += 4  # Her komut 4 byte

        self.log(f"\n1. Geçiş tamamlandı: {len(self.instructions)} komut, "
                 f"{len(self.label_table)} etiket\n")

    # ── 2. GEÇİŞ: Komutları kodla ─────────────────────────────────────────────
    def pass2(self):
        """
        Her komutu 32-bit makine koduna çevirir.
        Branch/jump için label_table'dan adres alır.
        """
        machine_words = []

        for lineno, pc, tokens in self.instructions:
            mnemonic = tokens[0].lower()
            args = tokens[1:]

            try:
                word = self._encode_instruction(mnemonic, args, pc, lineno)
            except (ValueError, IndexError) as e:
                raise SyntaxError(f"Satır {lineno}: {e}")

            machine_words.append((pc, word))
            self.log(f"  0x{pc:08x}: {' '.join(tokens):<30s} → 0x{word:08x}")

        return machine_words

    def _encode_instruction(self, mnemonic, args, pc, lineno):
        """Tek bir komutu kodlar; hata mesajı için lineno kullanır."""

        # ── R-type: add, sub, and, or, xor, slt ──────────────────────────────
        if mnemonic in R_FUNCT and mnemonic not in ('mul', 'swap'):
            # Sözdizimi: KOMUT rd, rs, rt
            if len(args) != 3:
                raise ValueError(f"'{mnemonic}' 3 operand bekliyor: rd, rs, rt")
            rd = parse_reg(args[0])
            rs = parse_reg(args[1])
            rt = parse_reg(args[2])
            return encode_r(rs, rt, rd, 0, R_FUNCT[mnemonic])

        # ── MUL: mul rd, rs, rt ───────────────────────────────────────────────
        elif mnemonic == 'mul':
            if len(args) != 3:
                raise ValueError("'mul' 3 operand bekliyor: rd, rs, rt")
            rd = parse_reg(args[0])
            rs = parse_reg(args[1])
            rt = parse_reg(args[2])
            return encode_r(rs, rt, rd, 0, R_FUNCT['mul'])

        # ── SWAP: swap rs, rt ─────────────────────────────────────────────────
        elif mnemonic == 'swap':
            # SWAP rs, rt → her ikisini de değiştirir (rd alanı 0)
            if len(args) != 2:
                raise ValueError("'swap' 2 operand bekliyor: rs, rt")
            rs = parse_reg(args[0])
            rt = parse_reg(args[1])
            return encode_r(rs, rt, 0, 0, R_FUNCT['swap'])

        # ── Standart I-type: addi, slti, andi, ori, xori ─────────────────────
        elif mnemonic in ('addi', 'slti', 'andi', 'ori', 'xori'):
            # Sözdizimi: KOMUT rt, rs, imm
            if len(args) != 3:
                raise ValueError(f"'{mnemonic}' 3 operand bekliyor: rt, rs, imm")
            rt = parse_reg(args[0])
            rs = parse_reg(args[1])
            imm = parse_imm(args[2])
            check_signed_range(imm, 16, f"{mnemonic} imm")
            return encode_i(I_OPCODE[mnemonic], rs, rt, imm)

        # ── LW: lw rt, offset(rs) ─────────────────────────────────────────────
        elif mnemonic == 'lw':
            if len(args) != 2:
                raise ValueError("'lw' 2 operand bekliyor: rt, offset($rs)")
            rt = parse_reg(args[0])
            offset, base_str = parse_mem_operand(args[1])
            rs = parse_reg(base_str)
            check_signed_range(offset, 16, "lw offset")
            return encode_i(I_OPCODE['lw'], rs, rt, offset)

        # ── SW: sw rt, offset(rs) ─────────────────────────────────────────────
        elif mnemonic == 'sw':
            if len(args) != 2:
                raise ValueError("'sw' 2 operand bekliyor: rt, offset($rs)")
            rt = parse_reg(args[0])
            offset, base_str = parse_mem_operand(args[1])
            rs = parse_reg(base_str)
            check_signed_range(offset, 16, "sw offset")
            return encode_i(I_OPCODE['sw'], rs, rt, offset)

        # ── BEQ: beq rs, rt, label ────────────────────────────────────────────
        elif mnemonic == 'beq':
            if len(args) != 3:
                raise ValueError("'beq' 3 operand bekliyor: rs, rt, label")
            rs = parse_reg(args[0])
            rt = parse_reg(args[1])
            offset = self._branch_offset(args[2], pc, lineno)
            return encode_i(I_OPCODE['beq'], rs, rt, offset)

        # ── BNE: bne rs, rt, label ────────────────────────────────────────────
        elif mnemonic == 'bne':
            if len(args) != 3:
                raise ValueError("'bne' 3 operand bekliyor: rs, rt, label")
            rs = parse_reg(args[0])
            rt = parse_reg(args[1])
            offset = self._branch_offset(args[2], pc, lineno)
            return encode_i(I_OPCODE['bne'], rs, rt, offset)

        # ── J: j label ────────────────────────────────────────────────────────
        elif mnemonic == 'j':
            if len(args) != 1:
                raise ValueError("'j' 1 operand bekliyor: label veya adres")
            target = self._resolve_label_or_addr(args[0], lineno)
            # J-type: hedef adresin bit[27:2]'si (>> 2)
            word_addr = (target >> 2) & 0x3FFFFFF
            return encode_j(J_OPCODE['j'], word_addr)

        # ── LOADI: loadi rd, imm ──────────────────────────────────────────────
        # YENİ KOMUT: rd = imm (16-bit anlık değeri register'a yükle)
        # Kodlama: op=0x11 | rs=0(5) | rt=rd(5) | imm(16)
        # Not: "hedef rt alanına yazılır" — rd aslında rt pozisyonuna gider
        elif mnemonic == 'loadi':
            if len(args) != 2:
                raise ValueError("'loadi' 2 operand bekliyor: rd, imm")
            rd = parse_reg(args[0])   # donanımda rt alanına yazılır
            imm = parse_imm(args[1])
            # 16-bit işaretli veya unsigned — geniş tutalım
            if not (-32768 <= imm <= 65535):
                raise ValueError(f"loadi imm {imm} 16-bit'e sığmıyor")
            return encode_i(I_OPCODE['loadi'], 0, rd, imm)

        # ── BGT: bgt rs, rt, label ────────────────────────────────────────────
        # YENİ KOMUT: rs > rt ise dallan (A-B > 0: zero=0 ve işaret=0)
        elif mnemonic == 'bgt':
            if len(args) != 3:
                raise ValueError("'bgt' 3 operand bekliyor: rs, rt, label")
            rs = parse_reg(args[0])
            rt = parse_reg(args[1])
            offset = self._branch_offset(args[2], pc, lineno)
            return encode_i(I_OPCODE['bgt'], rs, rt, offset)

        # ── PUSH: push rs ─────────────────────────────────────────────────────
        # YENİ KOMUT: $sp -= 4; MEM[$sp] = rs
        # Kodlama: op=0x13 | rs(5) | rt=0(5) | imm=0(16)
        elif mnemonic == 'push':
            if len(args) != 1:
                raise ValueError("'push' 1 operand bekliyor: rs")
            rs = parse_reg(args[0])
            return encode_i(I_OPCODE['push'], rs, 0, 0)

        # ── POP: pop rd ───────────────────────────────────────────────────────
        # YENİ KOMUT: rd = MEM[$sp]; $sp += 4
        # Kodlama: op=0x14 | rs=0(5) | rt=rd(5) | imm=0(16)
        # Not: "hedef rt alanına yazılır"
        elif mnemonic == 'pop':
            if len(args) != 1:
                raise ValueError("'pop' 1 operand bekliyor: rd")
            rd = parse_reg(args[0])   # donanımda rt alanı kullanılır
            return encode_i(I_OPCODE['pop'], 0, rd, 0)

        # ── ADDI3: addi3 rd, rs, rt, imm ─────────────────────────────────────
        # YENİ KOMUT: rd = rs + rt + imm (11-bit işaretli)
        elif mnemonic == 'addi3':
            if len(args) != 4:
                raise ValueError("'addi3' 4 operand bekliyor: rd, rs, rt, imm")
            rd = parse_reg(args[0])
            rs = parse_reg(args[1])
            rt = parse_reg(args[2])
            imm = parse_imm(args[3])
            return encode_addi3(rs, rt, rd, imm)

        else:
            raise ValueError(f"Bilinmeyen komut: '{mnemonic}'")

    def _branch_offset(self, label_or_addr, pc, lineno):
        """
        Branch offset hesabı: (hedef - (PC + 4)) >> 2
        MIPS'te branch hedefi PC+4'e göreli, kelime cinsinden (>>2).
        """
        target = self._resolve_label_or_addr(label_or_addr, lineno)
        offset = (target - (pc + 4)) >> 2
        check_signed_range(offset, 16, f"branch offset @ satır {lineno}")
        return offset

    def _resolve_label_or_addr(self, s, lineno):
        """Label ismini veya sayısal adresi byte adresine çevirir."""
        s = s.strip()
        if s in self.label_table:
            return self.label_table[s]
        try:
            return parse_imm(s)
        except ValueError:
            raise ValueError(
                f"Tanımsız etiket: '{s}' (satır {lineno})\n"
                f"Tanımlı etiketler: {list(self.label_table.keys())}"
            )

    # ── Dosya işlemleri ───────────────────────────────────────────────────────

    def assemble(self, source_text):
        """Kaynak metni makine koduna çevirir."""
        lines = source_text.splitlines()
        self.pass1(lines)
        return self.pass2()

    def write_hex(self, machine_words, out_path):
        """
        ModelSim $readmemh formatında .hex dosyası yazar.
        Her satır: 8 hex karakter (32-bit kelime).
        Bellek boşlukları (gap) 00000000 ile doldurulur.
        """
        if not machine_words:
            return

        max_addr = max(addr for addr, _ in machine_words)
        word_count = (max_addr // 4) + 1

        # Sparse → dense dizi (boşlukları 0 ile doldur)
        mem = [0] * word_count
        for addr, word in machine_words:
            mem[addr // 4] = word

        with open(out_path, 'w') as f:
            f.write(f"// MIPS Assembler çıktısı — {len(machine_words)} komut\n")
            f.write(f"// $readmemh ile yükle: $readmemh(\"{out_path}\", mem);\n")
            for word in mem:
                f.write(f"{word:08x}\n")

        print(f"Çıktı dosyası: {out_path} ({len(mem)} kelime)")

    def print_listing(self, machine_words):
        """İnsan okunabilir listing çıktısı: adres, hex, binary, kaynak."""
        print("\n─── PROGRAM LİSTİNGİ ───────────────────────────────────────────")
        print(f"{'Adres':<12} {'Hex':<12} {'Binary':<35} Açıklama")
        print("─" * 75)

        instr_map = {addr: (word, tokens)
                     for (_, addr, tokens), (addr2, word)
                     in zip(self.instructions, machine_words)}

        # Label → adres ters haritası
        addr_to_label = {v: k for k, v in self.label_table.items()}

        for addr, word in machine_words:
            label = addr_to_label.get(addr, "")
            if label:
                print(f"\n{label}:")
            tokens = instr_map[addr][1] if addr in instr_map else []
            src = ' '.join(tokens)
            binary = format(word, '032b')
            # Binary'i okunabilir parçalara böl: op|rs|rt|rd|shamt|funct
            b = f"{binary[0:6]}|{binary[6:11]}|{binary[11:16]}|{binary[16:21]}|{binary[21:26]}|{binary[26:32]}"
            print(f"0x{addr:08x}   {word:08x}   {b}   {src}")

        print("─" * 75)
        if self.label_table:
            print("\nEtiket Tablosu:")
            for label, addr in sorted(self.label_table.items(), key=lambda x: x[1]):
                print(f"  {label:<20} → 0x{addr:08x}")


# ─── MAIN ─────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("Kullanım: python3 assembler.py <dosya.asm> [-v]")
        print("  -v : detaylı (verbose) çıktı + listing")
        sys.exit(1)

    src_path = sys.argv[1]
    verbose = '-v' in sys.argv

    try:
        with open(src_path, 'r', encoding='utf-8') as f:
            source = f.read()
    except FileNotFoundError:
        print(f"Hata: '{src_path}' dosyası bulunamadı.")
        sys.exit(1)

    out_path = src_path.rsplit('.', 1)[0] + '.hex'

    asm = Assembler(verbose=verbose)
    try:
        machine_words = asm.assemble(source)
    except SyntaxError as e:
        print(f"\nAssembler HATASI: {e}")
        sys.exit(1)

    asm.write_hex(machine_words, out_path)

    if verbose:
        asm.print_listing(machine_words)

    print(f"Başarılı: {len(machine_words)} komut derlendi.")


if __name__ == '__main__':
    main()
