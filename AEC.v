module AEC(clk, rst, ascii_in, ready, valid, result);

// Input signal
input clk;
input rst;
input ready;
input [7:0] ascii_in;

// Output signal
output reg valid;
output reg [6:0] result;


localparam IDLE = 2'd0;
localparam data_in = 2'd1;
localparam infix_evaluation = 2'd2;
localparam Out = 2'd3;

reg [1:0] state, nextstate;
reg [4:0] token;
reg [4:0] data [0:15];
reg [2:0] tmp1, tmp2, current;
reg [4:0] index, count;
reg [1:0] _index;
reg [2:0] left_parenthesis [0:1];
reg [6:0] temp1 [0:5];
reg [4:0] temp2 [0:3];
reg [1:0] top;
reg [1:0] pop_num;
reg y, z;
reg [2:0] x;

always @(posedge clk) begin
    if(rst) state <= data_in;
    else state <= nextstate;
end

always @(*) begin
    case (state)
        IDLE:begin
            nextstate = data_in;
        end
        data_in:begin
            if(ascii_in == 61) nextstate = infix_evaluation;
            else nextstate = data_in;
        end
        infix_evaluation:begin
            if({(tmp2==0)&&(count==index-1)}) nextstate = Out;
            else nextstate = infix_evaluation;
        end 
        default:begin
            nextstate = IDLE;
        end 
    endcase
end

