-- ═══════════════════════════════════════════════════════════════════════════
-- tb_instruction_register — IR için self-checking testbench
-- ───────────────────────────────────────────────────────────────────────────
-- Test edilenler:
--   1. ir_write='1' → komut yüklenir ve alanlar doğru bölünür
--   2. ir_write='0' → komut korunur (yeni komut gelse bile alanlar değişmez)
--
-- Test komutu (bilinen bit deseni):  0x08A63A24
--   opcode=000010 rs=00101 rt=00110 rd=00111 shamt=01000 funct=100100
--   immediate(15..0)=0x3A24   address(25..0)="00"&x"A63A24"
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_instruction_register is
end tb_instruction_register;

architecture sim of tb_instruction_register is

    signal clk      : STD_LOGIC := '0';
    signal ir_write : STD_LOGIC := '0';
    signal instr_in : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');

    signal opcode    : STD_LOGIC_VECTOR(5 downto 0);
    signal rs        : STD_LOGIC_VECTOR(4 downto 0);
    signal rt        : STD_LOGIC_VECTOR(4 downto 0);
    signal rd        : STD_LOGIC_VECTOR(4 downto 0);
    signal shamt     : STD_LOGIC_VECTOR(4 downto 0);
    signal funct     : STD_LOGIC_VECTOR(5 downto 0);
    signal immediate : STD_LOGIC_VECTOR(15 downto 0);
    signal address   : STD_LOGIC_VECTOR(25 downto 0);
    signal instr_out : STD_LOGIC_VECTOR(31 downto 0);

    constant CLK_PERIOD : time := 10 ns;
    signal stop_clk : boolean := false;

begin

    DUT: entity work.instruction_register
        port map (
            clk       => clk,
            ir_write  => ir_write,
            instr_in  => instr_in,
            opcode    => opcode,
            rs        => rs,
            rt        => rt,
            rd        => rd,
            shamt     => shamt,
            funct     => funct,
            immediate => immediate,
            address   => address,
            instr_out => instr_out
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
        report "=== INSTRUCTION_REGISTER TESTLERI BASLIYOR ===" severity note;

        -- Test 1: komutu yükle ve tüm alanları kontrol et
        instr_in <= x"08A63A24";
        ir_write <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert instr_out = x"08A63A24"
            report "HATA [Test1]: instr_out yuklenmedi" severity error;
        assert opcode = "000010"
            report "HATA [Test1]: opcode yanlis" severity error;
        assert rs = "00101"
            report "HATA [Test1]: rs yanlis" severity error;
        assert rt = "00110"
            report "HATA [Test1]: rt yanlis" severity error;
        assert rd = "00111"
            report "HATA [Test1]: rd yanlis" severity error;
        assert shamt = "01000"
            report "HATA [Test1]: shamt yanlis" severity error;
        assert funct = "100100"
            report "HATA [Test1]: funct yanlis" severity error;
        assert immediate = x"3A24"
            report "HATA [Test1]: immediate yanlis" severity error;
        assert address = "00" & x"A63A24"
            report "HATA [Test1]: address yanlis" severity error;

        -- Test 2: ir_write='0' iken yeni komut gelse bile korunmali
        instr_in <= x"FFFFFFFF";
        ir_write <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert instr_out = x"08A63A24"
            report "HATA [Test2]: ir_write=0 iken komut degisti" severity error;
        assert opcode = "000010"
            report "HATA [Test2]: ir_write=0 iken opcode degisti" severity error;

        report "=== TUM INSTRUCTION_REGISTER TESTLERI GECTI ===" severity note;
        stop_clk <= true;
        wait;
    end process;

end sim;
