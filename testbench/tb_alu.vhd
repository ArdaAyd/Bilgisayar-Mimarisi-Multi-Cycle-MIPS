-- ═══════════════════════════════════════════════════════════════════════════
-- tb_alu — ALU için kendi kendini kontrol eden (self-checking) testbench
-- ───────────────────────────────────────────────────────────────────────────
-- Her işlemi bilinen girdilerle test eder, çıkışı beklenen değerle assert ile
-- karşılaştırır. Hata varsa ModelSim transcript'inde "Failure/Error" basar.
-- Sonunda "TUM ALU TESTLERI GECTI" yazarsa her şey doğru demektir.
--
-- Testbench'in girişi yok, çıkışı yok (entity boş) — sadece DUT'u sürer.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_alu is
end tb_alu;

architecture sim of tb_alu is

    -- DUT (Device Under Test = test edilen birim) ile bağlanacak sinyaller
    signal a        : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal b        : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal alu_ctrl : STD_LOGIC_VECTOR(3 downto 0)  := (others => '0');
    signal result   : STD_LOGIC_VECTOR(31 downto 0);
    signal zero     : STD_LOGIC;

    -- İşlem kodları (alu.vhd ile aynı)
    constant OP_AND : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    constant OP_OR  : STD_LOGIC_VECTOR(3 downto 0) := "0001";
    constant OP_ADD : STD_LOGIC_VECTOR(3 downto 0) := "0010";
    constant OP_XOR : STD_LOGIC_VECTOR(3 downto 0) := "0011";
    constant OP_SUB : STD_LOGIC_VECTOR(3 downto 0) := "0110";
    constant OP_SLT : STD_LOGIC_VECTOR(3 downto 0) := "0111";
    constant OP_MUL : STD_LOGIC_VECTOR(3 downto 0) := "1000";

    -- Yardımcı: tek bir testi yapan procedure.
    -- Girdileri uygular, kısa bekler, sonucu beklenenle karşılaştırır.
    procedure check(
        signal   sa, sb     : out STD_LOGIC_VECTOR(31 downto 0);
        signal   sctrl      : out STD_LOGIC_VECTOR(3 downto 0);
        signal   sres       : in  STD_LOGIC_VECTOR(31 downto 0);
        constant in_a, in_b : in  integer;
        constant ctrl       : in  STD_LOGIC_VECTOR(3 downto 0);
        constant expected   : in  integer;
        constant test_name  : in  string
    ) is
    begin
        sa    <= std_logic_vector(to_signed(in_a, 32));
        sb    <= std_logic_vector(to_signed(in_b, 32));
        sctrl <= ctrl;
        wait for 10 ns;  -- kombinasyonel devrenin oturması için
        assert sres = std_logic_vector(to_signed(expected, 32))
            report "HATA [" & test_name & "]: beklenen=" & integer'image(expected) &
                   " bulunan=" & integer'image(to_integer(signed(sres)))
            severity error;
    end procedure;

begin

    -- ── DUT örneği ──────────────────────────────────────────────────────────
    DUT: entity work.alu
        port map (
            a        => a,
            b        => b,
            alu_ctrl => alu_ctrl,
            result   => result,
            zero     => zero
        );

    -- ── Test senaryoları ──────────────────────────────────────────────────
    stimulus: process
    begin
        report "=== ALU TESTLERI BASLIYOR ===" severity note;

        -- ADD
        check(a, b, alu_ctrl, result,  5,  7, OP_ADD, 12,  "ADD 5+7");
        check(a, b, alu_ctrl, result, -3,  10, OP_ADD, 7,  "ADD -3+10");

        -- SUB
        check(a, b, alu_ctrl, result, 20,  8, OP_SUB, 12,  "SUB 20-8");
        check(a, b, alu_ctrl, result,  5,  9, OP_SUB, -4,  "SUB 5-9 (negatif)");

        -- AND / OR / XOR
        check(a, b, alu_ctrl, result, 12, 10, OP_AND, 8,   "AND 12&10");
        check(a, b, alu_ctrl, result, 12, 10, OP_OR,  14,  "OR 12|10");
        check(a, b, alu_ctrl, result, 12, 10, OP_XOR, 6,   "XOR 12^10");

        -- SLT
        check(a, b, alu_ctrl, result,  5,  7, OP_SLT, 1,   "SLT 5<7 -> 1");
        check(a, b, alu_ctrl, result,  7,  5, OP_SLT, 0,   "SLT 7<5 -> 0");
        check(a, b, alu_ctrl, result, -2,  3, OP_SLT, 1,   "SLT -2<3 -> 1");

        -- MUL
        check(a, b, alu_ctrl, result,  6,  7, OP_MUL, 42,  "MUL 6*7");
        check(a, b, alu_ctrl, result, -4,  5, OP_MUL, -20, "MUL -4*5");

        -- ── zero bayragi testleri ────────────────────────────────────────
        -- 5-5=0 olmali, zero='1' beklenir
        a <= std_logic_vector(to_signed(5, 32));
        b <= std_logic_vector(to_signed(5, 32));
        alu_ctrl <= OP_SUB;
        wait for 10 ns;
        assert zero = '1'
            report "HATA [zero]: 5-5=0 icin zero='1' beklendi" severity error;

        -- 5-3=2 olmali, zero='0' beklenir
        b <= std_logic_vector(to_signed(3, 32));
        wait for 10 ns;
        assert zero = '0'
            report "HATA [zero]: 5-3=2 icin zero='0' beklendi" severity error;

        report "=== TUM ALU TESTLERI GECTI ===" severity note;
        wait;  -- simulasyonu burada durdur (sonsuz bekleme)
    end process;

end sim;
