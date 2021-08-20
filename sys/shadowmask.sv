module shadowmask
(
	input             clk,

	input       [2:0] shadowmask_type,
	input      [23:0] din,
	input             hs_in,vs_in,
	input             de_in,

	output reg [23:0] dout,
	output reg        hs_out,vs_out,
	output reg        de_out
);

reg [2:0] hcount;
reg [1:0] vcount;

always @(posedge clk) begin
	reg old_hs, old_vs;
	
	old_hs <= hs_in;
	old_vs <= vs_in;
	hcount <= hcount + 1'd1;
	
	//code probably can be better but this works...
	if(old_hs && ~hs_in) begin  
		vcount <= vcount + 1'd1;
		hcount <= 0;
		end
	else if (hcount == 5) hcount <= 0;
	
	if(old_vs && ~vs_in) vcount <= 0;	
end

wire [7:0] r,g,b;

assign {r,g,b} = din;

reg [23:0] d;

// Each element of mask_lut is 3 bits. 1 each for R,G,B
// Red   is   100 = 4
// Green is   010 = 2
// Blue  is   001 = 1
// Magenta is 101 = 5
// Gray is    000 = 0
// White is   111 = 7
//
// So the Pattern 
// r,r,g,g,b,b 
// r,r,g,g,b,b
// g,b,b,r,r,g
// g,b,b,r,r,g
//
// is
// 4,4,2,2,1,1,0,0
// 4,4,2,2,1,1,0,0
// 2,1,1,4,4,2,0,0
// 2,1,1,4,4,2,0,0
//
//note that all rows are padded to 8 numbers although every pattern is 6 pixels wide

wire [2:0] mask_lut[160] = '{4,4,2,2,1,1,0,0, //VGA Type Mask
                             4,4,2,2,1,1,0,0,
                             2,1,1,4,4,2,0,0,
                             2,1,1,4,4,2,0,0,
                             4,4,2,2,1,1,0,0, //Squished vga mask
                             2,1,1,4,4,2,0,0,
                             4,4,2,2,1,1,0,0,
                             2,1,1,4,4,2,0,0,
                             4,2,1,4,2,1,0,0, //Thin RGB Stripes
                             4,2,1,4,2,1,0,0,
                             4,2,1,4,2,1,0,0,
                             4,2,1,4,2,1,0,0,
                             5,2,5,2,5,2,0,0, //Magenta/Green Stripes
                             5,2,5,2,5,2,0,0,
                             5,2,5,2,5,2,0,0,
                             5,2,5,2,5,2,0,0,
                             7,7,0,7,7,0,0,0, //Monochrome stripes
                             7,7,0,7,7,0,0,0,
                             7,7,0,7,7,0,0,0,
                             7,7,0,7,7,0,0,0};
									 
always @(posedge clk) begin
	
	reg rbit, gbit, bbit;
	reg [23:0] dout1, dout2;
	reg de1,de2,vs1,vs2,hs1,hs2;
	reg [8:0] r2, g2, b2; //9 bits to handle overflow
	reg [7:0] r3, g3, b3;
	reg mask_disable;
	
	{rbit,gbit, bbit} = mask_lut[{shadowmask_type,vcount,hcount}];
	mask_disable = (shadowmask_type == 5) ? 1 : 0;
	
	//This may not be the best way to do the calculation for best FMAX
	//Also, I should check that the math is actually correct and the minus sign works...
	r2 <= r + (rbit ? {3'b0, r[7:3]} : -{2'b0, r[7:2]});
	g2 <= g + (gbit ? {3'b0, g[7:3]} : -{2'b0, g[7:2]});
	b2 <= b + (bbit ? {3'b0, b[7:3]} : -{2'b0, b[7:2]});
	
	r3 <= r2[8] ? 8'd255 : r2[7:0];
	g3 <= g2[8] ? 8'd255 : g2[7:0];
	b3 <= b2[8] ? 8'd255 : b2[7:0];
	
	//I don't know how to keep the color aligned with the sync. Check on signaltap?
	// Should the mask_disable be done in the previous step?
	dout <= mask_disable ? {r,g,b} : {r3 ,g3, b3};
	vs_out <= vs2;   vs2   <= vs1;   vs1   <= vs_in;
	hs_out <= hs2;   hs2   <= hs1;   hs1   <= hs_in;
	de_out <= de2;   de2   <= de1;   de1   <= de_in;
end

endmodule
