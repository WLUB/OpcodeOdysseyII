import struct

"""
A utility for inspecting register value.
Author: Lukas Bergström
"""

def interpret_xmm(value):
    hex_values = value.strip("{}").split()
    
    # Convert to float (first 4 bytes)
    hex_string_float = ''.join([h[2:] for h in hex_values[:4]])
    byte_data_float = bytes.fromhex(hex_string_float)
    float_val = struct.unpack('<f', byte_data_float)[0]
    
    # Convert to double (first 8 bytes)
    hex_string_double = ''.join([h[2:] for h in hex_values[:8]])
    byte_data_double = bytes.fromhex(hex_string_double)
    double_val = struct.unpack('<d', byte_data_double)[0]
    
    print(f"32-bit float:  {float_val}")
    print(f"64-bit double: {double_val}\n")

def interpret_gpr(value):
    hex_val = int(value, 16)
    print(f"Value of GPR in decimal: {hex_val}\n")
    

def main():
    while True:
        print("Enter the register value (or 'exit' to quit) ")
        value = input("$ ").strip()
        try:
            if value.lower() == 'exit':
                break

            if "xmm" in value:
                _, xmm_val = value.split("=", 1)
                interpret_xmm(xmm_val.strip())
            elif "r" in value:
                _, gpr_val = value.split("=", 1)
                interpret_gpr(gpr_val.strip())
            else:
                print("Invalid format. Please try again.\n")
        except:
            print("Invalid command")

if __name__ == "__main__":
    main()
