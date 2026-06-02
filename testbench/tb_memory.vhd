-- ═══════════════════════════════════════════════════════════════════════════
-- tb_memory — Memory için self-checking testbench
-- ───────────────────────────────────────────────────────────────────────────
-- Test edilenler:
--   1. INIT_FILE (test_mem.hex) doğru yüklendi mi? (byte adresleme kontrolü)
--   2. Bir adrese yaz, geri oku (senkron yazma / asenkron okuma)
--   3. mem_write='0' iken yazma OLMAMALI
--   4. mem_read='0' iken çıkış 0 olmalı
--
-- ÖNEMLİ: address BYTE adresidir. word N → byte adresi N*4.
--   word0=deadbeef (adr 0), word1=00000005 (adr 4),
--   word2=0000000a (adr 8), word3=cafebabe (adr 12)
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_memory is
end tb_memory;

architecture sim of tb_memory is

    signal clk        : STD_LOGIC := '0';
    signal mem_read   : STD_LOGIC := '0';
    signal mem_write  : STD_LOGIC := '0';
    signal address    : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal write_data : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal read_data  : STD_LOGIC_VECTOR(31 downto 0);

    constant CLK_PERIOD : time := 10 ns;
    signal stop_clk : boolean := false;

    -- Yardımcı: byte adresi üretir (word indeksini 4 ile çarpar).
    function byte_addr(word_idx : integer) return STD_LOGIC_VECTOR is
    begin
        return std_logic_vector(to_unsigned(word_idx * 4, 32));
    end function;

begin

    -- ── DUT: test_mem.hex ile başlatılıyor ───────────────────────────────────
    -- DİKKAT: dosya yolu ModelSim'i çalıştırdığın klasöre göredir.
    -- Dosyalar düz (flat) duruyorsa sadece "test_mem.hex" yeterli olabilir;
    -- gerekirse yolu kendine göre düzelt.
    DUT: entity work.memory
        generic map ( INIT_FILE => "test_mem.hex" )
        port map (
            clk        => clk,
            mem_read   => mem_read,
            mem_write  => mem_write,
            address    => address,
            write_data => write_data,
            read_data  => read_data
        );

    -- ── Clock üreteci ────────────────────────────────────────────────────────
    clk_proc: process
    begin
        while not stop_clk loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- ── Test senaryoları ────────────────────────────────────────────────────
    stimulus: process
    begin
        report "=== MEMORY TESTLERI BASLIYOR ===" severity note;

        -- Test 1: INIT_FILE doğru yüklendi mi? (asenkron okuma)
        mem_read <= '1';

        address <= byte_addr(0);   wait for 1 ns;
        assert read_data = x"deadbeef"
            report "HATA [Test1]: word0 (adr0) deadbeef degil" severity error;

        address <= byte_addr(1);   wait for 1 ns;
        assert read_data = x"00000005"
            report "HATA [Test1]: word1 (adr4) 00000005 degil" severity error;

        address <= byte_addr(2);   wait for 1 ns;
        assert read_data = x"0000000a"
            report "HATA [Test1]: word2 (adr8) 0000000a degil" severity error;

        address <= byte_addr(3);   wait for 1 ns;
        assert read_data = x"cafebabe"
            report "HATA [Test1]: word3 (adr12) cafebabe degil" severity error;

        -- Test 2: word 10'a (byte adresi 40) yaz, geri oku
        mem_read   <= '0';
        address    <= byte_addr(10);
        write_data <= x"12345678";
        mem_write  <= '1';
        wait until rising_edge(clk);   -- yazma bu kenarda gerçekleşir
        wait for 1 ns;
        mem_write  <= '0';
        mem_read   <= '1';
        wait for 1 ns;
        assert read_data = x"12345678"
            report "HATA [Test2]: word10'a yazip okuyamadik" severity error;

        -- Test 3: mem_write='0' iken word 10'a yazmaya çalış, değişmemeli
        mem_read   <= '0';
        address    <= byte_addr(10);
        write_data <= x"ffffffff";
        mem_write  <= '0';             -- yazma KAPALI
        wait until rising_edge(clk);
        wait for 1 ns;
        mem_read   <= '1';
        wait for 1 ns;
        assert read_data = x"12345678"
            report "HATA [Test3]: mem_write=0 iken yazma oldu" severity error;

        -- Test 4: mem_read='0' iken çıkış 0 olmalı
        mem_read <= '0';
        wait for 1 ns;
        assert read_data = x"00000000"
            report "HATA [Test4]: mem_read=0 iken cikis 0 degil" severity error;

        report "=== TUM MEMORY TESTLERI GECTI ===" severity note;
        stop_clk <= true;
        wait;
    end process;

end sim;
