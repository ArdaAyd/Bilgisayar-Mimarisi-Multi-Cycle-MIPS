-- ═══════════════════════════════════════════════════════════════════════════
-- Register File — CPU'nun 32 adet 32-bit register'ı ($0 .. $31)
-- ───────────────────────────────────────────────────────────────────────────
-- 2 okuma portu (asenkron): aynı anda iki register okunabilir.
-- 1 yazma portu (senkron):  yazma clock'un yükselen kenarında olur.
-- $0 her zaman sıfır:       $0'a yazma donanımda engellenir (MIPS kuralı).
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity register_file is
    Port (
        clk        : in  STD_LOGIC;
        reg_write  : in  STD_LOGIC;                      -- '1' ise yaz
        read_reg1  : in  STD_LOGIC_VECTOR(4 downto 0);   -- 1. okunacak register no
        read_reg2  : in  STD_LOGIC_VECTOR(4 downto 0);   -- 2. okunacak register no
        write_reg  : in  STD_LOGIC_VECTOR(4 downto 0);   -- yazılacak register no
        write_data : in  STD_LOGIC_VECTOR(31 downto 0);  -- yazılacak veri
        read_data1 : out STD_LOGIC_VECTOR(31 downto 0);  -- 1. okunan veri
        read_data2 : out STD_LOGIC_VECTOR(31 downto 0);  -- 2. okunan veri

        -- ── Hata ayıklama portu (asenkron 3. okuma) ──
        -- Sadece testbench'in register içeriğini gözlemlemesi için. Donanım
        -- mantığını etkilemez; istenirse sentez öncesi çıkarılabilir.
        dbg_reg    : in  STD_LOGIC_VECTOR(4 downto 0)  := (others => '0');
        dbg_data   : out STD_LOGIC_VECTOR(31 downto 0)
    );
end register_file;

architecture Behavioral of register_file is

    -- 32 adet 32-bit register'ı bir dizi olarak tanımlıyoruz.
    type reg_array is array (0 to 31) of STD_LOGIC_VECTOR(31 downto 0);

    -- Hepsi 0 ile başlar (temiz başlangıç durumu).
    signal registers : reg_array := (others => (others => '0'));

begin

    -- ── Asenkron okuma ──────────────────────────────────────────────────────
    -- Adres (read_reg) değişince çıkış anında güncellenir, clock beklemez.
    -- $0 zaten 0 tutulduğu için ayrı kontrol gerekmez.
    read_data1 <= registers(to_integer(unsigned(read_reg1)));
    read_data2 <= registers(to_integer(unsigned(read_reg2)));

    -- Hata ayıklama: seçilen register'ı anında dışarı ver (testbench gözlemler).
    dbg_data   <= registers(to_integer(unsigned(dbg_reg)));

    -- ── Senkron yazma ─────────────────────────────────────────────────────
    -- Sadece clock'un yükselen kenarında, reg_write='1' ve hedef $0 değilse yaz.
    process(clk)
    begin
        if rising_edge(clk) then
            if reg_write = '1' and write_reg /= "00000" then
                registers(to_integer(unsigned(write_reg))) <= write_data;
            end if;
        end if;
    end process;

end Behavioral;
