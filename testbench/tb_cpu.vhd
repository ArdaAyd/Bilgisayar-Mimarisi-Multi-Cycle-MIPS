-- ═══════════════════════════════════════════════════════════════════════════
-- tb_cpu — tam CPU için self-checking entegrasyon testbench'i
-- ───────────────────────────────────────────────────────────────────────────
-- test_cpu.hex programını belleğe yükler, reset verir, programın bitmesi için
-- yeterli saykıl koşturur, sonra dbg_reg/dbg_data portundan her register'ın
-- beklenen değerde olduğunu kontrol eder.
--
-- Beklenen son değerler (test_cpu.asm'den):
--   $t0=5 $t1=7 $t2=12 $t3=2 $t4=5 $t5=7 $t6=2 $t7=1
--   $s0=35 $s1=15 $s2=15 $s3=12 $s4=0 $s5=0 $s6=0 $s7=0
--
-- NOT: test_cpu.hex dosyası ModelSim'i çalıştırdığın klasörde olmalı.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_cpu is
end tb_cpu;

architecture sim of tb_cpu is

    signal clk      : STD_LOGIC := '0';
    signal reset    : STD_LOGIC := '0';
    signal dbg_reg  : STD_LOGIC_VECTOR(4 downto 0)  := (others => '0');
    signal dbg_data : STD_LOGIC_VECTOR(31 downto 0);
    signal pc_debug : STD_LOGIC_VECTOR(31 downto 0);
    signal instr_dbg: STD_LOGIC_VECTOR(31 downto 0);

    constant CLK_PERIOD : time := 10 ns;
    signal stop_clk : boolean := false;

    -- Bir register'ı okuyup beklenen değerle karşılaştıran yardımcı.
    procedure check_reg(
        signal   s_sel  : out STD_LOGIC_VECTOR(4 downto 0);
        signal   s_data : in  STD_LOGIC_VECTOR(31 downto 0);
        constant regno  : in  integer;
        constant exp    : in  integer;
        constant name   : in  string
    ) is
    begin
        s_sel <= std_logic_vector(to_unsigned(regno, 5));
        wait for 2 ns;   -- asenkron okuma otursun
        assert s_data = std_logic_vector(to_signed(exp, 32))
            report "HATA [" & name & "]: beklenen=" & integer'image(exp) &
                   " bulunan=" & integer'image(to_integer(signed(s_data)))
            severity error;
    end procedure;

begin

    -- ── DUT: programı belleğe yükle ──
    DUT: entity work.cpu
        generic map ( INIT_FILE => "test_cpu.hex" )
        port map (
            clk         => clk,
            reset       => reset,
            dbg_reg     => dbg_reg,
            dbg_data    => dbg_data,
            pc_debug    => pc_debug,
            instr_debug => instr_dbg
        );

    -- ── Clock ──
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

    -- ── Test ──
    stimulus: process
    begin
        report "=== CPU ENTEGRASYON TESTI BASLIYOR ===" severity note;

        -- Reset: 2 saykıl boyunca tut, sonra bırak
        reset <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';

        -- Programın bitip HALT döngüsüne girmesi için yeterince koş (~160 saykıl)
        for i in 0 to 159 loop
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;

        -- ── Sonuç register'larını kontrol et ──
        check_reg(dbg_reg, dbg_data,  8,  5, "t0=5");
        check_reg(dbg_reg, dbg_data,  9,  7, "t1=7");
        check_reg(dbg_reg, dbg_data, 10, 12, "t2=add");
        check_reg(dbg_reg, dbg_data, 11,  2, "t3=sub");
        check_reg(dbg_reg, dbg_data, 12,  5, "t4=and");
        check_reg(dbg_reg, dbg_data, 13,  7, "t5=or");
        check_reg(dbg_reg, dbg_data, 14,  2, "t6=xor");
        check_reg(dbg_reg, dbg_data, 15,  1, "t7=slt");
        check_reg(dbg_reg, dbg_data, 16, 35, "s0=mul");
        check_reg(dbg_reg, dbg_data, 17, 15, "s1=addi");
        check_reg(dbg_reg, dbg_data, 18, 15, "s2=addi3");
        check_reg(dbg_reg, dbg_data, 19, 12, "s3=lw");
        check_reg(dbg_reg, dbg_data, 20,  0, "s4=beq atladi");
        check_reg(dbg_reg, dbg_data, 21,  0, "s5=bne atladi");
        check_reg(dbg_reg, dbg_data, 22,  0, "s6=bgt atladi");
        check_reg(dbg_reg, dbg_data, 23,  0, "s7=j atladi");

        report "=== TUM CPU ENTEGRASYON TESTLERI GECTI ===" severity note;
        stop_clk <= true;
        wait;
    end process;

end sim;
