module NN(
	// Input signals
	clk,
	rst_n,
	in_valid_u,
	in_valid_w,
	in_valid_v,
	in_valid_x,
	weight_u,
	weight_w,
	weight_v,
	data_x,
	// Output signals
	out_valid,
	out
);

//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch = 2;
parameter inst_arch_type= 0;
parameter inst_rnd=3'b000;
wire [7:0] status_inst;

parameter FP_ZERO = 32'b0_0000_0000_00000000000000000000000 ;
parameter FP_ONE = 32'b0_0111_1111_00000000000000000000000 ;
parameter IDLE=2'd0,LOAD=2'd1,OUT=2'd2;
reg [1:0] ns,cs;
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input  clk, rst_n, in_valid_u, in_valid_w, in_valid_v, in_valid_x;
input [inst_sig_width+inst_exp_width:0] weight_u, weight_w, weight_v;
input [inst_sig_width+inst_exp_width:0] data_x;
output reg	out_valid;
output reg [inst_sig_width+inst_exp_width:0] out;

//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
reg [22:0] state;
reg [3:0] cnt;
reg [5:0]cnt_in;
genvar  i;
integer j;

reg [inst_sig_width+inst_exp_width:0] weight_u_r [0:8];
reg [inst_sig_width+inst_exp_width:0] weight_w_r [0:8];
reg [inst_sig_width+inst_exp_width:0] weight_v_r [0:8];
reg [inst_sig_width+inst_exp_width:0] x_r [0:8];
reg [inst_sig_width+inst_exp_width:0] y_r [0:8];

reg [inst_sig_width+inst_exp_width:0] h_r [0:2];

wire [inst_sig_width+inst_exp_width:0] dp_ans[0:2];
reg  [inst_sig_width+inst_exp_width:0] dp1[0:8],dp2[0:2];


wire [inst_sig_width+inst_exp_width:0] sum_ans[0:2];
reg  [inst_sig_width+inst_exp_width:0] sum1[0:2],sum2[0:2];

wire [inst_sig_width+inst_exp_width:0] exp_ans[0:2];
reg  [inst_sig_width+inst_exp_width:0] exp[0:2];

wire [inst_sig_width+inst_exp_width:0] recip_ans[0:2];
reg  [inst_sig_width+inst_exp_width:0] recip[0:2];



wire [inst_sig_width+inst_exp_width:0] g_w[0:2];
reg  [inst_sig_width+inst_exp_width:0] g_r[0:2];

DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) EXP1(.a(exp[0]), .z(exp_ans[0]), .status(status_inst));
DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) EXP2(.a(exp[1]), .z(exp_ans[1]), .status(status_inst));
DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) EXP3(.a(exp[2]), .z(exp_ans[2]), .status(status_inst));
DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) ADD1(.a(sum1[0]), .b(sum2[0]), .rnd(inst_rnd), .z(sum_ans[0]), .status(status_inst));
DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) ADD2(.a(sum1[1]), .b(sum2[1]), .rnd(inst_rnd), .z(sum_ans[1]), .status(status_inst));
DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) ADD3(.a(sum1[2]), .b(sum2[2]), .rnd(inst_rnd), .z(sum_ans[2]), .status(status_inst));
DW_fp_dp3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type) DP1(.a(dp1[0]), .b(dp2[0]), .c(dp1[1]),.d(dp2[1]),.e(dp1[2]),.f(dp2[2]),.rnd(inst_rnd), .z(dp_ans[0]), .status(status_inst));
DW_fp_dp3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type) DP2(.a(dp1[3]), .b(dp2[0]), .c(dp1[4]),.d(dp2[1]),.e(dp1[5]),.f(dp2[2]),.rnd(inst_rnd), .z(dp_ans[1]), .status(status_inst));
DW_fp_dp3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type) DP3(.a(dp1[6]), .b(dp2[0]), .c(dp1[7]),.d(dp2[1]),.e(dp1[8]),.f(dp2[2]),.rnd(inst_rnd), .z(dp_ans[2]), .status(status_inst));
DW_fp_recip #(inst_sig_width, inst_exp_width, inst_ieee_compliance,0) RECIP1(.a(recip[0]),.rnd(inst_rnd), .z(recip_ans[0]), .status(status_inst));
DW_fp_recip #(inst_sig_width, inst_exp_width, inst_ieee_compliance,0) RECIP2(.a(recip[1]),.rnd(inst_rnd), .z(recip_ans[1]), .status(status_inst));
DW_fp_recip #(inst_sig_width, inst_exp_width, inst_ieee_compliance,0) RECIP3(.a(recip[2]),.rnd(inst_rnd), .z(recip_ans[2]), .status(status_inst));