always @(*) begin           //判別top token
    case (temp2[tmp2-1])
        5'd18: top=2'b01;   //top token '*'
        5'd19: top=2'b10;   //top token '+'
        5'd20: top=2'b10;   //top token '-'
        default: top=2'b11; //top token '('
    endcase
end

always @(*) begin
    case (data[count])     //判別current
        5'd18: current=3'b001; //'*'
        5'd19: current=3'b010; //'+'
        5'd20: current=3'b010; //'-' 
        5'd16: current=3'b100; //'('
        5'd17: current=3'b110; //')'
        default: current=3'b000;
    endcase
end

always @(*) begin
    case ({top, current})
        5'b10010: x = 3'd0;  //top:'+','-' current:'+','-'
        5'b01001: x = 3'd0;  //top:'*'     current:'*'
        5'b10001: x = 3'd1;  //top:'+','-' current:'*'
        5'b11010: x = 3'd1;  //top:'('     current:'+','-'
        5'b11001: x = 3'd1;  //top:'('     current:'*'
        5'b10110: x = 3'd2;  //top:'+','-' current:')'
        5'b01110: x = 3'd2;  //top:'*'     current:')'
        5'b10100: x = 3'd3;  //top:'+','-' current:'('
        5'b01100: x = 3'd3;  //top:'*'     current:'('
        5'b11100: x = 3'd3;  //top:'('     current:'('
        5'b01010: x = 3'd4;  //top:'*'     current:'+','-'
        default: x = 3'd5;
    endcase
end

always @(*) begin       //判別是否已經到最後一個character
    case (index-1!=count)
        1'b1: y = 1'b1; 
        default: y = 1'b0;
    endcase
end

always @(*) begin     //判別stack是否為空
    case (tmp2==0)
        1'b1: z = 1'b1; 
        default: z = 1'b0;
    endcase
end

always @(posedge clk) begin
    if(rst)begin
        valid <= 1'b0;
        result <= 7'b0;
        index <= 5'b0;
        count <= 5'b0;
        tmp1 <= 3'b0;
        tmp2 <= 3'b0;
        _index <= 2'b0;
        pop_num <= 2'b0;
    end
    else begin
        case (state)
            IDLE:begin
                valid <= 1'b0;
                result <= 7'b0;
                index <= 5'b0;
                count <= 5'b0;
                tmp1 <= 3'b0;
                tmp2 <= 3'b0;
                _index <= 2'b0;
                pop_num <= 2'b0;
            end
            data_in:begin //read data
                data[index] <= token;
                index <= index + 1;
            end 
            infix_evaluation:begin
                if(data[count]<5'd16)begin
                    temp1[tmp1] <= data[count];
                    tmp1 <= tmp1 + 1;
                    count <= count + 1;
                end
                else begin
                    case ({y,z})
                    2'b11:begin  //讀進第一個運算符
                        temp2[tmp2] <= data[count];
                        tmp2 <= tmp2 + 1;
                        count <= count + 1;
                        if(data[count]==5'd16)begin
                            left_parenthesis[_index] <= tmp2; //record the location of left_parenthesis
                            _index <= _index + 1;
                        end
                    end 
                    2'b10:begin
                        case (x)
                            3'd0:begin
                                case (temp2[tmp2-1])
                                    5'd18:begin
                                        temp1[tmp1-2] <= temp1[tmp1-2] * temp1[tmp1-1];
                                    end 
                                    5'd19:begin
                                        temp1[tmp1-2] <= temp1[tmp1-2] + temp1[tmp1-1];
                                    end
                                    5'd20:begin
                                        temp1[tmp1-2] <= temp1[tmp1-2] - temp1[tmp1-1];
                                    end 
                                endcase
                                temp2[tmp2-1] <= data[count];
                                tmp1 <= tmp1 - 1;
                                count <= count + 1;
                            end 
                            3'd1:begin
                                temp2[tmp2] <= data[count];
                                tmp2 <= tmp2 + 1;
                                count <= count + 1;
                            end
                            3'd2:begin
                                if(left_parenthesis[_index-1]+1 < tmp2)begin
                                    case (temp2[tmp2-(1+pop_num)])
                                    5'd18:begin
                                        temp1[tmp1-2] <= temp1[tmp1-2] * temp1[tmp1-1];
                                    end 
                                    5'd19:begin
                                        temp1[tmp1-2] <= temp1[tmp1-2] + temp1[tmp1-1];
                                    end
                                    5'd20:begin
                                        temp1[tmp1-2] <= temp1[tmp1-2] - temp1[tmp1-1];
                                    end 
                                    endcase
                                    tmp1 <= tmp1 - 1;
                                    left_parenthesis[_index-1] <= left_parenthesis[_index-1]+1;
                                    pop_num <= pop_num + 1;
                                end
                                else begin
                                    tmp2 <= tmp2-(pop_num+1);
                                    left_parenthesis[_index-1] <= 4'b0;
                                    _index <= _index-1;
                                    count <= count+1;
                                    pop_num <= 4'b0;
                                end
                            end
                            3'd3:begin
                                temp2[tmp2] <= data[count];
                                left_parenthesis[_index] <= tmp2;  //record the location of left_parenthesis
                                _index <= _index + 1;
                                tmp2 <= tmp2 + 1;
                                count <= count + 1;
                            end
                            3'd4:begin
                                case (temp2[tmp2-1])
                                    5'd18:begin
                                        temp1[tmp1-2] <= temp1[tmp1-2] * temp1[tmp1-1];
                                    end 
                                    5'd19:begin
                                        temp1[tmp1-2] <= temp1[tmp1-2] + temp1[tmp1-1];
                                    end
                                    5'd20:begin
                                        temp1[tmp1-2] <= temp1[tmp1-2] - temp1[tmp1-1];
                                    end 
                                endcase
                                tmp1 <= tmp1 - 1;
                                if((temp2[tmp2-2]==5'd19)|(temp2[tmp2-2]==5'd20))begin    //修正當stack裡是 +or- ,* 
                                    tmp2 <= tmp2 - 1;
                                end
                                else begin
                                    temp2[tmp2-1] <= data[count];
                                    count <= count + 1;
                                end
                                
                            end 
                        endcase
                   
                    end
                    2'b00:begin  //讀完character，但stack裡尚有運算符
                        case (temp2[tmp2-1])
                            5'd18:begin
                                temp1[tmp1-2] <= temp1[tmp1-2] * temp1[tmp1-1];
                            end 
                            5'd19:begin
                                temp1[tmp1-2] <= temp1[tmp1-2] + temp1[tmp1-1];
                            end
                            5'd20:begin
                                temp1[tmp1-2] <= temp1[tmp1-2] - temp1[tmp1-1];
                            end 
                        endcase
                        tmp1 <= tmp1 - 1;
                        tmp2 <= tmp2 - 1;
                    end 
                endcase
                end
            end
            Out:begin
                valid <= 1'b1;
                result <= temp1[0];
            end 
        endcase
    end
end

always @(*) begin //ascii code to num
    case (ascii_in)
        8'd48: token = 5'd0;
        8'd49: token = 5'd1;
        8'd50: token = 5'd2;
        8'd51: token = 5'd3;
        8'd52: token = 5'd4;
        8'd53: token = 5'd5;
        8'd54: token = 5'd6;
        8'd55: token = 5'd7;
        8'd56: token = 5'd8;
        8'd57: token = 5'd9;
        8'd97: token = 5'd10;
        8'd98: token = 5'd11;
        8'd99: token = 5'd12;
        8'd100: token = 5'd13;
        8'd101: token = 5'd14;
        8'd102: token = 5'd15;
        8'd40: token = 5'd16;   // '('
        8'd41: token = 5'd17;   // ')'
        8'd42: token = 5'd18;   // '*'
        8'd43: token = 5'd19;   // '+'
        8'd45: token = 5'd20;   // '-'
        default: token = 5'd21;   // '='
    endcase
end

endmodule