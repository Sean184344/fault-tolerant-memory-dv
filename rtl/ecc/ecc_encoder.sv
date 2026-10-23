module ecc_encoder (
    input  logic [31:0] data_in,
    output logic [38:0] codeword_out
);

    integer pos;
    integer data_idx;
    integer p;
    logic parity_value;

    always_comb begin
        codeword_out = '0;
        data_idx = 0;

        // Positions 1 through 38; parity positions are powers of two.
        for (pos = 1; pos <= 38; pos = pos + 1) begin
            if ((pos & (pos - 1)) != 0) begin
                codeword_out[pos-1] = data_in[data_idx];
                data_idx = data_idx + 1;
            end
        end

        // Six Hamming parity bits, using even parity.
        for (p = 0; p < 6; p = p + 1) begin
            parity_value = 1'b0;

            for (pos = 1; pos <= 38; pos = pos + 1) begin
                if (((pos & (1 << p)) != 0) &&
                    (pos != (1 << p))) begin
                    parity_value = parity_value ^ codeword_out[pos-1];
                end
            end

            codeword_out[(1 << p)-1] = parity_value;
        end

        // Overall parity bit: codeword position 39.
        codeword_out[38] = ^codeword_out[37:0];
    end

endmodule