always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		cs<=IDLE;
	end
	else begin
		cs<=ns;
	end
end
always@(*) begin
	case(cs)
	IDLE:begin
		if(in_valid_x) 
		begin
			ns=LOAD;
		end
		else begin
			ns = IDLE;
		end
	end
	LOAD:begin
		if(state[21])
		begin
			ns = OUT;
		end
		else begin
			ns = LOAD;
		end
	end
	OUT:begin
		if(cnt>8)
		begin
			ns = IDLE;
		end
		else begin
			ns = OUT;
		end
	end
	default:ns = IDLE;
	endcase
end
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
			cnt_in<='b0;
	end
	else if(ns == IDLE)
	begin
		cnt_in<='b0;
	end
	else if(ns == LOAD)
	begin
		cnt_in<=cnt_in+1'd1;
	end
end


always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(j=0;j<23;j=j+1)
		begin
			state[j]<=1'b0;
		end
	end
	else if(ns == IDLE)
	begin
		for(j=0;j<23;j=j+1)
		begin
			state[j]<=1'b0;
		end
	end
	else if(ns == LOAD)
	begin
		state[0]<=in_valid_x;
		if(!in_valid_x )
		begin
			for(j=1;j<23;j=j+1)
			begin
				state[j]<=state[j-1];
			end
		end
	end
