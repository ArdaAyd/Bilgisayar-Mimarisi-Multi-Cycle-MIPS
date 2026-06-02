-- ═══════════════════════════════════════════════════════════════════════════
-- simple_register — genel amaçlı 32-bit ara saklama register'ı
-- ───────────────────────────────────────────────────────────────────────────
-- Multi-cycle datapath'te bir saykılda üretilen değeri sonraki saykıla taşımak
-- için kullanılır. Örnekler:
--   A, B    : register file'dan okunan operandlar (EX saykılında ALU'ya gider)
--   ALUOut  : ALU sonucu (MEM/WB saykılında kullanılır)
--   MDR     : bellekten okunan veri (WB saykılında register'a yazılır)
--
--   en='1'  → girişteki değeri (d) yükle
--   en='0'  → mevcut değeri KORU
--
-- Senkron: yükleme clock'un yükselen kenarında olur.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity simple_register is
    Port (
        clk : in  STD_LOGIC;
        en  : in  STD_LOGIC;                         -- '1' → yükle, '0' → koru
        d   : in  STD_LOGIC_VECTOR(31 downto 0);     -- giriş (data in)
        q   : out STD_LOGIC_VECTOR(31 downto 0)      -- çıkış (saklanan değer)
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
            -- en='0' ise reg değişmez → değer korunur
        end if;
    end process;

    q <= reg;

end Behavioral;
