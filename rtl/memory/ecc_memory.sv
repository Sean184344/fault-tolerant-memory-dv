module ecc_memory #(
    parameter ADDR_WIDTH = 8,
    parameter DEPTH = 256
) (
    input  logic clk,
    input  logic rst_n,
    input  logic req_valid,
    input  logic req_write,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [31:0] wdata,

    output logic rsp_valid,
    output logic [31:0] rdata,
    output logic single_error,
    output logic double_error,
    output logic uncorrectable_error,

    output logic scrub_busy,
    output logic [31:0] scrub_correction_count,
    output logic [31:0] scrub_double_error_count
);

    logic [38:0] mem [0:DEPTH-1];
    logic [DEPTH-1:0] valid_words;

    logic [38:0] encoded;
    logic [38:0] decoded_codeword;
    logic [31:0] decoded_data;
    logic dec_single, dec_double, dec_uncorrectable;

    logic [ADDR_WIDTH-1:0] scrub_addr;
    logic [38:0] scrub_codeword;
    logic [31:0] scrub_data;
    logic scrub_single, scrub_double, scrub_uncorrectable;

    typedef enum logic {
        SCRUB_SCAN,
        SCRUB_REPAIR
    } scrub_state_t;

    scrub_state_t scrub_state;

    ecc_encoder u_encoder (
        .data_in(wdata),
        .codeword_out(encoded)
    );

    ecc_decoder u_decoder (
        .codeword_in(mem[addr]),
        .data_out(decoded_data),
        .corrected_codeword(decoded_codeword),
        .single_error(dec_single),
        .double_error(dec_double),
        .uncorrectable_error(dec_uncorrectable)
    );

    ecc_decoder u_scrub_decoder (
        .codeword_in(mem[scrub_addr]),
        .data_out(scrub_data),
        .corrected_codeword(scrub_codeword),
        .single_error(scrub_single),
        .double_error(scrub_double),
        .uncorrectable_error(scrub_uncorrectable)
    );

    assign scrub_busy = 1'b1;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rsp_valid <= 1'b0;
            rdata <= '0;
            single_error <= 1'b0;
            double_error <= 1'b0;
            uncorrectable_error <= 1'b0;
            valid_words <= '0;
            scrub_addr <= '0;
            scrub_state <= SCRUB_SCAN;
            scrub_correction_count <= '0;
            scrub_double_error_count <= '0;
        end else begin
            rsp_valid <= 1'b0;
            single_error <= 1'b0;
            double_error <= 1'b0;
            uncorrectable_error <= 1'b0;

            if (req_valid) begin
                rsp_valid <= 1'b1;

                if (req_write) begin
                    mem[addr] <= encoded;
                    valid_words[addr] <= 1'b1;
                    rdata <= '0;
                end else if (valid_words[addr]) begin
                    rdata <= decoded_data;
                    single_error <= dec_single;
                    double_error <= dec_double;
                    uncorrectable_error <= dec_uncorrectable;
                end else begin
                    rdata <= '0;
                end
            end else begin
                case (scrub_state)
                    SCRUB_SCAN: begin
                        if (valid_words[scrub_addr]) begin
                            if (scrub_single) begin
                                scrub_state <= SCRUB_REPAIR;
                            end else begin
                                if (scrub_double)
                                    scrub_double_error_count <=
                                        scrub_double_error_count + 1'b1;

                                if (scrub_addr == ADDR_WIDTH'(DEPTH-1))
                                    scrub_addr <= '0;
                                else
                                    scrub_addr <= scrub_addr + 1'b1;
                            end
                        end else begin
                            if (scrub_addr == ADDR_WIDTH'(DEPTH-1))
                                scrub_addr <= '0;
                            else
                                scrub_addr <= scrub_addr + 1'b1;
                        end
                    end

                    SCRUB_REPAIR: begin
                        mem[scrub_addr] <= scrub_codeword;
                        scrub_correction_count <=
                            scrub_correction_count + 1'b1;

                        if (scrub_addr == ADDR_WIDTH'(DEPTH-1))
                            scrub_addr <= '0;
                        else
                            scrub_addr <= scrub_addr + 1'b1;

                        scrub_state <= SCRUB_SCAN;
                    end
                endcase
            end
        end
    end

endmodule