end
//0
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(j=0;j<9;j=j+1)
		weight_u_r[j]<='b0;
	end
	else if(ns == IDLE)
	begin
		for(j=0;j<9;j=j+1)
		weight_u_r[j]<='b0;
	end
	else if(ns==LOAD)
	begin
		if(cnt_in==4'd0) weight_u_r[0]<=weight_u;
		else if(cnt_in==4'd1) weight_u_r[1]<=weight_u;
		else if(cnt_in==4'd2) weight_u_r[2]<=weight_u;
		else if(cnt_in==4'd3) weight_u_r[3]<=weight_u;
		else if(cnt_in==4'd4) weight_u_r[4]<=weight_u;
		else if(cnt_in==4'd5) weight_u_r[5]<=weight_u;
		else if(cnt_in==4'd6) weight_u_r[6]<=weight_u;
		else if(cnt_in==4'd7) weight_u_r[7]<=weight_u;
		else if(cnt_in==4'd8) weight_u_r[8]<=weight_u;
	end
end
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(j=0;j<9;j=j+1)
		weight_w_r[j]<='b0;
	end
	else if(ns == IDLE)
	begin
		for(j=0;j<9;j=j+1)
		weight_w_r[j]<='b0;
	end
	else if(ns==LOAD)
	begin
		if(cnt_in==4'd0) weight_w_r[0]<=weight_w;
		else if(cnt_in==4'd1) weight_w_r[1]<=weight_w;
		else if(cnt_in==4'd2) weight_w_r[2]<=weight_w;
		else if(cnt_in==4'd3) weight_w_r[3]<=weight_w;
		else if(cnt_in==4'd4) weight_w_r[4]<=weight_w;
		else if(cnt_in==4'd5) weight_w_r[5]<=weight_w;
		else if(cnt_in==4'd6) weight_w_r[6]<=weight_w;
		else if(cnt_in==4'd7) weight_w_r[7]<=weight_w;
		else if(cnt_in==4'd8) weight_w_r[8]<=weight_w;
	end
end

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(j=0;j<9;j=j+1)
		weight_v_r[j]<='b0;
	end
	else if(ns == IDLE)
	begin
		for(j=0;j<9;j=j+1)
		weight_v_r[j]<='b0;
	end
	else if(ns==LOAD)
	begin
		if(cnt_in==4'd0) weight_v_r[0]<=weight_v;
		else if(cnt_in==4'd1) weight_v_r[1]<=weight_v;
		else if(cnt_in==4'd2) weight_v_r[2]<=weight_v;
		else if(cnt_in==4'd3) weight_v_r[3]<=weight_v;
		else if(cnt_in==4'd4) weight_v_r[4]<=weight_v;
		else if(cnt_in==4'd5) weight_v_r[5]<=weight_v;
		else if(cnt_in==4'd6) weight_v_r[6]<=weight_v;
		else if(cnt_in==4'd7) weight_v_r[7]<=weight_v;
		else if(cnt_in==4'd8) weight_v_r[8]<=weight_v;
	end
end

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(j=0;j<9;j=j+1)
		x_r[j]<='b0;
	end
	else if(ns == IDLE)
	begin
		for(j=0;j<9;j=j+1)
		x_r[j]<='b0;
	end
	else if(ns==LOAD)
	begin
		if(cnt_in==4'd0) x_r[0]<=data_x;
		else if(cnt_in==4'd1) x_r[1]<=data_x;
		else if(cnt_in==4'd2) x_r[2]<=data_x;
		else if(cnt_in==4'd3) x_r[3]<=data_x;
		else if(cnt_in==4'd4) x_r[4]<=data_x;
		else if(cnt_in==4'd5) x_r[5]<=data_x;
		else if(cnt_in==4'd6) x_r[6]<=data_x;
		else if(cnt_in==4'd7) x_r[7]<=data_x;
		else if(cnt_in==4'd8) x_r[8]<=data_x;
	end
end

generate
	for(i=0;i<3;i=i+1) 
	begin
		always@(posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				h_r[i]<='b0;
			end
			else if(ns == IDLE)
			begin
				h_r[i]<='b0;
			end
			else if(state[5])
			begin
				h_r[i]<=recip_ans[i];
			end
			else if(state[12])
			begin
				h_r[i]<=recip_ans[i];
			end
		end
	end

endgenerate
//1
generate
	for(i=0;i<9;i=i+1) 
	begin
		always@(posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				dp1[i]<='b0;
			end
			else if(ns == IDLE)
			begin
				dp1[i]<='b0;
			end
			else if(state[1])
			begin
				dp1[i]<=weight_u_r[i];
			end
			else if(state[2])
			begin
				dp1[i]<=weight_w_r[i];
			end
			else if(state[5])
			begin
				dp1[i]<=weight_v_r[i];
			end
			else if(state[6])
			begin
				dp1[i]<=weight_u_r[i];
			end
			else if(state[7])
			begin
				dp1[i]<=weight_w_r[i];
			end
			else if(state[12])
			begin
				dp1[i]<=weight_v_r[i];
			end
			else if(state[13])
			begin
				dp1[i]<=weight_u_r[i];
			end
			else if(state[14])
			begin
				dp1[i]<=weight_w_r[i];
			end
			else if(state[19])
			begin
				dp1[i]<=weight_v_r[i];
			end
		end
	end

endgenerate
generate
	for(i=0;i<3;i=i+1) 
	begin
		always@(posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				dp2[i]<='b0;
			end
			else if(ns == IDLE)
			begin
				dp2[i]<='b0;
			end
			else if(state[1])
			begin
				dp2[i]<=x_r[i];
			end
			else if(state[5])
			begin
				dp2[i]<=recip_ans[i];
			end
			else if(state[6])
			begin
				dp2[i]<=x_r[i+3];
			end
			else if(state[7])
			begin
				dp2[i]<=h_r[i];
			end
			else if(state[12])
			begin
				dp2[i]<=recip_ans[i];
			end
			else if(state[13])
			begin
				dp2[i]<=x_r[i+6];
			end
			else if(state[14])
			begin
				dp2[i]<=h_r[i];
			end
			else if(state[19])
			begin
				dp2[i]<=recip_ans[i];
			end
		end
	end
endgenerate



generate
	for(i=0;i<3;i=i+1) 
	begin
		always@(posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				sum1[i]<='b0;
			end
			else if(ns == IDLE)
			begin
				sum1[i]<='b0;
			end
			else if(state[3])
			begin
				sum1[i]<=exp_ans[i];
			end
			else if(state[7])
			begin
				sum1[i]<=dp_ans[i];
			end
			else if(state[10])
			begin
				sum1[i]<=exp_ans[i];
			end
			else if(state[14])
			begin
				sum1[i]<=dp_ans[i];
			end
			else if(state[17])
			begin
				sum1[i]<=exp_ans[i];
			end
		end
	end
endgenerate

generate
	for(i=0;i<3;i=i+1) 
	begin
		always@(posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				sum2[i]<='b0;
			end
			else if(ns == IDLE)
			begin
				sum2[i]<='b0;
			end
			else if(state[3])
			begin
				sum2[i]<=FP_ONE ;
			end
			else if(state[8])
			begin
				sum2[i]<=dp_ans[i] ;
			end
			else if(state[10])
			begin
				sum2[i]<=FP_ONE ;
			end
			else if(state[15])
			begin
				sum2[i]<=dp_ans[i] ;
			end
			else if(state[17])
			begin
				sum2[i]<=FP_ONE ;
			end
		end
	end
endgenerate

generate
	for(i=0;i<3;i=i+1) 
	begin
		always@(posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				exp[i]<='b0;
			end
			else if(ns == IDLE)
			begin
				exp[i]<='b0;
			end
			else if(state[2])
			begin
				exp[i]<={{~{dp_ans[i][31]}},{dp_ans[i][30:0]}};
			end
			else if(state[9])
			begin
				exp[i]<={{~{sum_ans[i][31]}},{sum_ans[i][30:0]}};
			end
			else if(state[16])
			begin
				exp[i]<={{~{sum_ans[i][31]}},{sum_ans[i][30:0]}};
			end
			
		end
	end
endgenerate

generate
	for(i=0;i<3;i=i+1) 
	begin
		always@(posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				recip[i]<='b0;
			end
			else if(ns == IDLE)
			begin
				recip[i]<='b0;
			end
			else if(state[4])
			begin
				recip[i]<=sum_ans[i];
			end
			else if(state[11])
			begin
				recip[i]<=sum_ans[i];
			end
			else if(state[18])
			begin
				recip[i]<=sum_ans[i];
			end
		end
	end
endgenerate
generate
for(i=0;i<3;i=i+1)
begin
	assign g_w[i] =( dp_ans[i][31]== 1'b1)? FP_ZERO : dp_ans[i];
end
endgenerate

//4
generate
	for(i=0;i<3;i=i+1) 
	begin
		always@(posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				g_r[i]<='b0;
			end
			else if(ns == IDLE)
			begin
				g_r[i]<='b0;
			end
			else if(state[6])
			begin
				g_r[i]<=g_w[i];
			end
			else if(state[13])
			begin
				g_r[i]<=g_w[i];
			end
			else if(state[20])
			begin
				g_r[i]<=g_w[i];
			end
		end
	end

endgenerate

generate
	for(i=0;i<3;i=i+1) 
	begin
		always@(posedge clk or negedge rst_n) begin
			if(!rst_n) begin
				y_r[i]<='b0;
				y_r[i+3]<='b0;
				y_r[i+6]<='b0;
			end
			else if(ns == IDLE)
			begin
				y_r[i]<='b0;
				y_r[i+3]<='b0;
				y_r[i+6]<='b0;
			end
			else if(state[7])
			begin
				y_r[i]<=g_r[i];
			end
			else if(state[15])
			begin
				y_r[i+3]<=g_r[i];
			end
			else if(state[21])
			begin
				y_r[i+6]<=g_r[i];
			end
		end
	end

endgenerate
//out
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_valid<=1'b0;
	end
	else if( ns == IDLE)
	begin
		out_valid<=1'b0;
	end
	else if(ns == OUT)
	begin
		out_valid<=1'b1;
	end
end
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out<='b0;
	end
	else if( ns == IDLE)
	begin
		out<='b0;
	end
	else if(ns == OUT)
	begin
		if(cnt==4'd0) out<=y_r[0];
		else if(cnt==4'd1) out<=y_r[1];
		else if(cnt==4'd2) out<=y_r[2];
		else if(cnt==4'd3) out<=y_r[3];
		else if(cnt==4'd4) out<=y_r[4];
		else if(cnt==4'd5) out<=y_r[5];
		else if(cnt==4'd6) out<=y_r[6];
		else if(cnt==4'd7) out<=y_r[7];
		else if(cnt==4'd8) out<=y_r[8];

	end
end
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		cnt<=4'b0;
	end
	else if(ns == IDLE)
	begin
		cnt<=4'b0;
	end
	else if(ns == OUT)
	begin
		cnt<=cnt+4'd1;
	end
end
//cal
endmodule
