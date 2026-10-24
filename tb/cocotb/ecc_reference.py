"""Independent Python reference model for a 32-bit SECDED ECC."""

DATA_WIDTH = 32
CODE_WIDTH = 39
PARITY_POSITIONS = {1, 2, 4, 8, 16, 32}


def encode(data: int) -> int:
    """Encode 32-bit data into a 39-bit SECDED codeword."""
    if not 0 <= data < (1 << DATA_WIDTH):
        raise ValueError("data must be a 32-bit unsigned integer")

    bits = [0] * (CODE_WIDTH + 1)
    data_index = 0

    # Positions 1..38 use Hamming parity at powers of two.
    for pos in range(1, 39):
        if pos not in PARITY_POSITIONS:
            bits[pos] = (data >> data_index) & 1
            data_index += 1

    # Even Hamming parity.
    for parity_pos in sorted(PARITY_POSITIONS):
        parity = 0
        for pos in range(1, 39):
            if pos & parity_pos and pos != parity_pos:
                parity ^= bits[pos]
        bits[parity_pos] = parity

    # Overall parity occupies codeword bit 38 (position 39).
    bits[39] = 0
    for pos in range(1, 39):
        bits[39] ^= bits[pos]

    codeword = 0
    for pos in range(1, 40):
        codeword |= bits[pos] << (pos - 1)

    return codeword


def decode(codeword: int) -> dict:
    """Decode a 39-bit codeword and classify SECDED errors."""
    if not 0 <= codeword < (1 << CODE_WIDTH):
        raise ValueError("codeword must be a 39-bit unsigned integer")

    bits = [0] * (CODE_WIDTH + 1)
    for pos in range(1, 40):
        bits[pos] = (codeword >> (pos - 1)) & 1

    syndrome = 0
    for parity_pos in sorted(PARITY_POSITIONS):
        parity = 0
        for pos in range(1, 39):
            if pos & parity_pos:
                parity ^= bits[pos]
        if parity:
            syndrome |= parity_pos

    overall_bad = 0
    for pos in range(1, 40):
        overall_bad ^= bits[pos]

    corrected = codeword
    single_error = False
    double_error = False
    uncorrectable_error = False

    if overall_bad:
        if syndrome == 0:
            # Error in the overall parity bit.
            corrected ^= 1 << 38
            single_error = True
        elif syndrome <= 38:
            corrected ^= 1 << (syndrome - 1)
            single_error = True
        else:
            uncorrectable_error = True
    elif syndrome != 0:
        double_error = True

    corrected_bits = [0] * (CODE_WIDTH + 1)
    for pos in range(1, 40):
        corrected_bits[pos] = (corrected >> (pos - 1)) & 1

    data = 0
    data_index = 0
    for pos in range(1, 39):
        if pos not in PARITY_POSITIONS:
            data |= corrected_bits[pos] << data_index
            data_index += 1

    return {
        "data": data,
        "corrected_codeword": corrected,
        "syndrome": syndrome,
        "single_error": single_error,
        "double_error": double_error,
        "uncorrectable_error": uncorrectable_error,
    }
