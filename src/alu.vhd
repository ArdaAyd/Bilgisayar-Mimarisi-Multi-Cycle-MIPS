-- ═══════════════════════════════════════════════════════════════════════════
-- ALU (Arithmetic Logic Unit) — CPU'nun hesap makinesi
-- ───────────────────────────────────────────────────────────────────────────
-- İki 32-bit sayı (a, b) alır, alu_ctrl'ün söylediği işlemi yapar,
-- 32-bit sonuç (result) ve sonuç-sıfır-mı bilgisini (zero) üretir.
--
-- Kombinasyonel devre: clock yok. Girişler değişince çıkış anında güncellenir.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;   -- signed/unsigned aritmetiği için

entity alu is
    Port (
        a        : in  STD_LOGIC_VECTOR(31 downto 0);  -- 1. operand
        b        : in  STD_LOGIC_VECTOR(31 downto 0);  -- 2. operand
        alu_ctrl : in  STD_LOGIC_VECTOR(3 downto 0);   -- yapılacak işlem
        result   : out STD_LOGIC_VECTOR(31 downto 0);  -- işlem sonucu
        zero     : out STD_LOGIC                        -- result = 0 ise '1'
    );
end alu;

architecture Behavioral of alu is

    -- İşlem kodları — okunabilirlik için sabit isim verdik.
    -- Bu kodlar alu_control.vhd ile AYNI olmak zorunda (sözleşme).
    constant OP_AND : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    constant OP_OR  : STD_LOGIC_VECTOR(3 downto 0) := "0001";
    constant OP_ADD : STD_LOGIC_VECTOR(3 downto 0) := "0010";
    constant OP_XOR : STD_LOGIC_VECTOR(3 downto 0) := "0011";
    constant OP_SUB : STD_LOGIC_VECTOR(3 downto 0) := "0110";
    constant OP_SLT : STD_LOGIC_VECTOR(3 downto 0) := "0111";
    constant OP_MUL : STD_LOGIC_VECTOR(3 downto 0) := "1000";

    -- İç sinyal: sonucu önce buraya yazıp hem result'a hem zero'ya bağlayacağız.
    signal res : STD_LOGIC_VECTOR(31 downto 0);

begin

    -- ── İşlem seçimi ──────────────────────────────────────────────────────
    -- process: girişlerden (a, b, alu_ctrl) herhangi biri değişince çalışır.
    process(a, b, alu_ctrl)
    begin
        case alu_ctrl is

            -- Toplama (işaretli): add, addi, lw/sw adres, addi3, push/pop
            when OP_ADD =>
                res <= std_logic_vector(signed(a) + signed(b));

            -- Çıkarma (işaretli): sub, beq/bne/bgt karşılaştırması
            when OP_SUB =>
                res <= std_logic_vector(signed(a) - signed(b));

            -- Bit-bazlı VE
            when OP_AND =>
                res <= a and b;

            -- Bit-bazlı VEYA
            when OP_OR =>
                res <= a or b;

            -- Bit-bazlı XOR (özel veya)
            when OP_XOR =>
                res <= a xor b;

            -- Set Less Than: a < b ise 1, değilse 0 (işaretli karşılaştırma)
            when OP_SLT =>
                if signed(a) < signed(b) then
                    res <= x"00000001";
                else
                    res <= x"00000000";
                end if;

            -- Çarpma (davranışsal): 32x32 çarpımın alt 32 biti
            -- Not: raporda "davranışsal; sentezde çok-cycle çarpıcıya
            -- genişletilebilir" diye belirtilecek.
            when OP_MUL =>
                res <= std_logic_vector(resize(signed(a) * signed(b), 32));

            -- Tanımsız kod gelirse güvenli varsayılan: 0
            when others =>
                res <= x"00000000";

        end case;
    end process;

    -- ── Çıkışlar ──────────────────────────────────────────────────────────
    result <= res;

    -- zero bayrağı: sonucun tamamı 0 ise '1'. Branch komutları kullanır.
    zero <= '1' when res = x"00000000" else '0';

end Behavioral;
