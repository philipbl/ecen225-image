.PHONY: help download extract mount-image unmount-image modify-image build clean

# Colors for output
YELLOW := \033[0;33m
GREEN := \033[0;32m
NC := \033[0m # No Color

# Image settings
DOWNLOAD_DIR := downloads
TEMP_DIR := temp
OUTPUT_DIR := dist
IMAGE_NAME := ecen225-rpi-os
DOWNLOAD_URL := https://downloads.raspberrypi.org/raspios_lite_arm64/images
WORK_DIR := $(TEMP_DIR)/image_work

help:
	@echo "$(YELLOW)Raspberry Pi OS Image Builder$(NC)"
	@echo ""
	@echo "Available targets:"
	@echo "  make build           - Build the complete image (download, extract, grow, modify, compress)"
	@echo "  make download        - Download latest Raspberry Pi OS"
	@echo "  make extract         - Extract the downloaded image"
	@echo "  make grow-image      - Grow image size (adds 1GB by default)"
	@echo "  make modify-image    - Mount and modify the image (add user, etc.)"
	@echo "  make clean           - Clean all build artifacts"
	@echo "  make help            - Show this help message"

# Create necessary directories
$(DOWNLOAD_DIR) $(TEMP_DIR) $(OUTPUT_DIR):
	mkdir -p $@

# Download the latest Raspberry Pi OS Lite (ARM64)
download: | $(DOWNLOAD_DIR)
	@echo "$(YELLOW)Downloading latest Raspberry Pi OS Lite ARM64...$(NC)"
	@bash scripts/download_rpi_os.sh $(DOWNLOAD_DIR)

# Extract the downloaded image
extract: | $(TEMP_DIR)
	@echo "$(YELLOW)Extracting image...$(NC)"
	@bash scripts/extract_image.sh $(DOWNLOAD_DIR) $(TEMP_DIR)

# Grow the image size to provide more space for packages
grow-image: extract
	@echo "$(YELLOW)Growing image size...$(NC)"
	@sudo bash scripts/grow_image.sh $(TEMP_DIR) 1024

# Mount and modify the image
modify-image: grow-image
	@echo "$(YELLOW)Modifying image...$(NC)"
	@bash scripts/modify_image.sh $(TEMP_DIR)

# Build the complete modified image
build: | $(OUTPUT_DIR)
	@echo "$(YELLOW)Starting build process...$(NC)"
	@$(MAKE) download
	@$(MAKE) modify-image
	@echo "$(YELLOW)Packaging final image...$(NC)"
	@bash scripts/package_image.sh $(TEMP_DIR) $(OUTPUT_DIR) $(IMAGE_NAME)
	@echo "$(GREEN)Build complete! Compressed image saved to $(OUTPUT_DIR)/$(IMAGE_NAME).img.xz$(NC)"

# Clean up all build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	rm -rf $(TEMP_DIR) $(DOWNLOAD_DIR) $(OUTPUT_DIR)
	@echo "$(GREEN)Clean complete!$(NC)"

.DEFAULT_GOAL := help
