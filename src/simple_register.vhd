-- ═══════════════════════════════════════════════════════════════════════════
-- simple_register — genel amaçlı 32-bit ara saklama register'ı
-- ───────────────────────────────────────────────────────────────────────────
-- Bir saykılda üretilen değeri sonraki saykıla taşımak için kullanılır
-- (A, B operandları, ALUOut, MDR). en='1' iken yükler, en='0' iken korur.
-- Senkron: yükleme clock'un yükselen kenarında olur.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity simple_register is
    Port (
        clk : in  STD_LOGIC;
        en  : in  STD_LOGIC;
        d   : in  STD_LOGIC_VECTOR(31 downto 0);
        q   : out STD_LOGIC_VECTOR(31 downto 0)
    );
end simple_register;

architecture Behavioral of simple_register is
    signal reg : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if en = '1' then
                reg <= d;
            end if;
        end if;
    end process;

    q <= reg;

end Behavioral;
