-- ═══════════════════════════════════════════════════════════════════════════
-- Instruction Register (IR) — okunan komutu kilitler ve alanlara böler
-- ───────────────────────────────────────────────────────────────────────────
-- Multi-cycle CPU'da bellek TEK (komut+veri birlikte). IF saykılında komutu
-- bellekten okuyup IR'a kilitleriz. Sonra lw/sw MEM saykılında belleği veri
-- için kullanır — eğer komutu kilitlememiş olsaydık bitleri kaybederdik.
--
--   ir_write='1' → girişteki komutu (instr_in) yükle (sadece IF saykılında)
--   ir_write='0' → komutu KORU (komutun diğer tüm saykılları boyunca)
--
-- Kilitlenen komut ayrıca alanlara bölünüp dışarı verilir:
--   opcode (6) | rs (5) | rt (5) | rd (5) | immediate (16) | address (26)
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity instruction_register is
    Port (
        clk      : in  STD_LOGIC;
        ir_write : in  STD_LOGIC;                       -- '1' → komutu yükle
        instr_in : in  STD_LOGIC_VECTOR(31 downto 0);   -- bellekten gelen komut

        -- ── Kilitlenmiş komut ve alanları ──
        opcode   : out STD_LOGIC_VECTOR(5 downto 0);    -- bit 31..26
        rs       : out STD_LOGIC_VECTOR(4 downto 0);    -- bit 25..21
        rt       : out STD_LOGIC_VECTOR(4 downto 0);    -- bit 20..16
        rd       : out STD_LOGIC_VECTOR(4 downto 0);    -- bit 15..11
        shamt    : out STD_LOGIC_VECTOR(4 downto 0);    -- bit 10..6
        funct    : out STD_LOGIC_VECTOR(5 downto 0);    -- bit 5..0
        immediate: out STD_LOGIC_VECTOR(15 downto 0);   -- bit 15..0  (I-type)
        address  : out STD_LOGIC_VECTOR(25 downto 0);   -- bit 25..0  (J-type)
        instr_out: out STD_LOGIC_VECTOR(31 downto 0)    -- tüm komut (gerekirse)
    );
end instruction_register;

architecture Behavioral of instruction_register is
    signal ir : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
begin

    -- ── Komutu kilitle (senkron) ─────────────────────────────────────────────
    process(clk)
    begin
        if rising_edge(clk) then
            if ir_write = '1' then
                ir <= instr_in;
            end if;
        end if;
    end process;

    -- ── Alanlara böl (kombinasyonel; sadece bit dilimleme) ───────────────────
    opcode    <= ir(31 downto 26);
    rs        <= ir(25 downto 21);
    rt        <= ir(20 downto 16);
    rd        <= ir(15 downto 11);
    shamt     <= ir(10 downto 6);
    funct     <= ir(5 downto 0);
    immediate <= ir(15 downto 0);
    address   <= ir(25 downto 0);
    instr_out <= ir;

end Behavioral;
