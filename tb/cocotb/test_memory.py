import random

import cocotb
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

    dut._log.info(
        "PASS: 256 initial writes, 256 shuffled reads, "
        "1000 randomized operations"
    )
