#!/usr/bin/env python3
# =============================================================================
# Script  : uart_host.py
# Purpose : Send write_data.txt to FPGA over UART, receive read-back bytes,
#           save as read.txt, compare both files, print PASS/FAIL report.
#
# Usage   : python3 uart_host.py [--port PORT] [--write write_data.txt]
# Requires: pip install pyserial
#
# Flow:
#   1. Parse write_data.txt → list of 32768 raw bytes
#   2. Open UART port at 115200 baud
#   3. Stream all 32768 bytes to FPGA
#   4. Receive 32768 bytes back + 1 result byte ('P' or 'F')
#   5. Save received bytes to read.txt (binary format matching write_data.txt)
#   6. Compare and print full report
# =============================================================================

import serial
import serial.tools.list_ports
import argparse
import time
import sys
import os

# =============================================================================
# Configuration
# =============================================================================
BAUD_RATE   = 115200
MEM_DEPTH   = 32768         # 32 KB
WRITE_FILE  = "write_data.txt"
READ_FILE   = "read.txt"
CHUNK_SIZE  = 256           # Bytes per write chunk (flow control)
RX_TIMEOUT  = 30            # Seconds to wait for all bytes back

# =============================================================================
# Helper: list available serial ports
# =============================================================================
def list_ports():
    ports = serial.tools.list_ports.comports()
    if not ports:
        print("  No serial ports found.")
    for p in ports:
        print(f"  {p.device:20s} — {p.description}")

# =============================================================================
# Helper: load write_data.txt → list of ints [0..255]
# =============================================================================
def load_write_data(path):
    print(f"[HOST] Loading {path} ...")
    if not os.path.exists(path):
        print(f"[ERROR] {path} not found!")
        sys.exit(1)

    with open(path, "r") as f:
        lines = [l.strip() for l in f.readlines() if l.strip()]

    if len(lines) != MEM_DEPTH:
        print(f"[ERROR] Expected {MEM_DEPTH} lines, got {len(lines)}")
        sys.exit(1)

    data = []
    for i, line in enumerate(lines):
        if len(line) != 8 or not all(c in '01' for c in line):
            print(f"[ERROR] Bad binary string at line {i}: '{line}'")
            sys.exit(1)
        data.append(int(line, 2))

    print(f"[HOST] Loaded {len(data)} bytes OK.")
    print(f"[HOST] First 4: {[f'{b:08b}' for b in data[:4]]}")
    return data

# =============================================================================
# Helper: save read-back bytes → read.txt (same format as write_data.txt)
# =============================================================================
def save_read_data(path, data):
    print(f"[HOST] Saving {path} ...")
    with open(path, "w") as f:
        for b in data:
            f.write(f"{b:08b}\n")
    print(f"[HOST] Saved {len(data)} bytes to {path}")

# =============================================================================
# Helper: compare write_data vs read_data, print report
# =============================================================================
def compare(write_data, read_data):
    print("[HOST] Comparing ...")
    mismatches = []
    for i, (w, r) in enumerate(zip(write_data, read_data)):
        if w != r:
            mismatches.append((i, w, r))

    print("=" * 60)
    if not mismatches:
        print(f"  RESULT : ✅ PASS — All {MEM_DEPTH} bytes matched!")
        print(f"  Total bits verified : {MEM_DEPTH * 8:,}")
    else:
        total_bit_errors = sum(
            bin(w ^ r).count('1') for _, w, r in mismatches
        )
        ber = total_bit_errors / (MEM_DEPTH * 8)
        print(f"  RESULT : ❌ FAIL — {len(mismatches)} byte mismatches")
        print(f"  Bit errors          : {total_bit_errors}")
        print(f"  Bit Error Rate (BER): {ber:.2e}")
        print()
        print(f"  {'Addr':>8}  {'Written':>10}  {'Read':>10}  {'XOR':>10}")
        print(f"  {'-'*50}")
        for addr, w, r in mismatches[:30]:
            print(f"  0x{addr:04X}    {w:08b}    {r:08b}    {w^r:08b}")
        if len(mismatches) > 30:
            print(f"  ... and {len(mismatches)-30} more (truncated)")
    print("=" * 60)
    return len(mismatches) == 0

