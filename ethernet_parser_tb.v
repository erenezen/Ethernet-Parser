`timescale 1ns/1ps
module ethernet_parser_tb;

reg clk = 0;
always #5 clk = ~clk;

reg rst_n;
reg [63:0] s_axis_tdata;
reg [7:0]  s_axis_tkeep;
reg        s_axis_tvalid;
wire       s_axis_tready;
reg        s_axis_tlast;

wire [63:0] m_axis_tdata;
wire [7:0]  m_axis_tkeep;
wire        m_axis_tvalid;
reg         m_axis_tready;
wire        m_axis_tlast;

wire parsed_valid_pulse;
wire [47:0] dst_mac, src_mac;
wire [15:0] ethertype, src_port, dst_port;
wire [31:0] src_ip, dst_ip;

ethernet_parser dut (
  .clk(clk), .rst_n(rst_n),
  .s_axis_tdata(s_axis_tdata),
  .s_axis_tkeep(s_axis_tkeep),
  .s_axis_tvalid(s_axis_tvalid),
  .s_axis_tready(s_axis_tready),
  .s_axis_tlast(s_axis_tlast),
  .m_axis_tdata(m_axis_tdata),
  .m_axis_tkeep(m_axis_tkeep),
  .m_axis_tvalid(m_axis_tvalid),
  .m_axis_tready(m_axis_tready),
  .m_axis_tlast(m_axis_tlast),
  .parsed_valid_pulse(parsed_valid_pulse),
  .dst_mac(dst_mac), .src_mac(src_mac),
  .ethertype(ethertype),
  .src_ip(src_ip), .dst_ip(dst_ip),
  .src_port(src_port), .dst_port(dst_port)
);

task send_word(input [63:0] data, input [7:0] keep, input last);
begin
  s_axis_tdata  <= data;
  s_axis_tkeep  <= keep;
  s_axis_tvalid <= 1;
  s_axis_tlast  <= last;
  wait(s_axis_tready);
  @(posedge clk);
  s_axis_tvalid <= 0;
  s_axis_tlast  <= 0;
end
endtask

initial begin
  rst_n = 0;
  s_axis_tvalid = 0;
  s_axis_tlast = 0;
  s_axis_tdata = 0;
  s_axis_tkeep = 0;
  m_axis_tready = 1;

  repeat (4) @(posedge clk); // Reset is held low for 4 clock cycles, then released
  rst_n = 1;
  repeat (2) @(posedge clk); // wait 2 more clocks for system to stabilize


  send_word(64'h001122334455_6677, 8'hFF, 0);
  send_word(64'h889AABB_0800_4500, 8'hFF, 0);
  send_word(64'h003C000040004011, 8'hFF, 0);
  send_word(64'hC0A80001C0A80002, 8'hFF, 0);
  send_word(64'h1F909C40001C0000, 8'hFF, 0);
  send_word(64'hDEADBEEF00000000, 8'h0F, 1);

  repeat (10) @(posedge clk);
  $finish;
end
endmodule
