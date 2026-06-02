-- ═══════════════════════════════════════════════════════════════════════════
-- tb_itype — slti / andi / ori / xori self-checking testbench (Faz 6)
-- ───────────────────────────────────────────────────────────────────────────
-- Diğer programlarda kullanılmayan 4 standart I-type komutu doğrular.
-- GEÇME ÖLÇÜTÜ: çıktıda hiç "** Error" satırı OLMAMALI.
--
-- NOT: test_itype.hex dosyası ModelSim'i çalıştırdığın klasörde olmalı.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_itype is
end tb_itype;

architecture sim of tb_itype is

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
        generic map ( INIT_FILE => "test_itype.hex" )
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
        report "=== ITYPE (slti/andi/ori/xori) TESTI BASLIYOR ===" severity note;

        reset <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';

        for i in 0 to 199 loop
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;

        check_reg(dbg_reg, dbg_data,  8, 12, "t0=12");
        check_reg(dbg_reg, dbg_data,  9,  1, "t1=slti 12<20");
        check_reg(dbg_reg, dbg_data, 10,  0, "t2=slti 12<5");
        check_reg(dbg_reg, dbg_data, 11,  0, "t3=slti 12<12");
        check_reg(dbg_reg, dbg_data, 12,  8, "t4=andi 12&10");
        check_reg(dbg_reg, dbg_data, 13, 15, "t5=ori 12|3");
        check_reg(dbg_reg, dbg_data, 14,  6, "t6=xori 12^10");
        check_reg(dbg_reg, dbg_data, 15, -3, "t7=-3");
        check_reg(dbg_reg, dbg_data, 16,  1, "s0=slti -3<0");
        check_reg(dbg_reg, dbg_data, 17,  0, "s1=slti -3<-5");

        report "=== TUM ITYPE TESTLERI GECTI (Error yoksa) ===" severity note;
        stop_clk <= true;
        wait;
    end process;

end sim;
