import re
import os
import sys

"""

A utility for crafting more legible 
Intel x86 assembly code.

Author: Lukas Bergström

"""

RED = '\033[31m'
GREEN = '\033[32m'
YELLOW = '\033[33m'
RESET = '\033[0m'

class TooManyArgumentException(Exception):
    def __init__(self, message):
        super().__init__(message)

class WrongFormatException(Exception):
    def __init__(self, message):
        super().__init__(message)

class Function():
    def __init__(self) -> None:
        self.name = ''
        self.inputs = {}
        self.vars = {}
        self.offset = 0
        self.frame = False
        self.firstFloatVar = True
        self.instructions = []

        # Don't create function that takes in more than this... 
        # values after this should be in reverse order on the stack
        # and i really don't want to implement that
        self.parameters_gp64 = ['rdi',   'rsi',  'rdx',  'rcx',   'r8',    'r9' ]
        self.parameters_gp32 = ['edi',   'esi',  'edx',  'ecx',   'r8d',   'r9d']
        self.parameters_gp16 = ['di',     'si',   'dx',   'cx',   'r8w',   'r9w']
        self.parameters_gp8  = ['dil',   'sil',   'dh',   'ch',   'r8b',   'r9b']
        self.parameters_fp = ['xmm0', 'xmm1', 'xmm2', 'xmm3', 'xmm4', 'xmm5']
        self.gp_index = 0
        self.fp_index = 0

    def reset(self, name: str) -> None:
        total_size: int = 0

        tmp = 0
        for tag in self.inputs.keys():
            if (not self.inputs[tag]["used"]):
                print(f'{YELLOW}[Warning]{RESET} Unused input \'{tag}\' in function \'{self.name}\'')
            if(self.inputs[tag]["size"] > tmp):
                tmp = self.inputs[tag]["size"]

        total_size += tmp
        tmp = 0
        for tag in self.vars.keys():
            if (not self.vars[tag]["used"]):
                print(f'{YELLOW}[Warning]{RESET} Unused variable \'{tag}\' in function \'{self.name}\'')
            if(self.vars[tag]["size"] > tmp):
                tmp = self.vars[tag]["size"]

        total_size += tmp 
        if(total_size > 0):
            self.instructions.insert(2, f'sub rsp, {total_size}')

        data = '\n'.join(self.instructions)
        self.instructions = []

        self.name = name
        self.inputs = {}
        self.vars = {}
        self.offset = 0
        self.frame = False
        self.gp_index = 0
        self.fp_index = 0
        self.firstFloatVar = True

        return data
        
    def isActive(self) -> bool:
        return self.name != ''

    def _get_type_size(self, type_str: str) -> int:
        return int(type_str[1:]) // 8
    
    def _convert_type(self, type: str) -> str:
        if (type == 'u8' or type == 'i8'):
            return 'byte'
        if (type == 'u16' or type == 'i16'):
            return 'word'
        if (type == 'u32' or type == 'i32' or type == 'f32'):
            return 'dword'
        if (type == 'u64' or type == 'i64' or type == 'f64'):
            return 'qword'
        
    def _convert_mov(self, type):
        if (type == 'f32'):
            return 'movss'
        if (type == 'f64'):
            return 'movsd'
        return 'mov'
    
    def _convert_calling(self, type):

        if(self.fp_index == len(self.parameters_fp) or self.gp_index == len(self.parameters_gp64)):
            raise TooManyArgumentException(f"Too many arguments for function {self.name}")

        if (type == 'f32' or type == 'f64'):
            reg = self.parameters_fp[self.fp_index]
            self.fp_index += 1
            return reg
        
        if (type == 'u8' or type == 'i8'):
            reg = self.parameters_gp8[self.gp_index]
        elif (type == 'u16' or type == 'i16'):
            reg = self.parameters_gp16[self.gp_index]
        elif (type == 'u32' or type == 'i32'):
            reg = self.parameters_gp32[self.gp_index]
        elif (type == 'u64' or type == 'i64'):
            reg = self.parameters_gp64[self.gp_index]
        
        self.gp_index += 1
        return reg
        
    def _generate_ref(self, tag) -> str:
        size = self.inputs[tag]['size']
        type = self._convert_type(self.inputs[tag]['type'])
        self.inputs[tag]['used'] = True
        return f'{type} [rbp-{size}]'

    def _find_ref(self, text: str) -> str:
        pattern1 = re.compile(r'§(.*?)(,|\s)')
        pattern2 = re.compile(r'§(.*?)$')
        match1 = pattern1.search(text)
        match2 = pattern2.search(text)

        if match1:
            word_to_replace = match1.group(0)
            tag = match1.group(1)
            return text.replace(f'{word_to_replace}', self._generate_ref(tag) + ',')
        elif match2:
            word_to_replace = match2.group(0)
            tag = match2.group(1)
            return text.replace(f'{word_to_replace}', self._generate_ref(tag))
        else:
            raise WrongFormatException(f"Wrong format: {text}")
    
    def parse_line(self, line: str):
        tokens = line.split()

        if tokens[0] == 'in' and '::' in line:
            """
            The 'in' keyword designates a specific 
            input parameter. The sequence in which 
            this is defined corresponds to the order 
            of the registers.

            Usage: in <type>::<name>
            """

            if not self.frame:
                self.instructions.append('push    rbp')
                self.instructions.append('mov     rbp, rsp')
                self.frame = True

            type = tokens[1].split('::')[0]
            name = tokens[1].split('::')[1]
            size = self._get_type_size(type) + self.offset
            self.offset = size
            self.inputs[name] = {"size": size, "type": type, "used": False}
            data = f"{self._convert_mov(type)} {self._convert_type(type)} [rbp-{size}], {self._convert_calling(type)}"
            self.instructions.append(data)
            return ''
        elif tokens[0] == 'init' and  '::' in line:
            """
            The 'init' keyword initializes the register 
            to zero.

            Usage: init <type>::<name>
            """

            if not self.frame:
                self.instructions.append('push    rbp')
                self.instructions.append('mov     rbp, rsp')
                self.frame = True
            type = tokens[1].split('::')[0]
            name = tokens[1].split('::')[1]
            size = self._get_type_size(type) + self.offset
            self.offset = size
            self.inputs[name] = {"size": size, "type": type, "used": False}

            if (type[0] == 'f' and self.firstFloatVar):
                self.firstFloatVar = False
                data = f"xorpd xmm7, xmm7\n{self._convert_mov(type)} {self._convert_type(type)} [rbp-{size}], xmm7"
                self.instructions.append(data)
                return ''
            elif (type[0] == 'f'):
                data = f"{self._convert_mov(type)} {self._convert_type(type)} [rbp-{size}], xmm7"
                self.instructions.append(data)
                return ''
            return f"{self._convert_mov(type)} {self._convert_type(type)} [rbp-{size}], 0"
        elif '::' in line:
            """
            A nameless definition reserves space for 
            the variable without generating any code.

            Usage: <type>::<name>        
            """

            if not self.frame:
                self.instructions.append('push    rbp')
                self.instructions.append('mov     rbp, rsp')
                self.frame = True

            type = tokens[0].split('::')[0]
            name = tokens[0].split('::')[1]
            size = self._get_type_size(type) + self.offset
            self.offset = size
            self.inputs[name] = {"size": size, "type": type, "used": False}
            return ''
        elif '§' in line:
            """
            Reference to a specified variable.

            Usage: §<name>      
            """
            self.instructions.append(self._find_ref(line))
            return ''
        self.instructions.append(line)
        return line
    

