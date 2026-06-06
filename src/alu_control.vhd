-- ═══════════════════════════════════════════════════════════════════════════
-- ALU Control — opcode/funct'tan ALU'nun 4-bit işlem kodunu (alu_ctrl) üretir
-- ───────────────────────────────────────────────────────────────────────────
-- control_unit 2-bit 'alu_op' ipucu verir; bu modül 4-bit alu_ctrl'ü çözer.
-- Böylece FSM her R-type funct'ını bilmek zorunda kalmaz.
--   alu_op = "00" → ADD'e zorla  (PC+4, branch hedefi, lw/sw adres, ADDI3)
--   alu_op = "01" → SUB'a zorla  (beq/bne/bgt karşılaştırması)
--   alu_op = "10" → komuta bak   (R-type→funct, I-type aritmetik→opcode)
-- Çıkış kodları alu.vhd ile AYNI olmak zorunda (sözleşme).
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity alu_control is
    Port (
        alu_op   : in  STD_LOGIC_VECTOR(1 downto 0);
        opcode   : in  STD_LOGIC_VECTOR(5 downto 0);
        funct    : in  STD_LOGIC_VECTOR(5 downto 0);
        alu_ctrl : out STD_LOGIC_VECTOR(3 downto 0)
    );
end alu_control;

architecture Behavioral of alu_control is

    -- ALU işlem kodları (alu.vhd ile AYNI)
    constant OP_AND : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    constant OP_OR  : STD_LOGIC_VECTOR(3 downto 0) := "0001";
    constant OP_ADD : STD_LOGIC_VECTOR(3 downto 0) := "0010";
    constant OP_XOR : STD_LOGIC_VECTOR(3 downto 0) := "0011";
    constant OP_SUB : STD_LOGIC_VECTOR(3 downto 0) := "0110";
    constant OP_SLT : STD_LOGIC_VECTOR(3 downto 0) := "0111";
    constant OP_MUL : STD_LOGIC_VECTOR(3 downto 0) := "1000";

    -- R-type funct kodları (assembler.py R_FUNCT ile AYNI)
    constant F_ADD  : STD_LOGIC_VECTOR(5 downto 0) := "100000";  -- 0x20
    constant F_SUB  : STD_LOGIC_VECTOR(5 downto 0) := "100010";  -- 0x22
    constant F_AND  : STD_LOGIC_VECTOR(5 downto 0) := "100100";  -- 0x24
    constant F_OR   : STD_LOGIC_VECTOR(5 downto 0) := "100101";  -- 0x25
    constant F_XOR  : STD_LOGIC_VECTOR(5 downto 0) := "100110";  -- 0x26
    constant F_SLT  : STD_LOGIC_VECTOR(5 downto 0) := "101010";  -- 0x2a
    constant F_MUL  : STD_LOGIC_VECTOR(5 downto 0) := "101100";  -- 0x2c

    -- I-type opcode kodları (assembler.py I_OPCODE ile AYNI)
    constant OPC_ADDI  : STD_LOGIC_VECTOR(5 downto 0) := "001000";  -- 0x08
    constant OPC_SLTI  : STD_LOGIC_VECTOR(5 downto 0) := "001010";  -- 0x0a
    constant OPC_ANDI  : STD_LOGIC_VECTOR(5 downto 0) := "001100";  -- 0x0c
    constant OPC_ORI   : STD_LOGIC_VECTOR(5 downto 0) := "001101";  -- 0x0d
    constant OPC_XORI  : STD_LOGIC_VECTOR(5 downto 0) := "001110";  -- 0x0e
    constant OPC_LOADI : STD_LOGIC_VECTOR(5 downto 0) := "010001";  -- 0x11

begin

    process(alu_op, opcode, funct)
    begin
        case alu_op is

            when "00" =>
                alu_ctrl <= OP_ADD;

            when "01" =>
                alu_ctrl <= OP_SUB;

            when others =>   -- "10": komuta göre çöz
                if opcode = "000000" then
                    case funct is
                        when F_ADD  => alu_ctrl <= OP_ADD;
                        when F_SUB  => alu_ctrl <= OP_SUB;
                        when F_AND  => alu_ctrl <= OP_AND;
                        when F_OR   => alu_ctrl <= OP_OR;
                        when F_XOR  => alu_ctrl <= OP_XOR;
                        when F_SLT  => alu_ctrl <= OP_SLT;
                        when F_MUL  => alu_ctrl <= OP_MUL;
                        when others => alu_ctrl <= OP_ADD;
                    end case;
                else
                    case opcode is
                        when OPC_ADDI  => alu_ctrl <= OP_ADD;
                        when OPC_SLTI  => alu_ctrl <= OP_SLT;
                        when OPC_ANDI  => alu_ctrl <= OP_AND;
                        when OPC_ORI   => alu_ctrl <= OP_OR;
                        when OPC_XORI  => alu_ctrl <= OP_XOR;
                        when OPC_LOADI => alu_ctrl <= OP_ADD;  -- 0 + imm
                        when others    => alu_ctrl <= OP_ADD;
                    end case;
                end if;

        end case;
    end process;

end Behavioral;
