-- ═══════════════════════════════════════════════════════════════════════════
-- tb_register_file — Register File için self-checking testbench
-- ───────────────────────────────────────────────────────────────────────────
-- Test edilenler:
--   1. Bir register'a yaz, geri oku
--   2. $0'a yazmaya çalış → hep 0 kalmalı
--   3. İki register'ı aynı anda oku (iki okuma portu)
--   4. reg_write='0' iken yazma OLMAMALI
--
-- Yazma senkron olduğu için testbench bir clock üretir.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_register_file is
end tb_register_file;

architecture sim of tb_register_file is

    signal clk        : STD_LOGIC := '0';
    signal reg_write  : STD_LOGIC := '0';
    signal read_reg1  : STD_LOGIC_VECTOR(4 downto 0)  := (others => '0');
    signal read_reg2  : STD_LOGIC_VECTOR(4 downto 0)  := (others => '0');
    signal write_reg  : STD_LOGIC_VECTOR(4 downto 0)  := (others => '0');
    signal write_data : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal read_data1 : STD_LOGIC_VECTOR(31 downto 0);
    signal read_data2 : STD_LOGIC_VECTOR(31 downto 0);

    constant CLK_PERIOD : time := 10 ns;
    signal stop_clk : boolean := false;

begin

    -- ── DUT ───────────────────────────────────────────────────────────────
    DUT: entity work.register_file
        port map (
            clk        => clk,
            reg_write  => reg_write,
            read_reg1  => read_reg1,
            read_reg2  => read_reg2,
            write_reg  => write_reg,
            write_data => write_data,
            read_data1 => read_data1,
            read_data2 => read_data2
        );

    -- ── Clock üreteci ──────────────────────────────────────────────────────
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

    -- ── Test senaryoları ──────────────────────────────────────────────────
    stimulus: process
    begin
        report "=== REGISTER FILE TESTLERI BASLIYOR ===" severity note;

        -- Test 1: $5'e 100 yaz, geri oku
        write_reg  <= "00101";   -- $5
        write_data <= std_logic_vector(to_unsigned(100, 32));
        reg_write  <= '1';
        wait until rising_edge(clk);   -- yazma bu kenarda gerçekleşir
        wait for 1 ns;                 -- sinyaller otursun
        reg_write  <= '0';
        read_reg1  <= "00101";
        wait for 1 ns;
        assert read_data1 = std_logic_vector(to_unsigned(100, 32))
            report "HATA [Test1]: $5=100 yazilip okunamadi" severity error;

        -- Test 2: $0'a 123 yazmaya calis, hep 0 kalmali
        write_reg  <= "00000";   -- $0
        write_data <= std_logic_vector(to_unsigned(123, 32));
        reg_write  <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        reg_write  <= '0';
        read_reg1  <= "00000";
        wait for 1 ns;
        assert read_data1 = x"00000000"
            report "HATA [Test2]: $0 sifir kalmadi" severity error;

        -- Test 3: $6=7 ve $7=9 yaz, ikisini ayni anda oku
        write_reg  <= "00110";   -- $6
        write_data <= std_logic_vector(to_unsigned(7, 32));
        reg_write  <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        write_reg  <= "00111";   -- $7
        write_data <= std_logic_vector(to_unsigned(9, 32));
        wait until rising_edge(clk);
        wait for 1 ns;
        reg_write  <= '0';
        read_reg1  <= "00110";   -- $6
        read_reg2  <= "00111";   -- $7
        wait for 1 ns;
        assert read_data1 = std_logic_vector(to_unsigned(7, 32))
            report "HATA [Test3]: $6=7 okunamadi" severity error;
        assert read_data2 = std_logic_vector(to_unsigned(9, 32))
            report "HATA [Test3]: $7=9 okunamadi" severity error;

        -- Test 4: reg_write='0' iken $5'e 555 yazmaya calis, degismemeli
        read_reg1  <= "00101";   -- $5 (hala 100 olmali)
        write_reg  <= "00101";
        write_data <= std_logic_vector(to_unsigned(555, 32));
        reg_write  <= '0';       -- yazma KAPALI
        wait until rising_edge(clk);
        wait for 1 ns;
        assert read_data1 = std_logic_vector(to_unsigned(100, 32))
            report "HATA [Test4]: reg_write=0 iken yazma oldu" severity error;

        report "=== TUM REGISTER FILE TESTLERI GECTI ===" severity note;
        stop_clk <= true;   -- clock'u durdur, simulasyon biter
        wait;
    end process;

end sim;