def translate_to_asm(asm_data: str) -> str:
    func = Function()
    data = ''
    for line in asm_data.split('\n'):
        line: str = line.split(';', 1)[0].strip()
        try:
            if(line == ''):
                continue
            tmp = func.parse_line(line)
            if(not func.isActive()):
                data += tmp + '\n'
        except TooManyArgumentException as e:
            print(f'{RED}[Error]{RESET} {e}')
            exit(100)
        except WrongFormatException as e:
            print(f'{RED}[Error]{RESET} {e}')
            exit(101)
        except KeyError as e:
            print(f'{RED}[Error]{RESET} Invalid variable reference {e}')
            exit(102)

        if (not func.isActive() and line.endswith(':')):
            func.reset(line[0:-1])
        if (func.isActive() and (line == 'ret' or line == 'leave')):
            data += func.reset('') + '\n\n'
    return data

def generate_file(fullpath: str):
    with open(fullpath, 'r') as file:
        return translate_to_asm(file.read())
    
def find_asm_files(directory: str) -> list:
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.asm'):
                yield os.path.join(root, file)

def main(directory = './gen') -> None:
    if not os.path.exists(directory):
        os.mkdir(directory)
        print(f"Creating Directory '{directory}'")
    else:
        print(f"Directory '{directory}' already exists")

    for fullpath in list(find_asm_files(sys.argv[1])):
        print(f'{GREEN}* {fullpath}{RESET}')
        data = generate_file(fullpath)
        basename = os.path.basename(fullpath)
        with open(f'{directory}/{basename}', 'w') as file:
            file.write(data)

if __name__ == '__main__':
    if(len(sys.argv) == 2):
        main()
        exit(0)
    if(len(sys.argv) == 3):
        main(sys.argv[2])
        exit(0)
    print(f"""
    Execution Instructions:

    Usage: Python3 {sys.argv[0]} <src-dir>
    or
    Usage: Python3 {sys.argv[0]} <src-dir> <target-dir>
    """)






