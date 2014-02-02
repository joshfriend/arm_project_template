#==============================================================================
#     Project properties
#==============================================================================

# Project name
PROJECT_NAME = main

# Project executable target
EXE = build/$(PROJECT_NAME).axf

# Collect source files
AS_SRC := $(shell find . -type f -name '*.s')
C_SRC := $(shell find . -type f -name '*.c')
CXX_SRC := $(shell find . -type f -name '*.cpp')

# Get location of compiled objects
AS_OBJ := $(AS_SRC:./%.s=%.o)
C_OBJ := $(C_SRC:./%.c=%.o)
CXX_OBJ := $(CXX_SRC:./%.cpp=%.o)

# Combine object file lists
OBJS=$(C_OBJ) $(AS_OBJ) $(CXX_OBJ)

# Set build artifacts
ARTIFACTS = build/${PROJECT_NAME}.axf \
            build/${PROJECT_NAME}.bin \
            build/${PROJECT_NAME}.lst \
            build/${PROJECT_NAME}.size \
            build/$(PROJECT_NAME).map

#==============================================================================
#     Target properties
#==============================================================================

# Microcontroller properties.
PART=LM4F120H5QR
CPU=-mcpu=cortex-m4
FPU=-mfpu=fpv4-sp-d16 -mfloat-abi=softfp

# Linker file name
LINKER_FILE = $(PART).ld

#==============================================================================
#     Toolchain settings
#==============================================================================

# Toolchain executables
PREFIX_ARM = arm-none-eabi
AR   = ${PREFIX_ARM}-ar
AS   = ${PREFIX_ARM}-as
CC   = ${PREFIX_ARM}-gcc
CP   = ${PREFIX_ARM}-objcopy
CPP  = ${PREFIX_ARM}-cpp
CXX  = ${PREFIX_ARM}-g++
GDB  = ${PREFIX_ARM}-gdb
LD   = ${PREFIX_ARM}-ld
NM   = ${PREFIX_ARM}-nm
OD   = ${PREFIX_ARM}-objdump
SIZE = ${PREFIX_ARM}-size

# Paths to TI libraries
STELLARISWARE = /Developer/stellarisware
TIVIAWARE     = /Developer/tiviaware

# Choose which library path to use (Tivia/Stellaris)
TI_INCLUDE_PATH = $(STELLARISWARE)

# libdriver file for Stellarisware on Cortex M3
LIBDRIVER_FILE=driverlib/gcc-cm4f/libdriver-cm4f.a

# libdriver file for Stellarisware on Cortex M4F
# LIBDRIVER_FILE=driverlib/gcc-cm3/libdriver-cm3.a

# libdriver file for Tiviaware on Cortex M4
# LIBDRIVER_FILE=driverlib/gcc/libdriver.a

# Define symbols
DEFS = -DPART_$(PART) \
       -DTARGET_IS_BLIZZARD_RA1

# Include paths
INCS = -I$(TI_INCLUDE_PATH)

# Options for assembler.
ASFLAGS=

# Arguments for C compiler.
CFLAGS=-mthumb ${CPU} ${FPU} -O3 -std=c99 -Wall -c -g -MD ${INCS} $(DEFS)

# Arguments for C++ compiler
CXXFLAGS=-mthumb ${CPU} ${FPU} -O3 -Wall -c -g -MD ${INCS} $(DEFS)

# Flags for linker
LFLAGS = --gc-sections --entry reset_handler -Map build/$(PROJECT_NAME).map

# Get the path to libgcc, libc.a and libm.a for linking
LIB_GCC_PATH=${shell ${CC} ${CFLAGS} -print-libgcc-file-name}
LIBC_PATH=${shell ${CC} ${CFLAGS} -print-file-name=libc.a}
LIBM_PATH=${shell ${CC} ${CFLAGS} -print-file-name=libm.a}

# Get path to Stellaris/Tivia library
LIBDRIVER_PATH=${TI_INCLUDE_PATH}/$(LIBDRIVER_FILE)

# List of all libraries to link
LIBS = $(LIBM_PATH) $(LIBC_PATH) $(LIB_GCC_PATH)

# Flags for objcopy
CPFLAGS = -Obinary

# Flags for objdump
ODFLAGS = -S

# Programmer tool path
FLASHER=lm4flash
# Flags for the programmer tool.
FLASHER_FLAGS=

#==============================================================================
#    Make rules
#==============================================================================

all: $(ARTIFACTS) $(DEPENDENCIES)

# Include autogenerated depend files
-include $(AS_SRC:.s=.d)
-include $(C_SRC:.c=.d)
-include $(CXX_SRC:.cpp=.d)

# Compile assembly files
%.o: %.s
	@echo "AS " $<
	@$(AS) -c $(ASFLAGS) $< -o $@

# Compile C files
%.o: %.c
	@echo "CC " $@
	@$(CC) -c $(CFLAGS) $< -o $@

# Compile C++ files
%.o: %.cpp
	@echo CXX $<
	@$(CXX) -c $(CXXFLAGS) $< -o $@

# Transform .axf to .bin for flasher util
%.bin: %.axf
	@mkdir -p $(dir $@)
	@echo "CP " $< "->" $@
	@$(CP) $(CPFLAGS) $< $@

# Make assembly listing from executable
%.lst: %.axf
	@mkdir -p $(dir $@)
	@echo "OD " $@
	@$(OD) $(ODFLAGS) $< > $@

# Calculate code size
%.size: %.axf
	@mkdir -p $(dir $@)
	@echo
	@echo Code size:
	@$(SIZE) $< | tee $@

# TI Stellaris/Tivia library
${LIBDRIVER_PATH}:
	@echo Making driverlib...
	make -C $(DRIVERLIB_PATH)

# Project executable
$(EXE): $(OBJS) $(LIBDRIVER_PATH)
	@mkdir -p $(dir $@)
	@echo "LD " $@
	@$(LD) -T linker/$(LINKER_FILE) $(LFLAGS) -o $@ $^ $(LIBS)

# Clean compiled files
.PHONY: clean
clean:
	@echo Removing compiled files...
	@rm -r build
	@find . -name \*.elf | xargs rm
	@find . -name \*.axf | xargs rm
	@find . -name \*.bin | xargs rm
	@find . -name \*.hex | xargs rm
	@find . -name \*.lst | xargs rm
	@find . -name \*.out | xargs rm
	@find . -name \*.map | xargs rm
	@find . -name \*.size | xargs rm
	@find . -name \*.d | xargs rm
	@find . -name \*.o | xargs rm
	@find . -name \*.i | xargs rm

# Flash the target
.PHONY: flash
flash: build/${PROJECT_NAME}.bin
	@echo Flashing...
	${FLASHER} $< ${FLASHER_FLAGS}

# Create GDB initilization file
.gdbinit: $(EXE)
	@echo file $(EXE) > .gdbinit
	@echo target remote localhost:7777 >> .gdbinit
	@echo monitor reset halt >> .gdbinit
	@echo load >> .gdbinit

# Run a debug session
.PHONY: debug
debug: all .gdbinit
	@echo Starting debug server...
	@killall lmicdi
	@lmicdi &
	@echo Opening GDB...
	@$(GDB)
	@echo Killing debug server...
	@killall lmicdi
