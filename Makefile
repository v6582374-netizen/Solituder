SHELL := /bin/bash
DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
BUNDLE_ID ?= com.solituder.app.dev
SWIFT := DEVELOPER_DIR=$(DEVELOPER_DIR) xcrun swift
XCODEBUILD := DEVELOPER_DIR=$(DEVELOPER_DIR) xcrun xcodebuild

.PHONY: verify-toolchain test spm-list-tests build

verify-toolchain:
	@echo "DEVELOPER_DIR=$(DEVELOPER_DIR)"
	@$(XCODEBUILD) -version
	@$(SWIFT) --version
	@xcode-select -p

test:
	@$(SWIFT) test

spm-list-tests:
	@$(SWIFT) test list

build:
	@$(SWIFT) build

.PHONY: iphone-list-devices iphone-install

iphone-list-devices:
	@DEVELOPER_DIR=$(DEVELOPER_DIR) ./scripts/list-ios-devices.sh

iphone-install:
	@DEVELOPER_DIR=$(DEVELOPER_DIR) TEAM_ID="$(TEAM_ID)" DEVICE_UDID="$(DEVICE_UDID)" BUNDLE_ID="$(BUNDLE_ID)" ./scripts/install-on-iphone.sh
