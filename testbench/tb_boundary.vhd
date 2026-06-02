-- ═══════════════════════════════════════════════════════════════════════════
-- tb_boundary — SINIR DURUMLARI self-checking testbench (Faz 6)
-- ───────────────────────────────────────────────────────────────────────────
-- PDF "Sınır Durumları": Overflow, Bellek sınırları, Branch alanı.
-- GEÇME ÖLÇÜTÜ: çıktıda hiç "** Error" satırı OLMAMALI.
--
-- NOT: test_boundary.hex dosyası ModelSim'i çalıştırdığın klasörde olmalı.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_boundary is
end tb_boundary;

architecture sim of tb_boundary is

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
        generic map ( INIT_FILE => "test_boundary.hex" )
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
        report "=== BOUNDARY (sinir durumlari) TESTI BASLIYOR ===" severity note;

        reset <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';

        for i in 0 to 199 loop
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;

        -- ── Overflow (32-bit işaretli taşma / wraparound) ──
        check_reg(dbg_reg, dbg_data,  8,       30000, "t0=30000");
        check_reg(dbg_reg, dbg_data,  9,   900000000, "t1=mul 30000^2");
        check_reg(dbg_reg, dbg_data, 10,  1800000000, "t2=add (sigar)");
        check_reg(dbg_reg, dbg_data, 11, -1594967296, "t3=add TASTI (wrap)");

        -- ── Bellek sınırı (en üst word 255) ──
        check_reg(dbg_reg, dbg_data, 12,        1020, "t4=adres 1020");
        check_reg(dbg_reg, dbg_data, 13,       12345, "t5=yazilan deger");
        check_reg(dbg_reg, dbg_data, 14,       12345, "t6=MEM[1020] geri okundu");

        -- ── Branch alanı (ileri dallanma) ──
        check_reg(dbg_reg, dbg_data, 15,           0, "t7=0");
        check_reg(dbg_reg, dbg_data, 16,           7, "s0=7 (branch atladi)");

        report "=== TUM BOUNDARY TESTLERI GECTI (Error yoksa) ===" severity note;
        stop_clk <= true;
        wait;
    end process;

end sim;
