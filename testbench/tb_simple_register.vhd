-- ═══════════════════════════════════════════════════════════════════════════
-- tb_simple_register — genel amaçlı register için self-checking testbench
-- ───────────────────────────────────────────────────────────────────────────
-- Test edilenler:
--   1. en='1' → değer yüklenir
--   2. en='0' → değer korunur (yeni d gelse bile)
--   3. en='1' tekrar → yeni değer yüklenir
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_simple_register is
end tb_simple_register;

architecture sim of tb_simple_register is

    signal clk : STD_LOGIC := '0';
    signal en  : STD_LOGIC := '0';
    signal d   : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal q   : STD_LOGIC_VECTOR(31 downto 0);

    constant CLK_PERIOD : time := 10 ns;
    signal stop_clk : boolean := false;

begin

    DUT: entity work.simple_register
        port map (
            clk => clk,
            en  => en,
            d   => d,
            q   => q
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
        report "=== SIMPLE_REGISTER TESTLERI BASLIYOR ===" severity note;

        -- Test 1: en='1' → 100 yükle
        d  <= std_logic_vector(to_unsigned(100, 32));
        en <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = std_logic_vector(to_unsigned(100, 32))
            report "HATA [Test1]: en=1 iken 100 yuklenmedi" severity error;

        -- Test 2: en='0' → değer korunmali (yeni d=777 gelse bile)
        d  <= std_logic_vector(to_unsigned(777, 32));
        en <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = std_logic_vector(to_unsigned(100, 32))
            report "HATA [Test2]: en=0 iken deger degisti" severity error;

        -- Test 3: en='1' tekrar → 777 yüklenmeli
        en <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = std_logic_vector(to_unsigned(777, 32))
            report "HATA [Test3]: en=1 iken 777 yuklenmedi" severity error;

        report "=== TUM SIMPLE_REGISTER TESTLERI GECTI ===" severity note;
        stop_clk <= true;
        wait;
    end process;

end sim;
