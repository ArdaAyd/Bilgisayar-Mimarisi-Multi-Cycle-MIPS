-- ═══════════════════════════════════════════════════════════════════════════
-- Register File — CPU'nun 32 adet 32-bit register'ı ($0 .. $31)
-- ───────────────────────────────────────────────────────────────────────────
-- 2 okuma portu (asenkron) + 1 yazma portu (senkron).
-- $0 her zaman sıfırdır: $0'a yazma donanımda engellenir (MIPS kuralı).
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity register_file is
    Port (
        clk        : in  STD_LOGIC;
        reg_write  : in  STD_LOGIC;
        read_reg1  : in  STD_LOGIC_VECTOR(4 downto 0);
        read_reg2  : in  STD_LOGIC_VECTOR(4 downto 0);
        write_reg  : in  STD_LOGIC_VECTOR(4 downto 0);
        write_data : in  STD_LOGIC_VECTOR(31 downto 0);
        read_data1 : out STD_LOGIC_VECTOR(31 downto 0);
        read_data2 : out STD_LOGIC_VECTOR(31 downto 0);

        -- Hata ayıklama portu: asenkron 3. okuma, sadece testbench gözlemi için.
        -- Donanım mantığını etkilemez; istenirse sentez öncesi çıkarılabilir.
        dbg_reg    : in  STD_LOGIC_VECTOR(4 downto 0)  := (others => '0');
        dbg_data   : out STD_LOGIC_VECTOR(31 downto 0)
    );
end register_file;

architecture Behavioral of register_file is

    type reg_array is array (0 to 31) of STD_LOGIC_VECTOR(31 downto 0);
    signal registers : reg_array := (others => (others => '0'));

begin

    -- Asenkron okuma (clock beklemez)
    read_data1 <= registers(to_integer(unsigned(read_reg1)));
    read_data2 <= registers(to_integer(unsigned(read_reg2)));
    dbg_data   <= registers(to_integer(unsigned(dbg_reg)));

    -- Senkron yazma: hedef $0 değilse yaz
    process(clk)
    begin
        if rising_edge(clk) then
            if reg_write = '1' and write_reg /= "00000" then
                registers(to_integer(unsigned(write_reg))) <= write_data;
            end if;
        end if;
    end process;

end Behavioral;
