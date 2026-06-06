-- ═══════════════════════════════════════════════════════════════════════════
-- Memory — CPU'nun belleği (komut + veri tek bellek, von Neumann)
-- ───────────────────────────────────────────────────────────────────────────
-- 256 adet 32-bit word (1024 byte).
-- Dışarıdan gelen 'address' BYTE adresidir; word indeksi = address >> 2,
-- yani address(9 downto 2) (256 word için 8 bit yeter, word hizalı erişim).
-- Okuma asenkron, yazma senkron. Başlangıç içeriği INIT_FILE hex dosyasından.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;

entity memory is
    generic (
        INIT_FILE : string := ""        -- boş ("") ise bellek sıfırla başlar
    );
    Port (
        clk        : in  STD_LOGIC;
        mem_read   : in  STD_LOGIC;
        mem_write  : in  STD_LOGIC;
        address    : in  STD_LOGIC_VECTOR(31 downto 0);   -- BYTE adresi
        write_data : in  STD_LOGIC_VECTOR(31 downto 0);
        read_data  : out STD_LOGIC_VECTOR(31 downto 0)
    );
end memory;

architecture Behavioral of memory is

    constant MEM_WORDS : integer := 256;
    type mem_array is array (0 to MEM_WORDS - 1) of STD_LOGIC_VECTOR(31 downto 0);

    -- Hex dosyadan belleği doldurur. Dosya (dış dünya) okuduğu için 'impure'.
    impure function init_mem(filename : string) return mem_array is
        variable mem_v  : mem_array := (others => (others => '0'));
        file     f      : text;
        variable status : file_open_status;
        variable l      : line;
        variable word   : STD_LOGIC_VECTOR(31 downto 0);
        variable good   : boolean;
        variable idx    : integer := 0;
    begin
        if filename = "" then
            return mem_v;
        end if;

        file_open(status, f, filename, read_mode);
        if status /= open_ok then
            report "UYARI: bellek init dosyasi acilamadi: " & filename
                severity warning;
            return mem_v;
        end if;

        -- hread bir satırdan 32 bit (8 hex hane) çeker; yorum/boş satırda
        -- good=false döner ve o satır atlanır.
        while (not endfile(f)) and (idx < MEM_WORDS) loop
            readline(f, l);
            hread(l, word, good);
            if good then
                mem_v(idx) := word;
                idx := idx + 1;
            end if;
        end loop;

        file_close(f);
        return mem_v;
    end function;

    signal mem : mem_array := init_mem(INIT_FILE);

begin

    read_data <= mem(to_integer(unsigned(address(9 downto 2))))
                 when mem_read = '1' else (others => '0');

    process(clk)
    begin
        if rising_edge(clk) then
            if mem_write = '1' then
                mem(to_integer(unsigned(address(9 downto 2)))) <= write_data;
            end if;
        end if;
    end process;

end Behavioral;
