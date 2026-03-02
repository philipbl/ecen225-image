.PHONY: help download extract mount-image unmount-image modify-image build clean

# Colors for output
YELLOW := \033[0;33m
GREEN := \033[0;32m
NC := \033[0m # No Color

# Image settings
DOWNLOAD_DIR := downloads
BUILD_DIR := build
OUTPUT_DIR := dist
IMAGE_NAME := ecen225-rpi-os
DOWNLOAD_URL := https://downloads.raspberrypi.org/raspios_lite_arm64/images
WORK_DIR := $(BUILD_DIR)/image_work

help:
	@echo "$(YELLOW)Raspberry Pi OS Image Builder$(NC)"
	@echo ""
	@echo "Available targets:"
	@echo "  make build           - Build the complete image (download, extract, modify, package)"
	@echo "  make download        - Download latest Raspberry Pi OS"
	@echo "  make extract         - Extract the downloaded image"
	@echo "  make modify-image    - Mount and modify the image (add user, etc.)"
	@echo "  make clean           - Clean all build artifacts"
	@echo "  make help            - Show this help message"

# Create necessary directories
$(DOWNLOAD_DIR) $(BUILD_DIR) $(OUTPUT_DIR):
	mkdir -p $@

# Download the latest Raspberry Pi OS Lite (ARM64)
download: | $(DOWNLOAD_DIR)
	@echo "$(YELLOW)Downloading latest Raspberry Pi OS Lite ARM64...$(NC)"
	@bash scripts/download_rpi_os.sh $(DOWNLOAD_DIR)

# Extract the downloaded image
extract: | $(BUILD_DIR)
	@echo "$(YELLOW)Extracting image...$(NC)"
	@bash scripts/extract_image.sh $(DOWNLOAD_DIR) $(BUILD_DIR)

# Mount and modify the image
modify-image: extract
	@echo "$(YELLOW)Modifying image...$(NC)"
	@bash scripts/modify_image.sh $(BUILD_DIR)

# Build the complete modified image
build: | $(OUTPUT_DIR)
	@echo "$(YELLOW)Starting build process...$(NC)"
	@$(MAKE) download
	@$(MAKE) modify-image
	@echo "$(YELLOW)Packaging final image...$(NC)"
	@bash scripts/package_image.sh $(BUILD_DIR) $(OUTPUT_DIR) $(IMAGE_NAME)
	@echo "$(GREEN)Build complete! Image saved to $(OUTPUT_DIR)/$(IMAGE_NAME).img$(NC)"

# Clean up all build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	rm -rf $(BUILD_DIR) $(DOWNLOAD_DIR) $(OUTPUT_DIR)
	@echo "$(GREEN)Clean complete!$(NC)"

.DEFAULT_GOAL := help
