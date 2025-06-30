`timescale 1ns / 1ps

// Negative Edge 동작 D Flip-Flop
module D_flip_flop_n(
    input d, clk,
    input enable, reset_p,
    output reg q
    );
    
    // clk negedge = Negative(= Falling) Edge
    // reset posedge = Positive(= Rising) Edge
    // Sensitivity @( ) 여러개 있으면 우선순위를 정해줘야함
    always @(negedge clk or posedge reset_p) begin       // reset 우선
//    always @(negedge clk)begin                          // Clock 우선
        // begin end = { }, 여러 구문 실행
        if(reset_p) begin
            q = 1'b0;
        end
        else if(enable) begin
            q = d;
        end
    end
endmodule

// Positive Edge 동작 D Flip-Flop
module D_flip_flop_p(
    input d, clk,
    input enable, reset_p,
    output reg q
    );
    
    // clk posedge, reset posedge, reset은 보통 posedge 설정
    always @(posedge clk or posedge reset_p) begin       // reset 우선
        if(reset_p) begin
            q = 1'b0;
        end
        else if(enable) begin
            q = d;
        end
    end
endmodule

module T_flip_flop_n(
    input clk, reset_p,
    input enable,
    input t,
    output reg q
    );

    // ,와 or 같은 역할
    // 조합회로는 edge 미사용, Flip-Flop은 edge 사용
    // 문법 익숙해질때까지는 begin end 사용
    // clk negedge, reset posedge
    always @(negedge clk, posedge reset_p) begin
        if(reset_p) begin
            q = 0;
        end
        else begin
            if(enable) begin
                if(t) q = ~q;
                else q = q;         // 생략 가능
            end
        end
    end
endmodule

module T_flip_flop_p(
    input clk, reset_p,
    input enable,
    input t,
    output reg q
    );

    // clk posedge, reset posedge
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            q = 0;
        end
        else begin
            if(enable) begin
                if(t) q = ~q;
                else q = q;         // 생략 가능
            end
        end
    end
endmodule

// Falling Edge 동작 T Flip-Flop으로 Counter를 만들면 Up Counter
// 비동기식 Up Counter, 다른 Clock 사용
module up_counter_asyc(
    input clk, reset_p,
    output [3:0] count 
    );
    
    // .은 T_flip_flop 변수, ( )는 현재 module 변수
    // Module Instance 선언
    T_flip_flop_n cnt0(.clk(clk), .reset_p(reset_p), .enable(1'b1), .t(1'b1), .q(count[0]));
    T_flip_flop_n cnt1(.clk(count[0]), .reset_p(reset_p), .enable(1'b1), .t(1'b1), .q(count[1]));
    T_flip_flop_n cnt2(.clk(count[1]), .reset_p(reset_p), .enable(1'b1), .t(1'b1), .q(count[2]));
    T_flip_flop_n cnt3(.clk(count[2]), .reset_p(reset_p), .enable(1'b1), .t(1'b1), .q(count[3]));
endmodule

// Rising Edge 동작 T Flip-Flop으로 Counter를 만들면 Down Counter
// 비동기식 Down Counter
module down_counter_asyc(
    input clk, reset_p,
    output [3:0] count 
    );
    
    T_flip_flop_p cnt0(.clk(clk), .reset_p(reset_p), .enable(1), .t(1), .q(count[0]));
    T_flip_flop_p cnt1(.clk(count[0]), .reset_p(reset_p), .enable(1), .t(1), .q(count[1]));
    T_flip_flop_p cnt2(.clk(count[1]), .reset_p(reset_p), .enable(1), .t(1), .q(count[2]));
    T_flip_flop_p cnt3(.clk(count[2]), .reset_p(reset_p), .enable(1), .t(1), .q(count[3]));
endmodule

// 동기식 Up Counter, Rising Edge
module up_counter_p(
    input clk, reset_p,
    output reg [3:0] count
    );
    
    // T Flip Flop 사용할 때는 Falling, Rising Edge 영향 받지만 동기식은 크게 영향 없음
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            count = 0;
        end
        else begin
            count = count + 1;
        end
    end
endmodule

// 동기식 Up Counter, Falling Edge
module up_counter_n(
    input clk, reset_p,
    output reg [3:0] count
    );
    
    always @(negedge clk, posedge reset_p) begin
        if(reset_p) begin
            count = 0;
        end
        else begin
            count = count + 1;
        end
    end
endmodule

// 동기식 Down Counter, Rising Edge
module down_counter_p(
    input clk, reset_p,
    output reg [3:0] count
    );
    
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            count = 0;
        end
        else begin
            count = count - 1;
        end
    end
endmodule

// 동기식 Down Counter, Falling Edge
module down_counter_n(
    input clk, reset_p,
    output reg [3:0] count
    );
    
    always @(negedge clk, posedge reset_p) begin
        if(reset_p) begin
            count = 0;
        end
        else begin
            count = count - 1;
        end
    end
endmodule
