-- ═══════════════════════════════════════════════════════════════════════════
-- tb_pc — Program Counter için self-checking testbench
-- ───────────────────────────────────────────────────────────────────────────
-- Test edilenler:
--   1. reset='1' → PC=0
--   2. pc_write='1' → yeni adresi yükler
--   3. pc_write='0' → değeri KORUR (multi-cycle'da kritik)
--   4. reset her zaman kazanır (pc_write='1' olsa bile reset PC'yi sıfırlar)
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_pc is
end tb_pc;

architecture sim of tb_pc is

    signal clk      : STD_LOGIC := '0';
    signal reset    : STD_LOGIC := '0';
    signal pc_write : STD_LOGIC := '0';
    signal pc_next  : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal pc_out   : STD_LOGIC_VECTOR(31 downto 0);

    constant CLK_PERIOD : time := 10 ns;
    signal stop_clk : boolean := false;

begin

    DUT: entity work.pc
        port map (
            clk      => clk,
            reset    => reset,
            pc_write => pc_write,
            pc_next  => pc_next,
            pc_out   => pc_out
        );

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

    stimulus: process
    begin
        report "=== PC TESTLERI BASLIYOR ===" severity note;

        -- Test 1: reset → PC=0
        reset    <= '1';
        pc_write <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';
        assert pc_out = x"00000000"
            report "HATA [Test1]: reset sonrasi PC 0 degil" severity error;

        -- Test 2: pc_write='1' → adres 4 yükle
        pc_next  <= std_logic_vector(to_unsigned(4, 32));
        pc_write <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert pc_out = std_logic_vector(to_unsigned(4, 32))
            report "HATA [Test2]: pc_write sonrasi PC 4 degil" severity error;

        -- Test 3: pc_write='0' → değer korunmali (yeni pc_next gelse bile)
        pc_next  <= std_logic_vector(to_unsigned(999, 32));
        pc_write <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert pc_out = std_logic_vector(to_unsigned(4, 32))
            report "HATA [Test3]: pc_write=0 iken PC degisti" severity error;

        -- Test 4: pc_write='1' tekrar → bu sefer 8 yükle
        pc_next  <= std_logic_vector(to_unsigned(8, 32));
        pc_write <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert pc_out = std_logic_vector(to_unsigned(8, 32))
            report "HATA [Test4]: ikinci pc_write sonrasi PC 8 degil" severity error;

        -- Test 5: reset, pc_write='1' olsa bile kazanir → PC=0
        pc_next  <= std_logic_vector(to_unsigned(123, 32));
        pc_write <= '1';
        reset    <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert pc_out = x"00000000"
            report "HATA [Test5]: reset, pc_write'i yenmedi" severity error;

        report "=== TUM PC TESTLERI GECTI ===" severity note;
        stop_clk <= true;
        wait;
    end process;

end sim;
