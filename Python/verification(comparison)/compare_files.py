#!/usr/bin/env python3
# =============================================================================
# Script  : compare_files.py
# Purpose : Compare write_data.txt vs read.txt bit-by-bit after simulation
# Usage   : python3 compare_files.py
# =============================================================================

def compare_ram_files(write_file="write_data.txt", read_file="read.txt"):
    print("=" * 60)
    print("  32KB RAM File Comparison Tool")
    print("=" * 60)

    # ------------------------------------------------------------------
    # Load both files
    # ------------------------------------------------------------------
    try:
        with open(write_file, "r") as f:
            write_lines = [line.strip() for line in f.readlines()]
    except FileNotFoundError:
        print(f"[ERROR] Cannot open {write_file}")
        return

    try:
        with open(read_file, "r") as f:
            read_lines = [line.strip() for line in f.readlines()]
    except FileNotFoundError:
        print(f"[ERROR] Cannot open {read_file}")
        return

    # ------------------------------------------------------------------
    # Validate lengths
    # ------------------------------------------------------------------
    if len(write_lines) != len(read_lines):
        print(f"[WARNING] Line count mismatch: write={len(write_lines)}, read={len(read_lines)}")

    total_bytes   = min(len(write_lines), len(read_lines))
    mismatch_list = []

    # ------------------------------------------------------------------
    # Byte-by-byte comparison
    # ------------------------------------------------------------------
    for i in range(total_bytes):
        w = write_lines[i]
        r = read_lines[i]
        if w != r:
            mismatch_list.append((i, w, r))

    # ------------------------------------------------------------------
    # Bit-level analysis for mismatched bytes
    # ------------------------------------------------------------------
    total_bit_errors = 0
    if mismatch_list:
        print(f"\n[FAIL] {len(mismatch_list)} byte mismatches found:\n")
        print(f"{'Addr (hex)':<12} {'Addr (dec)':<12} {'Written':<10} {'Read':<10} {'Bit Errors'}")
        print("-" * 58)
        for addr, w, r in mismatch_list[:50]:   # Show max 50
            bit_errors = sum(1 for a, b in zip(w, r) if a != b)
            total_bit_errors += bit_errors
            print(f"0x{addr:04X}      {addr:<12} {w:<10} {r:<10} {bit_errors}")
        if len(mismatch_list) > 50:
            print(f"  ... and {len(mismatch_list) - 50} more mismatches (truncated)")
    
    # ------------------------------------------------------------------
    # Summary
    # ------------------------------------------------------------------
    print("\n" + "=" * 60)
    if not mismatch_list:
        print(f"  RESULT : ✅ PASS — All {total_bytes} bytes match perfectly!")
        print(f"  Total bytes checked : {total_bytes}")
        print(f"  Total bits checked  : {total_bytes * 8}")
        print(f"  Mismatches          : 0")
    else:
        ber = total_bit_errors / (total_bytes * 8)
        print(f"  RESULT : ❌ FAIL")
        print(f"  Total bytes checked : {total_bytes}")
        print(f"  Byte mismatches     : {len(mismatch_list)}")
        print(f"  Bit errors          : {total_bit_errors}")
        print(f"  Bit Error Rate (BER): {ber:.2e}")
    print("=" * 60)

if __name__ == "__main__":
    compare_ram_files()
