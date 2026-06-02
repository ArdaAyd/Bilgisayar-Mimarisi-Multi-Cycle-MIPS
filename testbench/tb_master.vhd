-- ═══════════════════════════════════════════════════════════════════════════
-- tb_master — KAPSAMLI "MASTER" self-checking testbench (Faz 6)
-- ───────────────────────────────────────────────────────────────────────────
-- test_master.hex programını koşturur (dizi kur → döngüyle topla/maks →
-- aritmetik/mantık → stack it/çek/swap), sonra 18 register'ı doğrular.
--
-- Beklenen son değerler:
--   $t0=200 $t1=3  $t2=16 $t3=16 $t4=212 $t5=10
--   $t6=16  $t7=10
--   $s0=26  $s1=10 $s2=26 $s3=16 $s4=1  $s5=30 $s6=40
--   $t8=26  $t9=10
--   $sp=400
--
-- NOT: test_master.hex dosyası ModelSim'i çalıştırdığın klasörde olmalı.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_master is
end tb_master;

architecture sim of tb_master is

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
        generic map ( INIT_FILE => "test_master.hex" )
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
        report "=== MASTER (kapsamli) TESTI BASLIYOR ===" severity note;

        reset <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';

        -- Program ~60 komut koşturur (döngü dahil); bol cycle ver.
        for i in 0 to 599 loop
            wait until rising_edge(clk);
        end loop;
        wait for 1 ns;

        -- ── Geçici register'lar (dizi/döngü kalıntıları) ──
        check_reg(dbg_reg, dbg_data,  8, 200, "t0=base");
        check_reg(dbg_reg, dbg_data,  9,   3, "t1=son loadi");
        check_reg(dbg_reg, dbg_data, 10,  16, "t2=i son");
        check_reg(dbg_reg, dbg_data, 11,  16, "t3=son sabit");
        check_reg(dbg_reg, dbg_data, 12, 212, "t4=son addr");
        check_reg(dbg_reg, dbg_data, 13,  10, "t5=son val");

        -- ── Aritmetik/mantık sonuçları ──
        check_reg(dbg_reg, dbg_data, 14,  16, "t6=sub 26-10");
        check_reg(dbg_reg, dbg_data, 15,  10, "t7=and 26&10");
        check_reg(dbg_reg, dbg_data, 16,  26, "s0=sum");
        check_reg(dbg_reg, dbg_data, 17,  10, "s1=max");
        check_reg(dbg_reg, dbg_data, 18,  26, "s2=or 26|10");
        check_reg(dbg_reg, dbg_data, 19,  16, "s3=xor 26^10");
        check_reg(dbg_reg, dbg_data, 20,   1, "s4=slt 10<26");
        check_reg(dbg_reg, dbg_data, 21,  30, "s5=mul 10*3");
        check_reg(dbg_reg, dbg_data, 22,  40, "s6=addi3 26+10+4");

        -- ── Stack + swap sonuçları ──
        check_reg(dbg_reg, dbg_data, 24,  26, "t8=swap sonrasi");
        check_reg(dbg_reg, dbg_data, 25,  10, "t9=swap sonrasi");
        check_reg(dbg_reg, dbg_data, 29, 400, "sp geri 400");

        report "=== TUM MASTER TESTLERI GECTI ===" severity note;
        stop_clk <= true;
        wait;
    end process;

end sim;