# =============================================================================
# Main
# =============================================================================
def main():
    parser = argparse.ArgumentParser(description="UART RAM tester — send/receive 32KB")
    parser.add_argument("--port",  default=None,       help="Serial port (e.g. COM3 or /dev/ttyUSB1)")
    parser.add_argument("--write", default=WRITE_FILE, help="Write data file (default: write_data.txt)")
    parser.add_argument("--read",  default=READ_FILE,  help="Read output file (default: read.txt)")
    args = parser.parse_args()

    # ------------------------------------------------------------------
    # Step 1: Auto-detect port if not specified
    # ------------------------------------------------------------------
    port = args.port
    if port is None:
        ports = serial.tools.list_ports.comports()
        # Try to auto-select FT2232H (Arty A7 USB-UART)
        ft_ports = [p for p in ports if "FT2232" in (p.description or "") or
                                        "Digilent" in (p.description or "")]
        if ft_ports:
            port = ft_ports[0].device
            print(f"[HOST] Auto-detected Arty A7 UART: {port}")
        elif ports:
            port = ports[0].device
            print(f"[HOST] Using first available port: {port}")
        else:
            print("[ERROR] No serial port found. Available ports:")
            list_ports()
            print("\nUsage: python3 uart_host.py --port COM3")
            sys.exit(1)

    # ------------------------------------------------------------------
    # Step 2: Load write data
    # ------------------------------------------------------------------
    write_data = load_write_data(args.write)

    # ------------------------------------------------------------------
    # Step 3: Open UART
    # ------------------------------------------------------------------
    print(f"[HOST] Opening {port} at {BAUD_RATE} baud ...")
    try:
        ser = serial.Serial(
            port     = port,
            baudrate = BAUD_RATE,
            bytesize = serial.EIGHTBITS,
            parity   = serial.PARITY_NONE,
            stopbits = serial.STOPBITS_ONE,
            timeout  = RX_TIMEOUT
        )
    except serial.SerialException as e:
        print(f"[ERROR] Cannot open port: {e}")
        sys.exit(1)

    # Clear any stale data
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    time.sleep(0.1)

    # ------------------------------------------------------------------
    # Step 4: Send all 32768 bytes in chunks
    # ------------------------------------------------------------------
    print(f"[HOST] Sending {MEM_DEPTH} bytes to FPGA ...")
    raw_bytes = bytes(write_data)
    sent      = 0
    t_start   = time.time()

    while sent < MEM_DEPTH:
        chunk = raw_bytes[sent : sent + CHUNK_SIZE]
        ser.write(chunk)
        sent += len(chunk)
        pct   = sent * 100 // MEM_DEPTH
        # Progress bar
        bar = "#" * (pct // 5) + "-" * (20 - pct // 5)
        print(f"\r  [{bar}] {pct:3d}%  {sent:5d}/{MEM_DEPTH}", end="", flush=True)
        # Small inter-chunk gap to avoid FPGA RX FIFO overflow
        # At 115200 baud, 256 bytes takes ~22 ms — give FPGA 1ms extra breathing room
        time.sleep(0.001)

    t_tx = time.time() - t_start
    print(f"\n[HOST] Sent {sent} bytes in {t_tx:.2f}s ({sent/t_tx:.0f} bytes/s)")

    # ------------------------------------------------------------------
    # Step 5: Receive 32768 read-back bytes + 1 result byte
    # ------------------------------------------------------------------
    print(f"[HOST] Waiting for {MEM_DEPTH + 1} bytes from FPGA ...")
    received = bytearray()
    t_start  = time.time()

    while len(received) < MEM_DEPTH + 1:
        chunk = ser.read(MEM_DEPTH + 1 - len(received))
        if not chunk:
            elapsed = time.time() - t_start
            print(f"\n[ERROR] Timeout! Only received {len(received)} bytes after {elapsed:.1f}s")
            ser.close()
            sys.exit(1)
        received.extend(chunk)
        pct = min(len(received), MEM_DEPTH) * 100 // MEM_DEPTH
        bar = "#" * (pct // 5) + "-" * (20 - pct // 5)
        print(f"\r  [{bar}] {pct:3d}%  {min(len(received),MEM_DEPTH):5d}/{MEM_DEPTH}", end="", flush=True)

    t_rx = time.time() - t_start
    print(f"\n[HOST] Received {len(received)} bytes in {t_rx:.2f}s")
    ser.close()

    # ------------------------------------------------------------------
    # Step 6: Split read-back data and result byte
    # ------------------------------------------------------------------
    read_data   = list(received[:MEM_DEPTH])
    result_byte = received[MEM_DEPTH]
    fpga_result = "PASS" if result_byte == ord('P') else "FAIL"
    print(f"[HOST] FPGA reports: {fpga_result} (0x{result_byte:02X} = '{chr(result_byte)}')")

    # ------------------------------------------------------------------
    # Step 7: Save read.txt
    # ------------------------------------------------------------------
    save_read_data(args.read, read_data)

    # ------------------------------------------------------------------
    # Step 8: Compare
    # ------------------------------------------------------------------
    host_pass = compare(write_data, read_data)

    # Sanity check: FPGA result should match host comparison
    if host_pass != (fpga_result == "PASS"):
        print("[WARNING] FPGA result and host comparison disagree — check UART integrity")

# =============================================================================
if __name__ == "__main__":
    main()
