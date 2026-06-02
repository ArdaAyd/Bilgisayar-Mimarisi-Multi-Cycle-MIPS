-- ═══════════════════════════════════════════════════════════════════════════
-- PC (Program Counter) — sıradaki komutun adresini tutan register
-- ───────────────────────────────────────────────────────────────────────────
-- Multi-cycle CPU'da PC HER saykılda güncellenmez. Sadece kontrol birimi
-- "şimdi güncelle" dediğinde (pc_write='1') yeni adresi alır. Bu yüzden
-- normal bir register'dan farklı olarak bir 'pc_write' (enable) girişi var.
--
--   reset='1'      → PC = 0 (programın başına dön), senkron.
--   pc_write='1'   → PC = pc_next (yeni adresi yükle).
--   ikisi de '0'   → PC değerini KORUR (multi-cycle'da çoğu saykıl böyle).
--
-- Senkron devre: değişiklik clock'un yükselen kenarında olur.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pc is
    Port (
        clk      : in  STD_LOGIC;
        reset    : in  STD_LOGIC;                        -- '1' → PC=0
        pc_write : in  STD_LOGIC;                        -- '1' → yeni adresi yükle
        pc_next  : in  STD_LOGIC_VECTOR(31 downto 0);    -- yüklenecek adres
        pc_out   : out STD_LOGIC_VECTOR(31 downto 0)     -- mevcut PC değeri
    );
end pc;

architecture Behavioral of pc is
    signal pc_reg : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pc_reg <= (others => '0');     -- başa dön
            elsif pc_write = '1' then
                pc_reg <= pc_next;             -- yeni adresi al
            end if;
            -- ikisi de '0' ise pc_reg değişmez → değer korunur
        end if;
    end process;

    pc_out <= pc_reg;

end Behavioral;
