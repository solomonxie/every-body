MODELS_DIR ?= $(HOME)/Downloads/every-body-models
TOOLS ?= $(or $(EVERYBODY_TOOLS),$(CURDIR)/tools)
BLENDER := $(TOOLS)/Blender.app/Contents/MacOS/Blender
STORE ?= us

.PHONY: device models-export models-import release screenshots

# figure variants + anatomy → .blend files for hand editing (an old MODELS_DIR is moved to /tmp)
# ONLY=female.adult.white exports just that variant (its body is the L chest, medium hips build)
models-export: export MODELS_ONLY = $(ONLY)
models-export:
	"$(BLENDER)" -b -P scripts/models/hand_edit.py -- export "$(MODELS_DIR)" 2>&1 | grep -E "^EXPORT|Error|Traceback|File \""

# moved figure vertices from MODELS_DIR → build/models/figure, then repack Resources/Models
models-import:
	"$(BLENDER)" -b -P scripts/models/hand_edit.py -- import "$(MODELS_DIR)" 2>&1 | grep -E "^IMPORT|Error|Traceback|File \"" \
		| tee /dev/stderr | grep -q "^IMPORT →" && scripts/models/build.sh pack || echo "nothing to pack"

# Release build onto the paired iPhone; STORE=cn for the China App Store (default us = Canada/US)
device:
	STORE=$(STORE) scripts/install-ios-device.sh

# Archive, sign for the App Store and upload (scripts/release-ios.sh); BUILD=202610021830 pins the build number
release:
	@git diff --quiet HEAD -- || echo "warning: uncommitted changes are going into this build"
	scripts/release-ios.sh $(BUILD)

# SHOTS=<dir of iPhone screenshots> → docs/release/screenshots/{6.9,6.5}, JPEG, no alpha
screenshots:
	scripts/store-screenshots.sh $(SHOTS)
