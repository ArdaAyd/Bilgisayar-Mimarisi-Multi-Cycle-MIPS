-- ═══════════════════════════════════════════════════════════════════════════
-- Memory — CPU'nun belleği (komut + veri tek bellek, von Neumann)
-- ───────────────────────────────────────────────────────────────────────────
-- 256 adet 32-bit söz (word). Toplam 256*4 = 1024 byte.
--
-- ÖNEMLİ: Dışarıdan gelen 'address' BYTE adresidir (MIPS böyle çalışır).
--   Bir word 4 byte olduğundan word indeksi = byte adresi / 4 = address >> 2.
--   256 word için 8 bitlik indeks yeter → address(9 downto 2).
--   (bit 1..0 = word içindeki byte; bizde hep word hizalı eriştiğimiz için 0.)
--
-- Okuma  : asenkron (mem_read='1' iken adresteki word anında çıkışta).
-- Yazma  : senkron  (clock yükselen kenarında, mem_write='1' ise).
-- Başlangıç içeriği INIT_FILE adlı hex dosyadan yüklenir (boşsa hepsi 0).
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;           -- dosya okuma (text, line, readline)
-- VHDL-2008: hread (hex okuma) std_logic_1164 içinde gelir.

entity memory is
    generic (
        -- Başlangıçta belleğe yüklenecek hex dosyasının adı.
        -- Boş ("") verilirse bellek sıfırla başlar.
        INIT_FILE : string := ""
    );
    Port (
        clk        : in  STD_LOGIC;
        mem_read   : in  STD_LOGIC;                       -- '1' ise oku
        mem_write  : in  STD_LOGIC;                       -- '1' ise yaz
        address    : in  STD_LOGIC_VECTOR(31 downto 0);  -- BYTE adresi
        write_data : in  STD_LOGIC_VECTOR(31 downto 0);   -- yazılacak veri
        read_data  : out STD_LOGIC_VECTOR(31 downto 0)    -- okunan veri
    );
end memory;

architecture Behavioral of memory is

    constant MEM_WORDS : integer := 256;
    type mem_array is array (0 to MEM_WORDS - 1) of STD_LOGIC_VECTOR(31 downto 0);

    -- ── Hex dosyadan belleği dolduran fonksiyon ──────────────────────────────
    -- 'impure' çünkü dosya (dış dünya) okuyor; aynı girdiyle hep aynı sonucu
    -- vermeyebilir, bu yüzden VHDL impure işaretlememizi ister.
    impure function init_mem(filename : string) return mem_array is
        variable mem_v  : mem_array := (others => (others => '0'));
        file     f      : text;
        variable status : file_open_status;
        variable l      : line;
        variable word   : STD_LOGIC_VECTOR(31 downto 0);
        variable good   : boolean;
        variable idx    : integer := 0;
    begin
        -- Dosya adı boşsa hiç açma, sıfır bellekle dön.
        if filename = "" then
            return mem_v;
        end if;

        file_open(status, f, filename, read_mode);
        if status /= open_ok then
            report "UYARI: bellek init dosyasi acilamadi: " & filename
                severity warning;
            return mem_v;
        end if;

        -- Satır satır oku. hread bir satırdan 8 hex hane (32 bit) çekmeye çalışır.
        -- Yorum ("//...") veya boş satırda hex bulamaz → good=false → o satırı atla.
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

    -- Bellek sinyali; init_mem ile başlangıç değerleri yüklenir.
    signal mem : mem_array := init_mem(INIT_FILE);

begin

    -- ── Asenkron okuma ──────────────────────────────────────────────────────
    -- mem_read='1' iken adresteki word çıkışa verilir, değilse 0.
    read_data <= mem(to_integer(unsigned(address(9 downto 2))))
                 when mem_read = '1' else (others => '0');

    -- ── Senkron yazma ───────────────────────────────────────────────────────
    process(clk)
    begin
        if rising_edge(clk) then
            if mem_write = '1' then
                mem(to_integer(unsigned(address(9 downto 2)))) <= write_data;
            end if;
        end if;
    end process;

end Behavioral;
