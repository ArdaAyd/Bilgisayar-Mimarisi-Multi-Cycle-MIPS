-- ═══════════════════════════════════════════════════════════════════════════
-- ALU (Arithmetic Logic Unit) — CPU'nun hesap makinesi
-- ───────────────────────────────────────────────────────────────────────────
-- İki 32-bit sayı (a, b) alır, alu_ctrl'ün söylediği işlemi yapar,
-- 32-bit sonuç (result) ve sonuç-sıfır-mı bilgisini (zero) üretir.
-- Kombinasyonel devre: clock yok.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu is
    Port (
        a        : in  STD_LOGIC_VECTOR(31 downto 0);
        b        : in  STD_LOGIC_VECTOR(31 downto 0);
        alu_ctrl : in  STD_LOGIC_VECTOR(3 downto 0);
        result   : out STD_LOGIC_VECTOR(31 downto 0);
        zero     : out STD_LOGIC
    );
end alu;

architecture Behavioral of alu is

    -- İşlem kodları alu_control.vhd ile birebir aynı olmak zorunda.
    constant OP_AND : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    constant OP_OR  : STD_LOGIC_VECTOR(3 downto 0) := "0001";
    constant OP_ADD : STD_LOGIC_VECTOR(3 downto 0) := "0010";
    constant OP_XOR : STD_LOGIC_VECTOR(3 downto 0) := "0011";
    constant OP_SUB : STD_LOGIC_VECTOR(3 downto 0) := "0110";
    constant OP_SLT : STD_LOGIC_VECTOR(3 downto 0) := "0111";
    constant OP_MUL : STD_LOGIC_VECTOR(3 downto 0) := "1000";

    signal res : STD_LOGIC_VECTOR(31 downto 0);

begin

    process(a, b, alu_ctrl)
    begin
        case alu_ctrl is

            when OP_ADD =>
                res <= std_logic_vector(signed(a) + signed(b));

            when OP_SUB =>
                res <= std_logic_vector(signed(a) - signed(b));

            when OP_AND =>
                res <= a and b;

            when OP_OR =>
                res <= a or b;

            when OP_XOR =>
                res <= a xor b;

            when OP_SLT =>
                if signed(a) < signed(b) then   -- işaretli karşılaştırma
                    res <= x"00000001";
                else
                    res <= x"00000000";
                end if;

            -- davranışsal çarpma; sentezde çok-cycle çarpıcıya genişletilebilir
            when OP_MUL =>
                res <= std_logic_vector(resize(signed(a) * signed(b), 32));

            when others =>
                res <= x"00000000";

        end case;
    end process;

    result <= res;
    zero   <= '1' when res = x"00000000" else '0';

end Behavioral;
