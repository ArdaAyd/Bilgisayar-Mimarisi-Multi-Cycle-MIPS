-- ═══════════════════════════════════════════════════════════════════════════
-- tb_edge — UÇ DURUM (edge case) self-checking testbench (Faz 6)
-- ───────────────────────────────────────────────────────────────────────────
-- test_edge.hex programını koşturur: negatif sayılar, $0 koruması, işaretli
-- karşılaştırma, eşitlikte dallanmama, geriye dallanma, nested push/pop.
-- Sonra 25 register'ı doğrular.
--
-- GEÇME ÖLÇÜTÜ: çıktıda hiç "** Error" satırı OLMAMALI.
-- (assert severity=error testi durdurmaz; "GECTI" yazısının kendisi yeterli değil.)
--
-- NOT: test_edge.hex dosyası ModelSim'i çalıştırdığın klasörde olmalı.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_edge is
end tb_edge;

architecture sim of tb_edge is

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
        generic map ( INIT_FILE => "test_edge.hex" )
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
        report "=== EDGE (uc durum) TESTI BASLIYOR ===" severity note;

        reset <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';

        for i in 0 to 499 loop
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;

        -- ── TEST 1: $0 korumasi ──
        check_reg(dbg_reg, dbg_data,  0,   0, "zero korundu");

        -- ── Negatif / isaretli ──
        check_reg(dbg_reg, dbg_data,  8,   7, "t0=7");
        check_reg(dbg_reg, dbg_data,  9,  -5, "t1=-5 loadi");
        check_reg(dbg_reg, dbg_data, 10,   1, "t2=slt -5<0");
        check_reg(dbg_reg, dbg_data, 11,   0, "t3=slt 0<-5");
        check_reg(dbg_reg, dbg_data, 12,   3, "t4=3");
        check_reg(dbg_reg, dbg_data, 13,  10, "t5=10");
        check_reg(dbg_reg, dbg_data, 14,  -7, "t6=sub 3-10");
        check_reg(dbg_reg, dbg_data, 15,   3, "t7=3");
        check_reg(dbg_reg, dbg_data, 16, -15, "s0=mul -5*3");

        -- ── Bit maskeleme (-1 = 0xFFFFFFFF) ──
        check_reg(dbg_reg, dbg_data, 17,  -1, "s1=-1");
        check_reg(dbg_reg, dbg_data, 18,  10, "s2=and 10&-1");
        check_reg(dbg_reg, dbg_data, 19, -11, "s3=xor 10^-1");
        check_reg(dbg_reg, dbg_data, 20,  -1, "s4=or 0|-1");

        -- ── addi3 negatif imm ──
        check_reg(dbg_reg, dbg_data, 21,   9, "s5=addi3 10+3-4");

        -- ── bgt dallanma kontrolu ──
        check_reg(dbg_reg, dbg_data, 22,   1, "s6=1 (bgt taken, 99 atlandi)");
        check_reg(dbg_reg, dbg_data, 23,  77, "s7=77 (bgt esitlikte dallanmadi)");

        -- ── Geriye dallanma (countdown) ──
        check_reg(dbg_reg, dbg_data, 24,   0, "t8=0 (countdown bitti)");
        check_reg(dbg_reg, dbg_data, 25,   5, "t9=5 (5 kez dondu)");

        -- ── Nested push/pop (LIFO) ──
        check_reg(dbg_reg, dbg_data, 26, 100, "k0=100");
        check_reg(dbg_reg, dbg_data, 27, 200, "k1=200");
        check_reg(dbg_reg, dbg_data, 30, 300, "fp=300 (ilk pop)");
        check_reg(dbg_reg, dbg_data, 31, 200, "ra=200 (ikinci pop)");
        check_reg(dbg_reg, dbg_data, 28, 100, "gp=100 (ucuncu pop)");
        check_reg(dbg_reg, dbg_data, 29, 400, "sp geri 400");

        report "=== TUM EDGE TESTLERI GECTI (Error yoksa) ===" severity note;
        stop_clk <= true;
        wait;
    end process;

end sim;
