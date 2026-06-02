-- ═══════════════════════════════════════════════════════════════════════════
-- tb_stack — push / pop / swap (Faz 5) için self-checking testbench
-- ───────────────────────────────────────────────────────────────────────────
-- test_stack.hex programını koşturur, sonra register'ları kontrol eder.
-- Beklenen: $t0=22 $t1=11 $t2=11 $t3=22 $sp=400
--
-- NOT: test_stack.hex dosyası ModelSim'i çalıştırdığın klasörde olmalı.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_stack is
end tb_stack;

architecture sim of tb_stack is

    signal clk      : STD_LOGIC := '0';
    signal reset    : STD_LOGIC := '0';
    signal dbg_reg  : STD_LOGIC_VECTOR(4 downto 0)  := (others => '0');
    signal dbg_data : STD_LOGIC_VECTOR(31 downto 0);
    signal pc_debug : STD_LOGIC_VECTOR(31 downto 0);
    signal instr_dbg: STD_LOGIC_VECTOR(31 downto 0);

    constant CLK_PERIOD : time := 10 ns;
    signal stop_clk : boolean := false;

    procedure check_reg(
        signal   s_sel  : out STD_LOGIC_VECTOR(4 downto 0);
        signal   s_data : in  STD_LOGIC_VECTOR(31 downto 0);
        constant regno  : in  integer;
        constant exp    : in  integer;
        constant name   : in  string
    ) is
    begin
        s_sel <= std_logic_vector(to_unsigned(regno, 5));
        wait for 2 ns;
        assert s_data = std_logic_vector(to_signed(exp, 32))
            report "HATA [" & name & "]: beklenen=" & integer'image(exp) &
                   " bulunan=" & integer'image(to_integer(signed(s_data)))
            severity error;
    end procedure;

begin

    DUT: entity work.cpu
        generic map ( INIT_FILE => "test_stack.hex" )
        port map (
            clk         => clk,
            reset       => reset,
            dbg_reg     => dbg_reg,
            dbg_data    => dbg_data,
            pc_debug    => pc_debug,
            instr_debug => instr_dbg
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
        report "=== STACK (push/pop/swap) TESTI BASLIYOR ===" severity note;

        reset <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';

        for i in 0 to 99 loop
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;

        check_reg(dbg_reg, dbg_data,  8, 22, "t0=swap");
        check_reg(dbg_reg, dbg_data,  9, 11, "t1=swap");
        check_reg(dbg_reg, dbg_data, 10, 11, "t2=pop");
        check_reg(dbg_reg, dbg_data, 11, 22, "t3=pop");
        check_reg(dbg_reg, dbg_data, 29, 400, "sp geri 400");

        report "=== TUM STACK TESTLERI GECTI ===" severity note;
        stop_clk <= true;
        wait;
    end process;

end sim;
