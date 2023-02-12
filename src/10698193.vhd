library ieee;
use ieee.std_logic_1164.all;

entity FSM is
    port(
        i : in std_logic;
        clk : in std_logic;
        rst : in std_logic;
        stop_fsm : in std_logic;
        o : out std_logic_vector(1 downto 0)
    );
end FSM;

architecture behavioral of FSM is
    type state_type is (s0, s1, s2, s3);
    signal next_state, current_state : state_type;
    signal temp_o : std_logic_vector(1 downto 0);

begin 
    delta_lambda: process(current_state, i)
    begin
        case current_state is
            when s0 =>
                if i = '0' then
                    next_state <= s0;
                    temp_o <= "00";
                else
                    next_state <= s2;
                    temp_o <= "11";
                end if;
            when s1 =>
                if i = '0' then
                    next_state <= s0;
                    temp_o <= "11";
                else
                    next_state <= s2;
                    temp_o <= "00";
                end if;
            when s2 =>
                if i = '0' then
                    next_state <= s1;
                    temp_o <= "01";
                else
                    next_state <= s3;
                    temp_o <= "10";
                end if;
            when s3 =>
                if i = '0' then
                    next_state <= s1;
                    temp_o <= "10";
                else
                    next_state <= s3;
                    temp_o <= "01";
                end if;
        end case;
    end process;
       
       
    state : process(clk, rst)
    begin
        if rst = '1' then
            current_state <= s0;
        else
            if rising_edge(clk) then
                if stop_fsm = '0' then
                    current_state <= next_state;
                end if;
            end if;
        end if;
    end process;
    
    output : process(clk, rst)
    begin
        if rst = '1' then
            o <= "00";
        else
            if rising_edge(clk) then
                if stop_fsm = '0' then
                    o <= temp_o;
                end if;
            end if;
        end if;
    end process;
    
end behavioral;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_data : in std_logic_vector(7 downto 0);
        o_address : out std_logic_vector(15 downto 0);
        o_done : out std_logic;
        o_en : out std_logic;
        o_we : out std_logic;
        o_data : out std_logic_vector(7 downto 0)
    );
end project_reti_logiche;

architecture mixed of project_reti_logiche is

signal numberOfWords        : std_logic_vector(7 downto 0) := (others => '0');
signal wordCount            : unsigned (15 downto 0) := (others => '0');
signal bitCount             : unsigned (2 downto 0) := (others => '1');
signal systemState          : unsigned (3 downto 0) := (others => '0');


signal input                : std_logic_vector(7 downto 0) := (others => '0');
signal inputFSM             : std_logic := '0';
signal outputFSM            : std_logic_vector(1 downto 0) := (others => '0');
signal resetFSM             : std_logic := '1';
signal stop                 : std_logic := '1';

component FSM is
    port(
        i           : in std_logic;
        clk         : in std_logic;
        rst         : in std_logic;
        stop_fsm    : in std_logic;
        o           : out std_logic_vector(1 downto 0)
    );
end component;

begin
    process(i_clk, i_rst) -- la sincronizzazione avviene interamente sul clock, il reset è asincrono
    begin
        if i_rst = '1' then -- reset del circuito
            o_address <= (others => '0');
            o_done <= '0';
            o_en <= '1';
            o_we <= '0';
            resetFSM <= '1';
            inputFSM <= '0';
            stop <= '1';
            systemState <= to_unsigned(0, 4);
            wordCount <= to_unsigned(0, 16);
        else    
            if rising_edge(i_clk) then
                if systemState = to_unsigned(0, 4) then -- attesa di sicurezza per la preparazione dei dati in input (se il reset scende dopo un ciclco di clock)
                    if i_start = '1' then
                        systemState <= to_unsigned(1, 4);
                    end if;
                elsif systemState = to_unsigned(1, 4) then -- lettura del numero di parole da leggere nella memoria e richiesta della prima parola
                    numberOfWords <= i_data;
                    o_address <= (15 downto 1 => '0', 0 => '1');
                    systemState <= to_unsigned(2, 4);
                elsif systemState = to_unsigned(2, 4) then -- attesa caricamento della prima parola
                    bitCount <= (others => '1');
                    resetFSM <= '0';
                    systemState <= to_unsigned(3, 4);
                elsif systemState = to_unsigned(3, 4) then
                    if std_logic_vector(wordCount) < numberOfWords then
                        input <= i_data;
                        inputFSM <= i_data(7);
                        o_en <= '0';
                        stop <= '0';
                        systemState <= to_unsigned(4, 4);
                    else
                        o_en <= '1';
                        o_we <= '0';
                        resetFSM <= '1';
                        inputFSM <= '0';
                        stop <= '1';
                        o_address <= (others => '0');
                        wordCount <= to_unsigned(0, 16);
                        o_done <= '1';
                        systemState <= to_unsigned(8, 4);
                    end if;
                elsif systemState = to_unsigned(4, 4) then
                    if bitCount > to_unsigned(0, 3) then
                        inputFSM <= input(to_integer(bitCount) - 1);
                        bitCount <= bitCount - 1;
                        if bitCount > to_unsigned(2, 3) then
                            if bitCount < to_unsigned(7, 3) then
                                o_data(2 * (to_integer(bitCount) + 1) - 7 downto 2 * (to_integer(bitCount) + 1) - 7 - 1) <= outputFSM;
                                if bitCount = to_unsigned(3, 3) then
                                    o_address <= std_logic_vector(2 * wordCount(7 downto 0) + 1000);
                                    o_en <= '1';
                                    o_we <= '1';
                                end if;
                            end if;
                        else
                            if bitCount = to_unsigned(2, 3) then
                                o_en <= '0';
                                o_we <= '0';
                            end if;
                            o_data(2 * (to_integer(bitCount) + 1) + 1 downto 2 * (to_integer(bitCount) + 1)) <= outputFSM;
                        end if;
                    else
                        o_data(3 downto 2) <= outputFSM;
                        
                        wordCount <= wordCount + 1;
                        
                        systemState <= to_unsigned(5, 4);
                        
                        -- è giusto mettere lo stop qua o dovrei metterlo un ciclo di clock dopo?
                        stop <= '1';
                    end if;
                elsif systemState = to_unsigned(5, 4) then -- stampa della seconda parola generata dagli 8 bit letti dalla memoria

                    o_data(1 downto 0) <= outputFSM;
                    o_address <= std_logic_vector(2 * wordCount(7 downto 0) - 1 + 1000);
                    o_en <= '1';
                    o_we <= '1';
                    systemState <= to_unsigned(6, 4);
                elsif systemState = to_unsigned(6, 4) then -- attesa della stampa
                    systemState <= to_unsigned(7, 4);
                elsif systemState = to_unsigned(7, 4) then -- attesa della stampa e preparazione della memoria alla lettura della nuova parola in input
                    o_address <= std_logic_vector(wordCount + 1);
                    o_we <= '0';
                    systemState <= to_unsigned(2, 4);
                else -- done a 0 per segnalare la fine dell'esecuzione
                    if i_start = '0' then
                        o_done <= '0';
                        systemState <= to_unsigned(0, 4);
                    else
                        systemState <= to_unsigned(8, 4);
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    macchina : FSM
        port map(i => inputFSM, clk => i_clk, rst => resetFSM, stop_fsm => stop, o => outputFSM);   
end mixed;