`timescale 1ns / 1ps

module playerNumDisp(pIn, seg);
    input [1:0] pIn;
    output reg [6:0] seg;

    always @(pIn)
    case (pIn)
        2'b00 : seg = 7'b1000000; // 0
        2'b01 : seg = 7'b1111001; // 1
        2'b10 : seg = 7'b0100100; // 2
        2'b11 : seg = 7'b0110000; // 3
    endcase
endmodule

module resultDisp(cIn, seg);
    input [1:0] cIn;
    output reg [6:0] seg;

    always @(cIn)
    case (cIn)
        2'b00 : seg = 7'b0001000; // A
        2'b01 : seg = 7'b0101111; // R
        2'b10 : seg = 7'b0000110; // P
        2'b11 : seg = 7'b0010101; // W
    endcase
endmodule

module avg_and_multiply (
    input  [1:0] num1, num2, num3, num4,
    output [4:0] avg_scaled
);
    wire [3:0] sum = num1 + num2 + num3 + num4;
    wire [6:0] temp;
    assign temp = sum * 8;
    assign avg_scaled = temp / 40;
endmodule

module bcd_to_seg (
    input [3:0] bcd,
    output reg [6:0] seg
);
    always @(bcd) begin
        case (bcd)
            4'd0 : seg = 7'b1000000;
            4'd1 : seg = 7'b1111001;
            4'd2 : seg = 7'b0100100;
            4'd3 : seg = 7'b0110000;
            4'd4 : seg = 7'b0011001;
            4'd5 : seg = 7'b0010010;
            4'd6 : seg = 7'b0000010;
            4'd7 : seg = 7'b1111000;
            4'd8 : seg = 7'b0000000;
            4'd9 : seg = 7'b0010000;
            default : seg = 7'b1111111;
        endcase
    end
endmodule

module disp_selector(
    input clk, clr, calculate_btn,
    input [1:0] num1, num2, num3, num4,
    output reg [6:0] seg,
    output reg [3:0] an
);
    wire [6:0] seg1, seg2, seg3, seg4;
    reg [12:0] segclk;

    // State parameters
    localparam LEFT = 3'b000,
               MIDLEFT = 3'b001,
               MIDRIGHT = 3'b010,
               RIGHT = 3'b011,
               TENS = 3'b100,
               ONES = 3'b101,
               P_DISPLAY = 3'b110,
               NUMBER_DISPLAY = 3'b111;

    reg [2:0] state = LEFT;
    reg [2:0] winner;
    reg show_winner;

    // Average calculation
    wire [4:0] multiplied_scaled;
    avg_and_multiply avg_mult (
        .num1(num1), .num2(num2), .num3(num3), .num4(num4),
        .avg_scaled(multiplied_scaled)
    );

    // BCD conversion
    reg [3:0] tens_bcd, ones_bcd;
    always @* begin
        tens_bcd = multiplied_scaled / 10;
        ones_bcd = multiplied_scaled % 10;
    end

    // BCD to segment
    wire [6:0] tens_seg, ones_seg;
    bcd_to_seg bcd_tens(tens_bcd, tens_seg);
    bcd_to_seg bcd_ones(ones_bcd, ones_seg);

    // Player displays
    playerNumDisp disp1(num1, seg1);
    playerNumDisp disp2(num2, seg2);
    playerNumDisp disp3(num3, seg3);
    playerNumDisp disp4(num4, seg4);
    
    always @* begin
        winner = 3'b000;
        if(multiplied_scaled[1:0] == num1) winner = 3'b001;
        else if(multiplied_scaled[1:0] == num2) winner = 3'b010;
        else if(multiplied_scaled[1:0] == num3) winner = 3'b011;
        else if(multiplied_scaled[1:0] == num4) winner = 3'b100;
    end

    // Clock divider
    always @(posedge clk)
        segclk <= segclk + 1'b1;

    // Main state machine
    always @(posedge segclk[12] or posedge clr) begin
        if (clr) begin
            seg <= 7'b0000000;
            an <= 4'b0000;
            state <= LEFT;
            show_winner <= 0;
        end else begin
            if (calculate_btn && winner != 3'b000) begin
                show_winner <= 1;
            end

            if (show_winner) begin
                case(state)
                    P_DISPLAY: begin
                        seg <= 7'b0001100; // P
                        an <= 4'b0111;
                        state <= NUMBER_DISPLAY;
                    end
                    NUMBER_DISPLAY: begin
                        case(winner)
                            3'b100: seg <= 7'b1111001; // 1
                            3'b001: seg <= 7'b0100100; // 2
                            3'b010: seg <= 7'b0110000; // 3
                            3'b011: seg <= 7'b0011001; // 4
                            default: seg <= 7'b1111111;
                        endcase
                        an <= 4'b1011;
                        state <= P_DISPLAY;
                    end
                    default: state <= P_DISPLAY;
                endcase
            end
            else if (calculate_btn) begin
                case(state)
                    TENS: begin
                        seg <= tens_seg;
                        an <= 4'b0111;
                        state <= ONES;
                    end
                    ONES: begin
                        seg <= ones_seg;
                        an <= 4'b1011;
                        state <= TENS;
                    end
                    default: begin
                        state <= TENS;
                        seg <= tens_seg;
                        an <= 4'b0111;
                    end
                endcase
            end
            else begin
                case(state)
                    LEFT: begin
                        seg <= seg1;
                        an <= 4'b0111;
                        state <= MIDLEFT;
                    end
                    MIDLEFT: begin
                        seg <= seg2;
                        an <= 4'b1011;
                        state <= MIDRIGHT;
                    end
                    MIDRIGHT: begin
                        seg <= seg3;
                        an <= 4'b1101;
                        state <= RIGHT;
                    end
                    RIGHT: begin
                        seg <= seg4;
                        an <= 4'b1110;
                        state <= LEFT;
                    end
                endcase
            end
        end
    end
endmodule