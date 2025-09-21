`timescale 1ns / 1ps

// FND 4-Digit Output
module fnd_cntr (
    input clk, reset_p,
    input [15:0] fnd_value,
    input hex_bcd,
    output [6:0] seg_7,
    output dp,
    output [3:0] com
    );

    wire [15:0] bcd_value;
    // Convert Input Value to BCD Format
    bin_to_dec bcd (.bin(fnd_value[11:0]), .bcd(bcd_value));

    reg [16:0] clk_div;             // Clock Divide

    always @(posedge clk) begin
        clk_div = clk_div + 1;
    end

    // Change FND Output Every 2^16 * 10ns 
    anode_selector ring_com (.scan_count(clk_div[16:15]), .an_out(com));

    reg [3:0] digit_value;          // Single-Digit Output Value

    wire [15:0] out_value;          // Hex ↔ BCD Change Format
    assign out_value = hex_bcd ? fnd_value : bcd_value;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin          // Single-Digit Value Reset
            digit_value = 0;
        end
        else begin
            case (com)              // Select Digit Value
                4'b1110 : digit_value = out_value[3:0];
                4'b1101 : digit_value = out_value[7:4];
                4'b1011 : digit_value = out_value[11:8];
                4'b0111 : digit_value = out_value[15:12];
                default : digit_value = 0;
            endcase
        end
    end

    seg_decoder_a dec (.scan_count(clk_div[16:15]), .digit_in(digit_value),
                    .seg_out(seg_7), .dp_out(dp));
endmodule

// Button Debounce 
module button_debounce (
    input clk,
    input noise_btn,            // Raw Input Button
    output reg clean_btn        // Modify Button
    );

    reg [19:0] cnt = 1;
    reg btn_sync_0, btn_sync_1; // 2 Step Debounce
    reg btn_state;              // Button Before State

    always @(posedge clk) begin
        btn_sync_0 <= noise_btn;
        btn_sync_1 <= btn_sync_0;
    end

    always @(posedge clk) begin
        if (btn_sync_1 == btn_state) begin
            cnt <= 1;           // Input == Before State, Stable State → Counter Reset
        end
        else begin
            cnt <= cnt + 1;     // Input != Before State, Count Increase
            if (cnt >= 1_000_000) begin  // Maintain a Specific Time for Debounce, 10ns * 1,000,000 = 10ms
                btn_state <= btn_sync_1;
                clean_btn <= btn_sync_1;
                cnt <= 1;
            end
        end
    end
endmodule

// Button Debounce + Edge Detect, Switch also Available
module btn_cntr (
    input clk, reset_p,
    input btn,
    output btn_pedge, btn_ndege
    );

    wire debounced_btn;
    button_debounce btn_debounce (.clk(clk), .noise_btn(btn), .clean_btn(debounced_btn));
    edge_detector_pos btn_ed (.clk(clk), .reset_p(reset_p),
        .cp(debounced_btn), .p_edge(btn_pedge), .n_edge(btn_ndege));
endmodule

// Input Address or Data, 100㎑ I2C Communication When Start-bit High
module i2c_master (
    input clk, reset_p,
    input [6:0] addr,                           // Slave Address
    input [7:0] data,                           // Transmission Data
    input rd_wr, comm_start,                    // Read & Write Select-bit, Communication Start-bit
    output reg scl, sda,                        // Serial Clock , Serial Data
                                                // Originally SDA Input + Output, but Here only Output
    output [15:0] led                           // for Debugging
    );

    // Change State Using Shift
    localparam I2C_IDLE     = 7'b000_0001;      // Standby State
    localparam COMM_START   = 7'b000_0010;      // Communication Start
    localparam SEND_ADDR    = 7'b000_0100;      // Address Transmission
    localparam READ_ACK     = 7'b000_1000;      // Read ACK-bit, Assume Read
    localparam SEND_DATA    = 7'b001_0000;      // Data Transmission
    localparam SCL_STOP     = 7'b010_0000;      // Stop Generate Serial Clock
    localparam COMM_STOP    = 7'b100_0000;      // Communication Stop

    // Clock Divide 100, 10ns x 100 = 1us
    wire clk_usec_nedge, clk_usec_pedge; // Divide Clock 1us
    clock_div_100 us_clk (.clk(clk), .reset_p(reset_p),
        .nedge_div_100(clk_usec_nedge), .pedge_div_100(clk_usec_pedge));

    // Edge Detection of Command Signal
    wire comm_start_pedge, comm_start_nedge;
    edge_detector_pos comm_start_ed (.clk(clk), .reset_p(reset_p),
        .cp(comm_start), .p_edge(comm_start_pedge), .n_edge(comm_start_nedge));

    // Edge Detection of SCL Signal
    wire scl_pedge, scl_nedge;
    edge_detector_pos scl_ed (.clk(clk), .reset_p(reset_p),
        .cp(scl), .p_edge(scl_pedge), .n_edge(scl_nedge));

    reg [2:0] cnt_usec5;                        // 5us Count
    reg scl_e;                                  // SCL Enable
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            cnt_usec5 = 0;                      // 5us Count Reset
            scl = 1;                            // SCL Reset, Pull-Up
        end
        else if (scl_e) begin                   // when SCL Enable
            if (clk_usec_nedge) begin           // when us Negative Edge
                if (cnt_usec5 >= 4) begin       // Every 5us 
                    cnt_usec5 = 0;              // 5us Count Reset
                    scl = ~scl;                 // Generate Serial Clock
                end
                else begin
                    cnt_usec5 = cnt_usec5 + 1;  // Count During Enable
                end
            end
        end
        else if (!scl_e) begin                  // SCL Disable
            cnt_usec5 = 0;                      // 5us Count Reset
            scl = 1;                            // SCL Reset, Pull-Up
        end
    end

    reg [6:0] state, next_state;                // Current & Next State
    always @(negedge clk, posedge reset_p) begin
        if (reset_p) state = I2C_IDLE;          // Basic Standby
        else state = next_state;                // Change State in Negative Edge
    end

    wire [7:0] addr_rd_wr;
    assign addr_rd_wr = {addr, rd_wr};          // Address + RW Select-bit
    reg [2:0] cnt_bit;                          // Count for Transmit 1-bit at a Time
    reg stop_flag;                              // Check Data Transmission
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            next_state = I2C_IDLE;              // Basic Standby
            scl_e = 0;                          // SCL Disable
            sda = 1;                            // SDA Reset, Pull-Up
            cnt_bit = 7;                        // bit Count Reset, from Upper bit
            stop_flag = 0;                      // Before Data Transmission
        end
        else begin
            case (state)
                I2C_IDLE   : begin              // Standby State
                    scl_e = 0;                  // SCL Disable
                    sda = 1;                    // SDA Reset, Pull-Up
                    if (comm_start_pedge) begin // Communication Start
                        next_state = COMM_START;    // Change State COMM_START
                    end
                end
                COMM_START : begin              // Communication Start
                    sda = 0;                    // SDA Start
                    scl_e = 1;                  // SCL Enable
                    next_state = SEND_ADDR;     // Change State SEND_ADDR
                end
                SEND_ADDR  : begin              // Address Transmission
                    if (scl_nedge) begin        // when SCL Negative Edge
                        sda = addr_rd_wr[cnt_bit];  // Enter Address into SDA
                    end
                    if (scl_pedge) begin        // when SCL Positive Edge
                        if (cnt_bit == 0) begin // Read to LSB
                            cnt_bit = 7;        // bit Count Reset
                            next_state = READ_ACK;  // Change State READ_ACK
                        end
                        else begin
                            cnt_bit = cnt_bit - 1;  // Read from MSB
                        end
                    end
                end
                READ_ACK   : begin              // Read ACK-bit, Assume Read
                    if (scl_nedge) begin        // when SCL Negative Edge
                        sda = 'bz; // Enter Inpedance Value into SDA, Disconnect
                    end
                    else if (scl_pedge) begin   // when SCL Positive Edge
                        if (stop_flag) begin    // Complete Data Transmission
                            stop_flag = 0;      // Data Transmission Flag Clear
                            next_state = SCL_STOP;  // Change State SCL_STOP
                        end
                        else begin              // Before Data Transmission
                            stop_flag = 1;      // Data Transmission Flag Set
                            next_state = SEND_DATA; // Change State SEND_DATA
                        end
                    end
                end
                SEND_DATA  : begin              // Data Transmission
                    if (scl_nedge) begin        // when SCL Negative Edge
                        sda = data[cnt_bit];    // Enter Data into SDA
                    end
                    if (scl_pedge) begin        // when SCL Positive Edge
                        if (cnt_bit == 0) begin // Read to LSB
                            cnt_bit = 7;        // bit Count Reset
                            next_state = READ_ACK;  // Change State READ_ACK
                        end
                        else begin
                            cnt_bit = cnt_bit - 1;  // Read from MSB
                        end
                    end
                end
                SCL_STOP   : begin              // Stop Generate Serial Clock
                    if (scl_nedge) sda = 0;     // SDA Low when SCL Negative Edge
                    if (scl_pedge) next_state = COMM_STOP;  // Change State COMM_STOP when SCL Positive Edge
                end
                COMM_STOP  : begin              // Communication Stop
                    if (cnt_usec5 >= 3) begin   // Wait 4us
                        scl_e = 0;              // SCL Disable
                        sda = 1;                // SDA Stop
                        next_state = I2C_IDLE;  // Change State I2C_IDLE
                    end
                end
                default    : begin
                    scl_e = 0;                  // SCL Disable
                    sda = 1;                    // SDA Reset, Pull-Up
                    next_state = I2C_IDLE;      // Basic Standby
                end
            endcase
        end
    end
endmodule

// PWM Frequency Signal Output According to Duty Ratio
module pwm_Nstep (
    input clk, reset_p,
    input [31:0] duty,                          // PWM Duty Rate, CCR Capture Compare Register
    output reg pwm                              // PWM Duty Applied Pulse
    );

    parameter sys_clk_freq  = 100_000_000;      // System Clock Frequency
    parameter pwm_freq      = 10_000;           // PWM Frequency
    parameter duty_step_N   = 200;              // Duty Step, ARR Auto Reload Register
    parameter temp = sys_clk_freq / pwm_freq / duty_step_N / 2; // Half of Cycle

    integer cnt_sysclk;                         // System Clock Count
    reg pwm_freqXn;                             // PWM Frequency
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            cnt_sysclk = 0;                     // System Clock Count Reset
            pwm_freqXn = 0;                     // PWM Frequency Reset
        end
        else begin
            if (cnt_sysclk >= temp - 1) begin   // when Half of Cycle
                cnt_sysclk = 0;                 // System Clock Count Reset
                pwm_freqXn = ~pwm_freqXn;       // PWM Frequency Generation
            end
            else cnt_sysclk = cnt_sysclk + 1;   // Count System Clock
        end
    end

    // Edge Detection of PWM Frequency
    wire pwm_freqXn_nedge;                      // PWM Frequency Negative Edge
    edge_detector_pos pwm_freqXn_ed (.clk(clk), .reset_p(reset_p),
        .cp(pwm_freqXn), .n_edge(pwm_freqXn_nedge));

    integer cnt_duty;                           // PWM Frequency Count
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            cnt_duty = 0;                       // PWM Frequency Count Reset
            pwm = 0;                            // Pulse Reset
        end
        else if (pwm_freqXn_nedge) begin
            if (cnt_duty >= duty_step_N) cnt_duty = 0;  // Count to End of Duty
            else cnt_duty = cnt_duty + 1;       // Count PWM Frequency

            if (cnt_duty < duty) pwm = 1;       // Pulse High Until Duty
            else pwm = 0;                       // Pulse Low After Duty
        end
    end
endmodule

// GY-65 BMP180 압력/온도 센서 제어 모듈
module gy65_bmp180_cntr (
    input wire clk,           // 시스템 클럭 (예: 100MHz)
    input wire reset_p,       // 리셋 (active high)
    input wire start,         // 측정 시작 신호
    
    // I2C 인터페이스
    inout wire sda,           // I2C 데이터 라인
    output wire scl,          // I2C 클럭 라인
    
    // 출력 데이터 (계산된 값만)
    output reg [31:0] pressure_pa,     // 계산된 압력 (Pa)
    output reg [15:0] temperature_c,   // 계산된 온도 (0.1도 단위)
    output reg [31:0] altitude_cm,     // 계산된 고도 (cm)
    
    // 상태 신호
    output reg data_ready,    // 데이터 준비 완료
    output reg busy,          // 동작 중
    output reg error          // 에러 발생
);

// BMP180 I2C 주소 및 레지스터
localparam BMP180_ADDR = 7'h77;
localparam REG_CAL_AC1 = 8'hAA;
localparam REG_CAL_AC2 = 8'hAC;
localparam REG_CAL_AC3 = 8'hAE;
localparam REG_CAL_AC4 = 8'hB0;
localparam REG_CAL_AC5 = 8'hB2;
localparam REG_CAL_AC6 = 8'hB4;
localparam REG_CAL_B1  = 8'hB6;
localparam REG_CAL_B2  = 8'hB8;
localparam REG_CAL_MB  = 8'hBA;
localparam REG_CAL_MC  = 8'hBC;
localparam REG_CAL_MD  = 8'hBE;
localparam REG_CONTROL = 8'hF4;
localparam REG_DATA    = 8'hF6;

// 측정 명령
localparam CMD_TEMP    = 8'h2E;
localparam CMD_PRESS   = 8'h34; // OSS=0

// 상태 머신
localparam IDLE         = 4'd0;
localparam READ_CAL     = 4'd1;
localparam START_TEMP   = 4'd2;
localparam WAIT_TEMP    = 4'd3;
localparam READ_TEMP    = 4'd4;
localparam START_PRESS  = 4'd5;
localparam WAIT_PRESS   = 4'd6;
localparam READ_PRESS   = 4'd7;
localparam CALCULATE    = 4'd8;
localparam DONE         = 4'd9;
localparam ERROR_STATE  = 4'd10;

reg [3:0] state, next_state;
reg [31:0] counter;
reg [7:0] cal_step;

// 교정 계수들
reg signed [15:0] ac1, ac2, ac3, b1, b2, mb, mc, md;
reg [15:0] ac4, ac5, ac6;

// I2C 제어 신호
reg i2c_start;
reg i2c_stop;
reg i2c_write;
reg i2c_read;
reg [7:0] i2c_data_tx;
wire [7:0] i2c_data_rx;
wire i2c_busy;
wire i2c_ack;

// 내부 변수
reg [15:0] ut, up; // 온도/압력 원시 데이터
reg signed [31:0] x1, x2, x3, b3, b5, b6, p;
reg [31:0] b4, b7;

// I2C 마스터 모듈 인스턴스
i2c_master_io i2c_inst (
    .clk(clk),
    .reset_p(reset_p),
    .start(i2c_start),
    .stop(i2c_stop),
    .write(i2c_write),
    .read(i2c_read),
    .slave_addr(BMP180_ADDR),
    .data_tx(i2c_data_tx),
    .data_rx(i2c_data_rx),
    .busy(i2c_busy),
    .ack(i2c_ack),
    .sda(sda),
    .scl(scl)
);

// 메인 상태 머신
always @(posedge clk or posedge reset_p) begin
    if (reset_p) begin
        state <= IDLE;
        counter <= 0;
        cal_step <= 0;
        data_ready <= 0;
        busy <= 0;
        error <= 0;
    end else begin
        state <= next_state;
        
        // 카운터 관리
        if (state != next_state)
            counter <= 0;
        else
            counter <= counter + 1;
    end
end

// 상태 머신 로직
always @(*) begin
    next_state = state;
    i2c_start = 0;
    i2c_stop = 0;
    i2c_write = 0;
    i2c_read = 0;
    i2c_data_tx = 8'h00;
    
    case (state)
        IDLE: begin
            busy = 0;
            data_ready = 0;
            if (start) begin
                next_state = READ_CAL;
                busy = 1;
                cal_step = 0;
            end
        end
        
        READ_CAL: begin
            // 교정 계수 읽기 (간소화된 버전)
            if (counter == 0) begin
                i2c_start = 1;
                i2c_write = 1;
                i2c_data_tx = REG_CAL_AC1;
            end else if (counter > 100 && !i2c_busy) begin
                if (cal_step < 11) begin
                    cal_step = cal_step + 1;
                    // 실제 구현에서는 각 교정 계수를 순차적으로 읽음
                end else begin
                    next_state = START_TEMP;
                end
            end
        end
        
        START_TEMP: begin
            // 온도 측정 시작
            if (counter == 0) begin
                i2c_start = 1;
                i2c_write = 1;
                i2c_data_tx = REG_CONTROL;
            end else if (counter == 50) begin
                i2c_write = 1;
                i2c_data_tx = CMD_TEMP;
            end else if (counter == 100) begin
                i2c_stop = 1;
                next_state = WAIT_TEMP;
            end
        end
        
        WAIT_TEMP: begin
            // 온도 변환 대기 (4.5ms)
            if (counter > 450000) begin // 100MHz 기준
                next_state = READ_TEMP;
            end
        end
        
        READ_TEMP: begin
            // 온도 데이터 읽기
            if (counter == 0) begin
                i2c_start = 1;
                i2c_write = 1;
                i2c_data_tx = REG_DATA;
            end else if (counter == 50) begin
                i2c_read = 1;
            end else if (counter == 150 && !i2c_busy) begin
                ut[15:8] = i2c_data_rx;
                i2c_read = 1;
            end else if (counter == 200 && !i2c_busy) begin
                ut[7:0] = i2c_data_rx;
                i2c_stop = 1;
                next_state = START_PRESS;
            end
        end
        
        START_PRESS: begin
            // 압력 측정 시작
            if (counter == 0) begin
                i2c_start = 1;
                i2c_write = 1;
                i2c_data_tx = REG_CONTROL;
            end else if (counter == 50) begin
                i2c_write = 1;
                i2c_data_tx = CMD_PRESS;
            end else if (counter == 100) begin
                i2c_stop = 1;
                next_state = WAIT_PRESS;
            end
        end
        
        WAIT_PRESS: begin
            // 압력 변환 대기 (4.5ms, OSS=0)
            if (counter > 450000) begin
                next_state = READ_PRESS;
            end
        end
        
        READ_PRESS: begin
            // 압력 데이터 읽기 (3바이트)
            if (counter == 0) begin
                i2c_start = 1;
                i2c_write = 1;
                i2c_data_tx = REG_DATA;
            end else if (counter == 50) begin
                i2c_read = 1;
            end else if (counter == 150 && !i2c_busy) begin
                up[15:8] = i2c_data_rx;
                i2c_read = 1;
            end else if (counter == 200 && !i2c_busy) begin
                up[7:0] = i2c_data_rx;
                i2c_stop = 1;
                next_state = CALCULATE;
            end
        end
        
        CALCULATE: begin
            // 온도 및 압력 계산 (BMP180 알고리즘)
            if (counter == 0) begin
                // 온도 계산
                x1 = (ut - ac6) * ac5 / 32768;
                x2 = mc * 2048 / (x1 + md);
                b5 = x1 + x2;
                temperature_c = (b5 + 8) / 16;
            end else if (counter == 10) begin
                // 압력 계산
                b6 = b5 - 4000;
                x1 = (b2 * (b6 * b6 / 4096)) / 2048;
                x2 = ac2 * b6 / 2048;
                x3 = x1 + x2;
                b3 = (((ac1 * 4 + x3) + 2) / 4);
                x1 = ac3 * b6 / 8192;
                x2 = (b1 * (b6 * b6 / 4096)) / 65536;
                x3 = ((x1 + x2) + 2) / 4;
                b4 = ac4 * (x3 + 32768) / 32768;
                b7 = (up - b3) * 50000;
                
                if (b7 < 80000000) p = (b7 * 2) / b4;
                else p = (b7 / b4) * 2;
                    
                x1 = (p / 256) * (p / 256);
                x1 = (x1 * 3038) / 65536;
                x2 = (-7357 * p) / 65536;
                pressure_pa = p + (x1 + x2 + 3791) / 16;
                
                // 고도 계산 (해수면 압력 101325 Pa 기준)
                altitude_cm = 4433000 * (1 - ((pressure_pa * 100) / 10132500));
                
                next_state = DONE;
            end
        end
        
        DONE: begin
            data_ready = 1;
            busy = 0;
            next_state = IDLE;
        end
        
        ERROR_STATE: begin
            error = 1;
            busy = 0;
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule

module i2c_master_io (
    input  wire clk,
    input  wire reset_p,

    // Control
    input  wire start,
    input  wire stop,
    input  wire write,
    input  wire read,
    input  wire [6:0] slave_addr,
    input  wire [7:0] data_tx,
    output reg  [7:0] data_rx,

    // Status
    output reg busy,
    output reg ack,       // ACK/NACK 상태 유지

    // I2C lines
    inout  wire sda,
    output wire scl
);

    // -------------------------------
    // SCL Generator (100kHz from 100MHz)
    // -------------------------------
    reg [9:0] clk_div;
    reg [1:0] scl_phase;
    reg scl_tick;
    reg scl_reg;

    assign scl = scl_reg;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            clk_div   <= 0;
            scl_phase <= 0;
            scl_tick  <= 0;
        end else if (busy) begin
            if (clk_div == 499) begin
                clk_div   <= 0;
                scl_phase <= scl_phase + 1;
                scl_tick  <= 1;
            end else begin
                clk_div  <= clk_div + 1;
                scl_tick <= 0;
            end
        end else begin
            clk_div   <= 0;
            scl_phase <= 0;
            scl_tick  <= 0;
        end
    end

    // SCL output
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) scl_reg <= 1;
        else begin
            case (scl_phase)
                2'b00, 2'b01: scl_reg <= 0;
                2'b10, 2'b11: scl_reg <= 1;
            endcase
        end
    end

    // -------------------------------
    // SDA Control
    // -------------------------------
    reg sda_out;
    reg sda_oe;
    assign sda = sda_oe ? sda_out : 1'bz;

    // -------------------------------
    // FSM
    // -------------------------------
    localparam [3:0]
        ST_IDLE   = 0,
        ST_START  = 1,
        ST_ADDR   = 2,
        ST_ACK    = 3,
        ST_TX     = 4,
        ST_TX_ACK = 5,
        ST_RX     = 6,
        ST_RX_ACK = 7,
        ST_STOP   = 8,
        ST_ERROR  = 9;

    reg [3:0] state, next_state;
    reg [7:0] shift_reg;
    reg [2:0] bit_cnt;

    // Sequential FSM
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            state     <= ST_IDLE;
            busy      <= 0;
            ack       <= 0;
            data_rx   <= 0;
            bit_cnt   <= 0;
            shift_reg <= 0;
        end else if (scl_tick) state <= next_state;
    end

    // Combinational FSM
    always @(*) begin
        // defaults
        next_state = state;
        sda_out = 1;
        sda_oe  = 0;
        busy     = (state != ST_IDLE);

        case (state)
            ST_IDLE: begin
                if (start) next_state = ST_START;
            end

            ST_START: begin
                sda_out = 0; sda_oe = 1; // START condition
                if (scl_phase == 2'b10) begin
                    shift_reg = {slave_addr, (read?1'b1:1'b0)};
                    bit_cnt   = 7;
                    next_state = ST_ADDR;
                end
            end

            ST_ADDR: begin
                sda_out = shift_reg[bit_cnt]; sda_oe = 1;
                if (scl_phase == 2'b01 && scl_tick) begin
                    if (bit_cnt==0) next_state=ST_ACK;
                    else bit_cnt = bit_cnt-1;
                end
            end

            ST_ACK: begin
                sda_oe = 0; // Release SDA for ACK
                if (scl_phase == 2'b10 && scl_tick) begin
                    ack = ~sda; // ACK=1, NACK=0
                    if (ack) begin
                        if (write) begin
                            shift_reg = data_tx;
                            bit_cnt   = 7;
                            next_state= ST_TX;
                        end else if (read) begin
                            bit_cnt   = 7;
                            next_state= ST_RX;
                        end
                    end else next_state = ST_ERROR;
                end
            end

            ST_TX: begin
                sda_out = shift_reg[bit_cnt]; sda_oe = 1;
                if (scl_phase==2'b01 && scl_tick) begin
                    if (bit_cnt==0) next_state=ST_TX_ACK;
                    else bit_cnt=bit_cnt-1;
                end
            end

            ST_TX_ACK: begin
                sda_oe = 0; // Release SDA
                if (scl_phase==2'b10 && scl_tick) begin
                    next_state = stop ? ST_STOP : ST_IDLE;
                end
            end

            ST_RX: begin
                sda_oe = 0; // Read mode
                if (scl_phase==2'b10 && scl_tick) begin
                    shift_reg[bit_cnt] = sda;
                    if (bit_cnt==0) begin
                        data_rx = shift_reg;
                        next_state = ST_RX_ACK;
                    end else bit_cnt=bit_cnt-1;
                end
            end

            ST_RX_ACK: begin
                sda_out = 0; sda_oe = 1; // Send ACK
                if (scl_phase==2'b10 && scl_tick) begin
                    next_state = stop ? ST_STOP : ST_IDLE;
                end
            end

            ST_STOP: begin
                sda_out = 0; sda_oe = 1;
                if (scl_phase==2'b10) begin
                    sda_out=1; sda_oe=1; // STOP
                    next_state=ST_IDLE;
                end
            end

            ST_ERROR: begin
                next_state = ST_IDLE;
            end
        endcase
    end
endmodule

