module tb_ecc;

    logic [31:0] data_in;
    logic [38:0] encoded;
    logic [38:0] corrupted;

    logic [31:0] decoded_data;
    logic [38:0] corrected_codeword;
    logic single_error;
    logic double_error;
    logic uncorrectable_error;

    integer i, j, k;
    integer single_tests;
    integer double_tests;
    integer random_tests;

    ecc_encoder u_encoder (
        .data_in(data_in),
        .codeword_out(encoded)
    );

    ecc_decoder u_decoder (
        .codeword_in(corrupted),
        .data_out(decoded_data),
        .corrected_codeword(corrected_codeword),
        .single_error(single_error),
        .double_error(double_error),
        .uncorrectable_error(uncorrectable_error)
    );

    initial begin
        single_tests = 0;
        double_tests = 0;
        random_tests = 0;

        data_in = '0;
        corrupted = '0;
        #1;

        // Directed and randomized payloads.
        for (k = 0; k < 104; k = k + 1) begin
            case (k)
                0: data_in = 32'h00000000;
                1: data_in = 32'hFFFFFFFF;
                2: data_in = 32'hAAAAAAAA;
                3: data_in = 32'h55555555;
                default: data_in = $urandom;
            endcase

            #1;
            corrupted = encoded;
            #1;

            // Clean codeword.
            if (decoded_data !== data_in ||
                single_error !== 1'b0 ||
                double_error !== 1'b0 ||
                uncorrectable_error !== 1'b0) begin
                $fatal(1, "Clean-codeword test failed: data=%h decoded=%h",
                       data_in, decoded_data);
            end

            if (k >= 4)
                random_tests = random_tests + 1;

            // Every possible single-bit corruption.
            for (i = 0; i < 39; i = i + 1) begin
                corrupted = encoded ^ (39'b1 << i);
                #1;

                if (decoded_data !== data_in ||
                    single_error !== 1'b1 ||
                    double_error !== 1'b0 ||
                    uncorrectable_error !== 1'b0) begin
                    $fatal(1,
                        "Single-bit test failed: data=%h bit=%0d decoded=%h",
                        data_in, i, decoded_data);
                end

                if (corrected_codeword !== encoded) begin
                    $fatal(1,
                        "Correction mismatch: data=%h bit=%0d",
                        data_in, i);
                end

                single_tests = single_tests + 1;
            end

            // Every distinct pair of corrupted bits.
            for (i = 0; i < 39; i = i + 1) begin
                for (j = i + 1; j < 39; j = j + 1) begin
                    corrupted = encoded
                              ^ (39'b1 << i)
                              ^ (39'b1 << j);
                    #1;

                    if (double_error !== 1'b1 ||
                        single_error !== 1'b0 ||
                        uncorrectable_error !== 1'b0) begin
                        $fatal(1,
                            "Double-bit test failed: data=%h bits=%0d,%0d",
                            data_in, i, j);
                    end

                    double_tests = double_tests + 1;
                end
            end
        end

        $display("PASS: clean payload tests = 104");
        $display("PASS: single-bit corrections = %0d", single_tests);
        $display("PASS: double-bit detections = %0d", double_tests);
        $display("PASS: randomized payloads = %0d", random_tests);
        $display("ALL ECC TESTS PASSED");

        $finish;
    end

endmodule
