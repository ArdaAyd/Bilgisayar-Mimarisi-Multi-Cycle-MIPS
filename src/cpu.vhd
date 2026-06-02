-- ═══════════════════════════════════════════════════════════════════════════
-- CPU — üst seviye: datapath + control_unit + alu_control'ü birbirine bağlar
-- ───────────────────────────────────────────────────────────────────────────
-- Bağlantı şeması:
--   control_unit  → kontrol sinyalleri (mux/enable) + alu_op  → datapath
--   datapath      → opcode, funct, zero, neg                  → control/alu_control
--   alu_control   → alu_op + opcode + funct → alu_ctrl        → datapath
--
-- INIT_FILE: belleğe yüklenecek programın hex dosyası.
-- dbg_reg/dbg_data: testbench'in register içeriğini gözlemlemesi için.
-- ═══════════════════════════════════════════════════════════════════════════

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity cpu is
    generic (
        INIT_FILE : string := ""
    );
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;

        -- ── Gözlem için ──
        dbg_reg    : in  STD_LOGIC_VECTOR(4 downto 0)  := (others => '0');
        dbg_data   : out STD_LOGIC_VECTOR(31 downto 0);
        pc_debug   : out STD_LOGIC_VECTOR(31 downto 0);
        instr_debug: out STD_LOGIC_VECTOR(31 downto 0)
    );
end cpu;

architecture Structural of cpu is

    -- control_unit → datapath sinyalleri
    signal pc_write   : STD_LOGIC;
    signal ir_write   : STD_LOGIC;
    signal reg_write  : STD_LOGIC;
    signal mem_read   : STD_LOGIC;
    signal mem_write  : STD_LOGIC;
    signal ior_d      : STD_LOGIC;
    signal mem_to_reg : STD_LOGIC;
    signal reg_dst    : STD_LOGIC;
    signal alu_src_a  : STD_LOGIC_VECTOR(1 downto 0);
    signal alu_src_b  : STD_LOGIC_VECTOR(2 downto 0);
    signal pc_source  : STD_LOGIC_VECTOR(1 downto 0);
    signal alu_op     : STD_LOGIC_VECTOR(1 downto 0);

    -- datapath → control/alu_control sinyalleri
    signal opcode     : STD_LOGIC_VECTOR(5 downto 0);
    signal funct      : STD_LOGIC_VECTOR(5 downto 0);
    signal zero       : STD_LOGIC;
    signal neg        : STD_LOGIC;

    -- alu_control → datapath
    signal alu_ctrl   : STD_LOGIC_VECTOR(3 downto 0);

begin

    -- ══ Kontrol birimi (FSM) ═════════════════════════════════════════════════
    CTRL: entity work.control_unit
        port map (
            clk        => clk,
            reset      => reset,
            opcode     => opcode,
            zero       => zero,
            neg        => neg,
            pc_write   => pc_write,
            ir_write   => ir_write,
            reg_write  => reg_write,
            mem_read   => mem_read,
            mem_write  => mem_write,
            ior_d      => ior_d,
            mem_to_reg => mem_to_reg,
            reg_dst    => reg_dst,
            alu_src_a  => alu_src_a,
            alu_src_b  => alu_src_b,
            pc_source  => pc_source,
            alu_op     => alu_op
        );

    -- ══ ALU kontrol (alu_op + opcode + funct → alu_ctrl) ═════════════════════
    ALUCTRL: entity work.alu_control
        port map (
            alu_op   => alu_op,
            opcode   => opcode,
            funct    => funct,
            alu_ctrl => alu_ctrl
        );

    -- ══ Veri yolu ════════════════════════════════════════════════════════════
    DP: entity work.datapath
        generic map ( INIT_FILE => INIT_FILE )
        port map (
            clk        => clk,
            reset      => reset,
            pc_write   => pc_write,
            ir_write   => ir_write,
            reg_write  => reg_write,
            mem_read   => mem_read,
            mem_write  => mem_write,
            ior_d      => ior_d,
            mem_to_reg => mem_to_reg,
            reg_dst    => reg_dst,
            alu_src_a  => alu_src_a,
            alu_src_b  => alu_src_b,
            pc_source  => pc_source,
            alu_ctrl   => alu_ctrl,
            opcode     => opcode,
            funct      => funct,
            zero       => zero,
            neg        => neg,
            dbg_reg    => dbg_reg,
            dbg_data   => dbg_data,
            pc_debug   => pc_debug,
            instr_debug=> instr_debug
        );

end Structural;
