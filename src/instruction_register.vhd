-- ═══════════════════════════════════════════════════════════════════════════
-- Instruction Register (IR) — okunan komutu kilitler ve alanlara böler
-- ───────────────────────────────────────────────────────────────────────────
-- Bellek tek olduğundan (komut+veri), IF saykılında okunan komutu IR'a
-- kilitleriz; aksi halde lw/sw belleği veriye kullanınca komut bitleri kaybolur.
-- ir_write='1' iken yükler (sadece IF), aksi halde komutu korur.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity instruction_register is
    Port (
        clk      : in  STD_LOGIC;
        ir_write : in  STD_LOGIC;
        instr_in : in  STD_LOGIC_VECTOR(31 downto 0);

        opcode   : out STD_LOGIC_VECTOR(5 downto 0);    -- bit 31..26
        rs       : out STD_LOGIC_VECTOR(4 downto 0);    -- bit 25..21
        rt       : out STD_LOGIC_VECTOR(4 downto 0);    -- bit 20..16
        rd       : out STD_LOGIC_VECTOR(4 downto 0);    -- bit 15..11
        shamt    : out STD_LOGIC_VECTOR(4 downto 0);    -- bit 10..6
        funct    : out STD_LOGIC_VECTOR(5 downto 0);    -- bit 5..0
        immediate: out STD_LOGIC_VECTOR(15 downto 0);   -- bit 15..0 (I-type)
        address  : out STD_LOGIC_VECTOR(25 downto 0);   -- bit 25..0 (J-type)
        instr_out: out STD_LOGIC_VECTOR(31 downto 0)
    );
end instruction_register;

architecture Behavioral of instruction_register is
    signal ir : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if ir_write = '1' then
                ir <= instr_in;
            end if;
        end if;
    end process;

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
