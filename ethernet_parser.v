module ethernet_parser (
    input wire clk,
    input wire rst_n,

    // AXI-Stream Input (From MAC/Network)
    input  wire [63:0] s_axis_tdata,   
    input  wire [7:0]  s_axis_tkeep,   
    input  wire        s_axis_tvalid,  
    output wire        s_axis_tready,  
    input  wire        s_axis_tlast,   

    // AXI-Stream Output (Parsed Data Forwarded)
    output reg  [63:0] m_axis_tdata,   
    output reg  [7:0]  m_axis_tkeep,   
    output reg         m_axis_tvalid,  
    input  wire        m_axis_tready,  
    output reg         m_axis_tlast,   

    // Parsed Header Outputs
    output reg         parsed_valid_pulse, 
    output reg [47:0]  dst_mac,
    output reg [47:0]  src_mac,
    output reg [15:0]  ethertype,
    output reg [31:0]  src_ip,
    output reg [31:0]  dst_ip,
    output reg [15:0]  src_port,
    output reg [15:0]  dst_port
);

// FSM State Definitions
// -----------------------------------------------------------------------------
localparam IDLE    = 3'd0, 
           WORD1   = 3'd1, 
           WORD2   = 3'd2, 
           WORD3   = 3'd3, 
           WORD4   = 3'd4, 
           WORD5   = 3'd5, 
           PAYLOAD = 3'd6; 

reg [2:0] state;           // FSM current state
reg [2:0] word_count;      // debug tracking
reg parsing_done;          // One-time flag to prevent duplicate pulse

// Handshake Logic
assign s_axis_tready = (m_axis_tready || !m_axis_tvalid);

// Parser Logic
// -----------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all state and outputs
        state <= IDLE;
        word_count <= 0;
        parsing_done <= 0;
        parsed_valid_pulse <= 0;

        dst_mac <= 0; src_mac <= 0; ethertype <= 0;
        src_ip <= 0; dst_ip <= 0;
        src_port <= 0; dst_port <= 0;

        m_axis_tdata <= 0;
        m_axis_tkeep <= 0;
        m_axis_tvalid <= 0;
        m_axis_tlast <= 0;
    end else begin
        // pulse is cleared every clock by default 
        parsed_valid_pulse <= 0;
        // Clear output valid flag once data is accepted
        if (m_axis_tvalid && m_axis_tready) begin
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end

        // Proceed only when handshake occurs
        if (s_axis_tvalid && s_axis_tready) begin
            // Forward every incoming word as it is
            m_axis_tdata  <= s_axis_tdata;
            m_axis_tkeep  <= s_axis_tkeep;
            m_axis_tvalid <= 1;
            m_axis_tlast  <= s_axis_tlast;

            case (state)
                IDLE: begin
                    state <= WORD1;
                    word_count <= 0;
                    parsing_done <= 0;

                    dst_mac[47:0]   <= s_axis_tdata[63:16]; // First 6 bytes
                    src_mac[47:32]  <= s_axis_tdata[15:0];  // Next 2 bytes
                end

                WORD1: begin
                    state <= WORD2;
                    src_mac[31:0]  <= s_axis_tdata[63:32]; // Remaining 4 bytes
                    ethertype      <= s_axis_tdata[31:16]; // 2 bytes EtherType
                end

                WORD2: begin
                    state <= WORD3;                
                end

                WORD3: begin
                    state <= WORD4;
                    src_ip <= s_axis_tdata[63:32]; // Source IP Address (4 bytes)
                    dst_ip <= s_axis_tdata[31:0];  // Destination IP Address (4 bytes)
                end

                WORD4: begin
                    state <= WORD5;
                    src_port <= s_axis_tdata[63:48]; // 2 bytes
                    dst_port <= s_axis_tdata[47:32]; // 2 bytes

                    parsed_valid_pulse <= 1;      // Trigger pulse
                    parsing_done <= 1;
                end

                WORD5: begin
                    state <= PAYLOAD;
                end

                PAYLOAD: begin
                    if (s_axis_tlast) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
end

endmodule