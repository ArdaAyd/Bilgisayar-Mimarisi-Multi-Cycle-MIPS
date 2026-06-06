-- ═══════════════════════════════════════════════════════════════════════════
-- PC (Program Counter) — sıradaki komutun adresini tutan register
-- ───────────────────────────────────────────────────────────────────────────
-- Multi-cycle CPU'da PC her saykılda güncellenmez; yalnızca pc_write='1'
-- olduğunda yeni adresi alır, aksi halde değerini korur.
--   reset='1'    → PC = 0
--   pc_write='1' → PC = pc_next
-- Senkron devre: değişiklik clock'un yükselen kenarında olur.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pc is
    Port (
        clk      : in  STD_LOGIC;
        reset    : in  STD_LOGIC;
        pc_write : in  STD_LOGIC;
        pc_next  : in  STD_LOGIC_VECTOR(31 downto 0);
        pc_out   : out STD_LOGIC_VECTOR(31 downto 0)
    );
end pc;

architecture Behavioral of pc is
    signal pc_reg : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pc_reg <= (others => '0');
            elsif pc_write = '1' then
                pc_reg <= pc_next;
            end if;
        end if;
    end process;

    pc_out <= pc_reg;

end Behavioral;
