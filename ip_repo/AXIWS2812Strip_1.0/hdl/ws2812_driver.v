`default_nettype none
`timescale 1 ns / 1 ps

module ws2812_driver(
    input wire clk,
    input wire reset,
    input wire write,
    input wire [31:0]addr,
    input wire [23:0]value,
    input wire display,
    
    output wire busy,
    output reg led_out
);

    parameter MASTER_CLK            = 0.1; // GHz
    localparam MASTER_PERIOD        = 1 / MASTER_CLK; // ns
    
    parameter T0H                   = 350; // ns
    parameter T1H                   = 700; // ns
    parameter T0L                   = 800; // ns
    parameter T1L                   = 600; // ns
    
    parameter RST                   = 100000; // ns
    
    localparam integer T0H_C                = T0H / MASTER_PERIOD;
    localparam integer T1H_C                = T1H / MASTER_PERIOD;
    localparam integer T0L_C                = T0L / MASTER_PERIOD;
    localparam integer T1L_C                = T1L / MASTER_PERIOD;
    localparam integer RST_C                = RST / MASTER_PERIOD;
    
    parameter NB_LEDS               = 150;
    
    // Handling busy flag
    reg busy_r = 0;
    reg reset_r = 0;
    reg [7:0]r_cnt = 0;
    assign busy = reset | display | reset_r | busy_r;
    
    reg [7:0]led_index = 0;
    reg [4:0]bit_index = 0;
    reg [23:0]led_val = 0;
    reg [23:0]leds[0:NB_LEDS-1];
    
    // Write data
    always @(posedge clk)
    begin
        r_cnt <= 0;
        if(reset) begin
            reset_r <= 1;
        end else if(reset_r) begin
            r_cnt <= r_cnt + 1;
            leds[r_cnt] <= 0;
            if(r_cnt == NB_LEDS - 1) reset_r <= 0;
        end else if(write) leds[addr] <= value;
    end
    
    // Display data
    
    reg [15:0]t_cnt = 0;
    
    localparam IDLE                 = 0;
    localparam TSYM                 = 1;
    localparam RESET                = 2;
    
    reg [1:0]state = IDLE;
    
    always @(posedge clk)
    begin
        
        t_cnt <= t_cnt + 1;
        led_val <= leds[led_index];
        
        case(state)
            IDLE: begin
                t_cnt <= 0;
                led_index <= 0;
                if(display) begin
                    state <= TSYM;
                    busy_r <= 1;
                end
            end
            
            TSYM: begin
                if(led_val[bit_index]) begin
                    if(t_cnt == 0)
                        led_out <= 1;
                    else if(t_cnt == T1H_C - 1)
                        led_out <= 0;
                    else if(t_cnt == T1H_C + T1L_C - 1) begin
                        t_cnt <= 0;
                        bit_index <= bit_index + 1;
                        if(bit_index == 23) begin
                            bit_index <= 0;
                            led_index <= led_index + 1;
                            if(led_index == NB_LEDS - 1) begin
                                state <= RESET;
                            end
                        end
                    end
                end else begin
                    if(t_cnt == 0)
                        led_out <= 1;
                    else if(t_cnt == T0H_C - 1)
                        led_out <= 0;
                    else if(t_cnt == T0H_C + T0L_C - 1) begin
                        t_cnt <= 0;
                        bit_index <= bit_index + 1;
                        if(bit_index == 23) begin
                            bit_index <= 0;
                            led_index <= led_index + 1;
                            if(led_index == NB_LEDS - 1) begin
                                state <= RESET;
                            end
                        end
                    end
                end
            end
            
            RESET: begin
                if(t_cnt == RST_C) begin
                    state <= IDLE;
                    busy_r <= 0;
                end
            end
        endcase
    end

endmodule