-- ═══════════════════════════════════════════════════════════════════════════
-- tb_alu_control — ALU Control için self-checking testbench
-- ───────────────────────────────────────────────────────────────────────────
-- Her (alu_op, opcode, funct) kombinasyonunun doğru alu_ctrl ürettiğini test eder.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_alu_control is
end tb_alu_control;

architecture sim of tb_alu_control is

    signal alu_op   : STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
    signal opcode   : STD_LOGIC_VECTOR(5 downto 0) := (others => '0');
    signal funct    : STD_LOGIC_VECTOR(5 downto 0) := (others => '0');
    signal alu_ctrl : STD_LOGIC_VECTOR(3 downto 0);

    -- ALU işlem kodları (alu.vhd ile aynı)
    constant OP_AND : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    constant OP_OR  : STD_LOGIC_VECTOR(3 downto 0) := "0001";
    constant OP_ADD : STD_LOGIC_VECTOR(3 downto 0) := "0010";
    constant OP_XOR : STD_LOGIC_VECTOR(3 downto 0) := "0011";
    constant OP_SUB : STD_LOGIC_VECTOR(3 downto 0) := "0110";
    constant OP_SLT : STD_LOGIC_VECTOR(3 downto 0) := "0111";
    constant OP_MUL : STD_LOGIC_VECTOR(3 downto 0) := "1000";

    -- Tek bir durumu kontrol eden yardımcı procedure.
    procedure check(
        signal   s_op    : out STD_LOGIC_VECTOR(1 downto 0);
        signal   s_opc   : out STD_LOGIC_VECTOR(5 downto 0);
        signal   s_fun   : out STD_LOGIC_VECTOR(5 downto 0);
        signal   s_ctrl  : in  STD_LOGIC_VECTOR(3 downto 0);
        constant in_op   : in  STD_LOGIC_VECTOR(1 downto 0);
        constant in_opc  : in  STD_LOGIC_VECTOR(5 downto 0);
        constant in_fun  : in  STD_LOGIC_VECTOR(5 downto 0);
        constant exp     : in  STD_LOGIC_VECTOR(3 downto 0);
        constant name    : in  string
    ) is
    begin
        s_op  <= in_op;
        s_opc <= in_opc;
        s_fun <= in_fun;
        wait for 5 ns;
        assert s_ctrl = exp
            report "HATA [" & name & "]: alu_ctrl yanlis" severity error;
    end procedure;

begin

    DUT: entity work.alu_control
        port map ( alu_op => alu_op, opcode => opcode, funct => funct,
                   alu_ctrl => alu_ctrl );

    stimulus: process
    begin
        report "=== ALU_CONTROL TESTLERI BASLIYOR ===" severity note;

        -- alu_op=00 → her zaman ADD
        check(alu_op,opcode,funct,alu_ctrl, "00","000000","000000", OP_ADD, "force ADD");
        -- alu_op=01 → her zaman SUB
        check(alu_op,opcode,funct,alu_ctrl, "01","000100","000000", OP_SUB, "force SUB");

        -- alu_op=10, R-type (opcode=000000) → funct'a göre
        check(alu_op,opcode,funct,alu_ctrl, "10","000000","100000", OP_ADD, "R add");
        check(alu_op,opcode,funct,alu_ctrl, "10","000000","100010", OP_SUB, "R sub");
        check(alu_op,opcode,funct,alu_ctrl, "10","000000","100100", OP_AND, "R and");
        check(alu_op,opcode,funct,alu_ctrl, "10","000000","100101", OP_OR,  "R or");
        check(alu_op,opcode,funct,alu_ctrl, "10","000000","100110", OP_XOR, "R xor");
        check(alu_op,opcode,funct,alu_ctrl, "10","000000","101010", OP_SLT, "R slt");
        check(alu_op,opcode,funct,alu_ctrl, "10","000000","101100", OP_MUL, "R mul");

        -- alu_op=10, I-type → opcode'a göre
        check(alu_op,opcode,funct,alu_ctrl, "10","001000","000000", OP_ADD, "addi");
        check(alu_op,opcode,funct,alu_ctrl, "10","001010","000000", OP_SLT, "slti");
        check(alu_op,opcode,funct,alu_ctrl, "10","001100","000000", OP_AND, "andi");
        check(alu_op,opcode,funct,alu_ctrl, "10","001101","000000", OP_OR,  "ori");
        check(alu_op,opcode,funct,alu_ctrl, "10","001110","000000", OP_XOR, "xori");
        check(alu_op,opcode,funct,alu_ctrl, "10","010001","000000", OP_ADD, "loadi");

        report "=== TUM ALU_CONTROL TESTLERI GECTI ===" severity note;
        wait;
    end process;

end sim;
