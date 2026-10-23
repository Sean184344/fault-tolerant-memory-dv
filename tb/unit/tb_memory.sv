module tb_memory;

    logic clk = 0;
    logic rst_n = 0;

    logic req_valid = 0;
    logic req_write = 0;
    logic [7:0] addr = 0;
    logic [31:0] wdata = 0;

    logic rsp_valid;
    logic [31:0] rdata;
    logic single_error;
    logic double_error;
    logic uncorrectable_error;

    logic scrub_busy;
    logic [31:0] scrub_correction_count;
    logic [31:0] scrub_double_error_count;

    logic [38:0] original_codeword;
    integer timeout_count;

    ecc_memory dut (
        .clk(clk),
        .rst_n(rst_n),
        .req_valid(req_valid),
        .req_write(req_write),
        .addr(addr),
        .wdata(wdata),
        .rsp_valid(rsp_valid),
        .rdata(rdata),
        .single_error(single_error),
        .double_error(double_error),
        .uncorrectable_error(uncorrectable_error),
        .scrub_busy(scrub_busy),
        .scrub_correction_count(scrub_correction_count),
        .scrub_double_error_count(scrub_double_error_count)
    );

    always #5 clk = ~clk;

    task automatic write_word(
        input logic [7:0] a,
        input logic [31:0] d
    );
        @(negedge clk);
        req_valid = 1;
        req_write = 1;
        addr = a;
        wdata = d;

        @(negedge clk);
        req_valid = 0;
        req_write = 0;
    endtask

    task automatic read_word(
        input logic [7:0] a
    );
        @(negedge clk);
        req_valid = 1;
        req_write = 0;
        addr = a;

        @(posedge clk);
        #1;

        if (!rsp_valid)
            $fatal(1, "Missing response for address %0d", a);

        @(negedge clk);
        req_valid = 0;
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;

        // Basic write/read.
        write_word(8'd10, 32'hDEADBEEF);
        read_word(8'd10);

        if (rdata !== 32'hDEADBEEF)
            $fatal(1, "Basic read failed: %h", rdata);

        // Single-bit correction on read.
        original_codeword = dut.mem[10];
        dut.mem[10][5] = ~dut.mem[10][5];

        read_word(8'd10);

        if (rdata !== 32'hDEADBEEF || !single_error ||
            double_error || uncorrectable_error)
            $fatal(1, "Single-bit correction failed");

        // Wait until the scrubber repairs address 10.
        timeout_count = 0;
        while (dut.mem[10] !== original_codeword &&
               timeout_count < 1000) begin
            @(negedge clk);
            timeout_count = timeout_count + 1;
        end

        if (dut.mem[10] !== original_codeword)
            $fatal(1, "Scrubber did not repair codeword");

        if (scrub_correction_count == 0)
            $fatal(1, "Scrubber correction counter did not increment");

        // Inject two errors and verify detection.
        dut.mem[10][5] = ~dut.mem[10][5];
        dut.mem[10][8] = ~dut.mem[10][8];

        read_word(8'd10);

        if (!double_error || single_error || uncorrectable_error)
            $fatal(1, "Double-bit detection failed");

        // A write replaces the corrupted codeword.
        write_word(8'd10, 32'h12345678);
        read_word(8'd10);

        if (rdata !== 32'h12345678 ||
            single_error || double_error || uncorrectable_error)
            $fatal(1, "Rewrite/recovery test failed");

        $display("PASS: basic memory read/write");
        $display("PASS: single-bit correction");
        $display("PASS: scrubber repairs stored codeword");
        $display("PASS: double-bit detection");
        $display("PASS: rewrite after corruption");
        $display("Scrubber repairs: %0d", scrub_correction_count);
        $display("ALL MEMORY TESTS PASSED");

        $finish;
    end

endmodule
