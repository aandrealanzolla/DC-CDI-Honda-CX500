#!/usr/bin/env python3
"""
Legge il dump binario del settore di log flash della CDI (128KB, a partire
da 0x08060000 sul micro) e lo esporta in CSV leggibile.

Come ottenere il dump binario, a motore fermo:
  - STM32CubeProgrammer (GUI o CLI): tab "Memory & File editing" -> connetti
    via ST-LINK -> Read -> indirizzo 0x08060000, dimensione 0x20000 (128KB)
    -> salva come .bin.
    Da riga di comando: STM32_Programmer_CLI -c port=SWD -r32 0x08060000 0x20000 dump.bin
  - Oppure, dalla Debugger Console di CubeIDE (GDB), a motore gia' fermo:
    dump binary memory dump.bin 0x08060000 0x08080000

Uso:
  python3 parse_log.py dump.bin [output.csv]

Se output.csv non e' specificato, stampa a schermo in formato tabellare.
"""
import struct
import sys

MAGIC = 0x31434431
RECORD_FMT = "<IIIHhBBH"   # t_ms, period_meas_us, period_used_us, rpm, advance10, cyl, branch, reserved
RECORD_SIZE = struct.calcsize(RECORD_FMT)
assert RECORD_SIZE == 20

BRANCH_NAMES = {0: "reattivo", 1: "predittivo", 2: "transizione"}
CYL_NAMES = {0: "L", 1: "R"}


def parse(path):
    with open(path, "rb") as f:
        data = f.read()

    if len(data) < 4:
        print("File troppo corto, non sembra un dump valido.", file=sys.stderr)
        sys.exit(1)

    (magic,) = struct.unpack_from("<I", data, 0)
    if magic != MAGIC:
        print(
            f"ATTENZIONE: magic non combacia (atteso 0x{MAGIC:08X}, trovato "
            f"0x{magic:08X}). O l'indirizzo di dump e' sbagliato, o il "
            f"settore non e' mai stato inizializzato da questo firmware.",
            file=sys.stderr,
        )

    records = []
    offset = 4
    while offset + RECORD_SIZE <= len(data):
        chunk = data[offset : offset + RECORD_SIZE]
        t_ms, period_meas_us, period_used_us, rpm, advance10, cyl, branch, _ = (
            struct.unpack(RECORD_FMT, chunk)
        )
        if t_ms == 0xFFFFFFFF:
            break  # prima voce ancora vergine: fine del log scritto finora
        records.append(
            {
                "idx": len(records),
                "t_ms": t_ms,
                "cyl": CYL_NAMES.get(cyl, f"?{cyl}"),
                "branch": BRANCH_NAMES.get(branch, f"?{branch}"),
                "rpm": rpm,
                "advance_deg": advance10 / 10.0,
                "period_meas_us": period_meas_us,
                "period_used_us": period_used_us,
            }
        )
        offset += RECORD_SIZE

    return records


def main():
    if len(sys.argv) < 2:
        print(f"Uso: {sys.argv[0]} dump.bin [output.csv]", file=sys.stderr)
        sys.exit(1)

    records = parse(sys.argv[1])
    print(f"Trovate {len(records)} voci.", file=sys.stderr)

    fields = ["idx", "t_ms", "cyl", "branch", "rpm", "advance_deg",
              "period_meas_us", "period_used_us"]

    if len(sys.argv) >= 3:
        import csv
        with open(sys.argv[2], "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fields)
            writer.writeheader()
            writer.writerows(records)
        print(f"Scritto {sys.argv[2]}", file=sys.stderr)
    else:
        header = " ".join(f"{h:>14}" for h in fields)
        print(header)
        for r in records:
            print(" ".join(f"{r[h]!s:>14}" for h in fields))


if __name__ == "__main__":
    main()