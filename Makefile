ASM=nasm
SRC_DIR=src
BUILD_DIR=build
EMU=qemu-system-i386

all: ./$(BUILD_DIR)/main_floppy.img
	$(EMU) -machine q35 -fda ./$(BUILD_DIR)/main_floppy.img 

./$(BUILD_DIR)/main_floppy.img: ./$(BUILD_DIR)/bootloader.bin
	cp $? ./$(BUILD_DIR)/main_floppy.img
	truncate -s 1440k $^

./$(BUILD_DIR)/bootloader.bin: ./$(SRC_DIR)/bootloader.asm
	$(ASM)  ./$(SRC_DIR)/bootloader.asm -o ./$(BUILD_DIR)/bootloader.bin
clean:
	rm  $(BUILD_DIR)/*

edit:
	nvim $(SRC_DIR)/bootloader.asm

debug:
	$(EMU) -machine q35 -fda ./$(BUILD_DIR)/main_floppy.img -gdb tcp::26000 -S
