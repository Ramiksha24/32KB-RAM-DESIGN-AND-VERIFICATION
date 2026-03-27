# 32KB RAM on FPGA: From Simulation to System-Level Verification

> Designing, verifying, and implementing a **32KB RAM system** using Verilog with both **file-driven simulation** and **hardware validation (LFSR + UART)**.

---

##  Overview

This project implements a complete **32KB RAM (32768 × 8-bit)** and validates it across multiple levels:

- Simulation using file-based verification  
- FPGA-based **self-checking validation (LFSR)**  
- UART-based **external system validation (PC ↔ FPGA)**  

---

## 🏗️ Architecture Variants

### 🔹 LFSR-Based (Internal Self-Test)

- Uses **16-bit LFSR** to generate pseudo-random data  
- Writes data to:
  - Main RAM (DUT)  
  - Shadow memory (reference model)  
- Compares internally on FPGA  
- No external input required  

✔ Result:
- PASS → LED ON  
- FAIL → LED BLINK  

---

### 🔹 UART-Based (External Interface)

- Data sent from **PC → FPGA via UART**  
- FPGA writes incoming data into RAM  
- Data read back and transmitted to PC  
- Python script performs verification  

✔ Enables:
- Real-time testing  
- Flexible input patterns  
- System-level validation  

---

## Motivation

Memory seems simple… until you actually verify it.

> Did every byte really get written correctly?  
> Did it come back exactly the same?

This project validates **all 32,768 bytes (262,144 bits)**:

- In **simulation (file-based)**  
- In **hardware (self-checking logic)**  
- Over **real communication interface (UART)**  

---

## Tech Stack

- **Language:** Verilog HDL  
- **Tools:** Xilinx Vivado  
- **Simulation:** File-driven Testbench  
- **Validation:** Python (`compare_files.py`, UART host)  
- **Hardware:** Artix-7 FPGA  

---

## Project Structure

```
FPGA/
├── LFSR/
│   ├── Code/
│   │   ├── RAM_32KB.v
│   │   ├── Top.v
│   │   └── ram_controller.v
│   └── Output/
│       ├── Pass_LED.jpeg
│       ├── SETUP.jpeg
│       └── vio_output.png
│
├── UART/
│   ├── Code/
│   │   ├── RAM_Controller_2.v
│   │   ├── Top2.v
│   │   ├── uart_rx.v
│   │   └── uart_tx.v
│   └── Output/
│       └── vio_output_uart.png
│
Python/
├── UART/
│   ├── uart_host.py
│   ├── write_data.txt
│   └── read.txt
│
verification(comparison)/
├── compare_files.py
│
Simulation/
├── Output/
│   ├── Tb_tcl_console.png
│   ├── write_data.png
│   ├── read_data.png
│   ├── comparison_output.png
│   └── uart_verification_python.png
```

---

## Simulation Verification Flow

1. Load data from `write_data.txt`  
2. Write all 32KB into RAM  
3. Read back data  
4. Store output in `read.txt`  
5. Compare using Python script  

Result: **PASS / FAIL**

---

## Hardware Verification (LFSR Mode)

### Data Generation
- Internal **LFSR generator**
- Deterministic pseudo-random sequence  

---

### Write Phase
- Writes to RAM + shadow memory  

---

###  Read Phase
- Accounts for **1-cycle BRAM latency**  

---

###  Compare Phase
- Compares RAM vs shadow memory  

---

###  Output
- PASS → LED ON  
- FAIL → LED BLINK  

---

## 🔌 UART-Based Verification Flow

### FPGA Side

1. Receive data via `uart_rx`  
2. Write data into RAM  
3. Read back data  
4. Transmit via `uart_tx`  

---

### Python Host

1. Load `write_data.txt`  
2. Send data over UART  
3. Receive FPGA output  
4. Save as `read.txt`  
5. Compare with original  

---

### Output

- PASS → All bytes match  
- FAIL → Mismatch detected  
- Optional: Bit Error Rate (BER)  

---

## Results

### Simulation Output

![Simulation Console](Simulation/Output/Tb_tcl_console.png)

---

### Write Data

![Write Data](Simulation/Output/write_data.png)

---

### Read Data

![Read Data](Simulation/Output/read_data.png)

---

### Comparison Output

![Comparison](Simulation/Output/comparison_output.png)

---

### UART Verification

![UART Verification](Simulation/Output/uart_verification_python.png)

---

## FPGA Implementation

### Hardware Setup

![Setup](FPGA/LFSR/Output/SETUP.jpeg)

---

### PASS Indication

![Pass LED](FPGA/LFSR/Output/Pass_LED.jpeg)

---

### VIO Debug Output

![VIO Output](FPGA/LFSR/Output/vio_output.png)

---

##  How to Run

### Simulation

1. Open project in Vivado  
2. Add RTL + Testbench  
3. Run simulation  
4. Execute `compare_files.py`  

---

### FPGA (LFSR Mode)

1. Generate bitstream  
2. Program FPGA  
3. Press reset  
4. Observe LED status  

---

### UART Mode

1. Program FPGA  
2. Run `uart_host.py`  
3. Send data  
4. Receive and compare output  

---

## Challenges

- File I/O in simulation  
- Handling BRAM latency  
- UART timing synchronization  
- Data alignment between FPGA and Python  
- Debugging mismatches across 32K entries  

---

## Future Improvements

- AXI interface integration  
- Dual-port RAM  
- Burst transactions  
- CRC/error detection over UART  
- Real-time debug console  

---

##  Why This Project Stands Out

Most RAM projects stop at simulation.

This project:

- Verifies memory in **simulation + FPGA + UART**  
- Implements **self-checking architecture (BIST-like)**  
- Integrates **hardware + software validation**  

> This is not just RTL — this is **design + verification + system-level validation**

---

## Author

**Ramiksha Shetty**

---
