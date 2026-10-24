import random

import cocotb
from ecc_reference import encode, decode
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer


@cocotb.test()
async def randomized_memory_test(dut):
    rng = random.Random(20261023)
    reference = {}

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.rst_n.value = 0
    dut.req_valid.value = 0
    dut.req_write.value = 0
    dut.addr.value = 0
    dut.wdata.value = 0

    for _ in range(3):
        await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.rst_n.value = 1

    async def transact(write, address, data=0):
        await FallingEdge(dut.clk)

        dut.req_valid.value = 1
        dut.req_write.value = int(write)
        dut.addr.value = address
        dut.wdata.value = data

        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

        assert int(dut.rsp_valid.value) == 1, (
            f"Missing response: write={write}, address={address}"
        )

        if write:
            reference[address] = data
        else:
            expected = reference.get(address, 0)
            actual = int(dut.rdata.value)

            assert actual == expected, (
                f"Read mismatch at address {address}: "
                f"expected=0x{expected:08X}, actual=0x{actual:08X}"
            )

            assert int(dut.double_error.value) == 0, (
                f"Unexpected double-error flag at address {address}"
            )

            assert int(dut.uncorrectable_error.value) == 0, (
                f"Unexpected uncorrectable-error flag at address {address}"
            )

        await FallingEdge(dut.clk)
        dut.req_valid.value = 0
        dut.req_write.value = 0

    # Write every address with deterministic randomized data.
    for address in range(256):
        data = rng.getrandbits(32)
        await transact(True, address, data)

    # Read every address in a shuffled order.
    addresses = list(range(256))
    rng.shuffle(addresses)

    for address in addresses:
        await transact(False, address)

    # Mixed randomized traffic, including repeated addresses.
    for _ in range(1000):
        address = rng.randrange(256)
        write = rng.random() < 0.55

        if write:
            await transact(True, address, rng.getrandbits(32))
        else:
            await transact(False, address)

    # Fault injection: flip one bit in a stored ECC codeword.
    fault_addr = 10
    expected_data = reference[fault_addr]
    original_codeword = int(dut.mem[fault_addr].value)

    dut.mem[fault_addr].value = original_codeword ^ (1 << 5)

    await transact(False, fault_addr)

    assert int(dut.rdata.value) == expected_data, (
        "Single-bit fault: incorrect data returned"
    )
    assert int(dut.single_error.value) == 1, (
        "Single-bit fault was not flagged"
    )
    dut._log.info("PASS: single-bit fault corrected on read")

    # Allow the background scrubber time to scan and repair the word.
    timeout = 0
    while int(dut.mem[fault_addr].value) != original_codeword and timeout < 1000:
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        timeout += 1

    assert int(dut.mem[fault_addr].value) == original_codeword, (
        "Background scrubber did not repair the stored codeword"
    )
    dut._log.info("PASS: background scrubber repaired stored codeword")

    # Inject two bit errors and verify detection without correction.
    dut.mem[fault_addr].value = original_codeword ^ (1 << 5) ^ (1 << 8)

    # Perform this read directly: the generic helper expects clean data
    # and no error flags, which is inappropriate for an injected fault.
    await FallingEdge(dut.clk)
    dut.req_valid.value = 1
    dut.req_write.value = 0
    dut.addr.value = fault_addr

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")

    assert int(dut.rsp_valid.value) == 1, (
        "Missing response for double-bit fault read"
    )
    assert int(dut.double_error.value) == 1, (
        "Double-bit fault was not detected"
    )
    assert int(dut.single_error.value) == 0, (
        "Double-bit fault was incorrectly classified as single-bit"
    )
    assert int(dut.uncorrectable_error.value) == 0, (
        "Double-bit fault unexpectedly raised uncorrectable_error"
    )

    await FallingEdge(dut.clk)
    dut.req_valid.value = 0
    dut.req_write.value = 0

    dut._log.info("PASS: double-bit fault detected")

    dut._log.info(
        "PASS: 256 initial writes, 256 shuffled reads, "
        "1000 randomized operations, and fault-injection checks"
    )


@cocotb.test()
async def systematic_ecc_fault_test(dut):
    """Check all single-bit and double-bit faults against the Python model."""
    data = 0xDEADBEEF
    address = 10
    clean_codeword = encode(data)

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.rst_n.value = 0
    dut.req_valid.value = 0
    dut.req_write.value = 0
    dut.addr.value = 0
    dut.wdata.value = 0

    for _ in range(3):
        await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.rst_n.value = 1

    # Initialize a valid word through the public memory interface.
    await FallingEdge(dut.clk)
    dut.req_valid.value = 1
    dut.req_write.value = 1
    dut.addr.value = address
    dut.wdata.value = data

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert int(dut.rsp_valid.value) == 1

    async def read_injected_codeword(injected, expected):
        # Keep a request active while the corrupted word is sampled so
        # the background scrubber does not modify it before the read.
        await FallingEdge(dut.clk)
        dut.mem[address].value = injected
        dut.req_valid.value = 1
        dut.req_write.value = 0
        dut.addr.value = address

        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

        assert int(dut.rsp_valid.value) == 1
        assert int(dut.single_error.value) == int(expected["single_error"]), (
            f"single_error mismatch for codeword 0x{injected:010X}"
        )
        assert int(dut.double_error.value) == int(expected["double_error"]), (
            f"double_error mismatch for codeword 0x{injected:010X}"
        )
        assert int(dut.uncorrectable_error.value) == int(
            expected["uncorrectable_error"]
        ), f"uncorrectable_error mismatch for codeword 0x{injected:010X}"

        if expected["single_error"]:
            assert int(dut.rdata.value) == data, (
                f"Single-bit correction returned wrong data for "
                f"codeword 0x{injected:010X}"
            )

        await FallingEdge(dut.clk)
        dut.req_valid.value = 0
        dut.req_write.value = 0

    single_cases = 0
    double_cases = 0

    for bit in range(39):
        injected = clean_codeword ^ (1 << bit)
        expected = decode(injected)

        assert expected["data"] == data
        assert expected["single_error"]

        await read_injected_codeword(injected, expected)
        single_cases += 1

    for bit_a in range(39):
        for bit_b in range(bit_a + 1, 39):
            injected = clean_codeword ^ (1 << bit_a) ^ (1 << bit_b)
            expected = decode(injected)

            assert expected["double_error"]
            assert not expected["single_error"]

            await read_injected_codeword(injected, expected)
            double_cases += 1

    # Restore a clean codeword through a normal write.
    await FallingEdge(dut.clk)
    dut.req_valid.value = 1
    dut.req_write.value = 1
    dut.addr.value = address
    dut.wdata.value = data

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert int(dut.rsp_valid.value) == 1

    await FallingEdge(dut.clk)
    dut.req_valid.value = 0
    dut.req_write.value = 0

    assert single_cases == 39
    assert double_cases == 741

    dut._log.info(
        f"PASS: {single_cases} single-bit and "
        f"{double_cases} double-bit RTL fault cases"
    )
