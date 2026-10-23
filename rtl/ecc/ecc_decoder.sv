module ecc_decoder (
    input  logic [38:0] codeword_in,
    output logic [31:0] data_out,
    output logic [38:0] corrected_codeword,
    output logic single_error,
    output logic double_error,
    output logic uncorrectable_error
);

    integer pos;
    integer p;
    integer data_idx;
    integer syndrome;

    logic parity_value;
    logic overall_bad;

    always_comb begin
        syndrome = 0;

        // Recalculate the six Hamming parity checks.
        for (p = 0; p < 6; p = p + 1) begin
            parity_value = 1'b0;

            for (pos = 1; pos <= 38; pos = pos + 1) begin
                if ((pos & (1 << p)) != 0) begin
                    parity_value =
                        parity_value ^ codeword_in[pos-1];
                end
            end

            if (parity_value)
                syndrome = syndrome | (1 << p);
        end

        // Odd overall parity indicates an odd number of bit errors.
        overall_bad = ^codeword_in;

        corrected_codeword = codeword_in;
        single_error = 1'b0;
        double_error = 1'b0;
        uncorrectable_error = 1'b0;

        if (overall_bad) begin
            if (syndrome == 0) begin
                // Error in the overall parity bit.
                corrected_codeword[38] = ~codeword_in[38];
                single_error = 1'b1;
            end
            else if (syndrome <= 38) begin
                // Single-bit error in positions 1 through 38.
                corrected_codeword[syndrome-1] =
                    ~codeword_in[syndrome-1];
                single_error = 1'b1;
            end
            else begin
                // Not a valid single-bit syndrome.
                uncorrectable_error = 1'b1;
            end
        end
        else if (syndrome != 0) begin
            // Nonzero syndrome with even overall parity:
            // detected double-bit error.
            double_error = 1'b1;
        end

        // Extract the 32 data bits from the corrected codeword.
        data_out = '0;
        data_idx = 0;

        for (pos = 1; pos <= 38; pos = pos + 1) begin
            if ((pos & (pos - 1)) != 0) begin
                data_out[data_idx] = corrected_codeword[pos-1];
                data_idx = data_idx + 1;
            end
        end
    end

endmodule
