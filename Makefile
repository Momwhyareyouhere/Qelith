AS := as
LD := ld
SRC ?= examples/hello.flux
OUT ?= build/hello
RELEASE_DIR ?= release
DIST_DIR ?= dist
FLUX_SHARE_DIR ?= $(HOME)/.local/share/flux

.PHONY: all clean hello build compile run install package dist

all: build

flux0: flux0.s
	$(AS) --64 flux0.s -o flux0.o
	$(LD) -o flux0 flux0.o

build: package install
	@echo "Flux toolchain ready (flux + hidden bootstrap)."

compile: $(SRC)
	./flux build $(SRC) $(OUT)

hello: examples/hello.flux
	mkdir -p build
	./flux build examples/hello.flux build/hello

run:
	./flux run examples/hello.flux

package:
	rm -rf $(RELEASE_DIR)
	mkdir -p $(RELEASE_DIR)/bin
	mkdir -p $(RELEASE_DIR)/share/flux
	cp flux $(RELEASE_DIR)/bin/flux
	$(AS) --64 flux0.s -o $(RELEASE_DIR)/share/flux/flux0.o
	$(LD) -o $(RELEASE_DIR)/share/flux/flux0 $(RELEASE_DIR)/share/flux/flux0.o
	rm -f $(RELEASE_DIR)/share/flux/flux0.o
	chmod +x $(RELEASE_DIR)/bin/flux
	chmod +x $(RELEASE_DIR)/share/flux/flux0
	cp README.md $(RELEASE_DIR)/README.md

dist: package
	rm -rf $(DIST_DIR)
	mkdir -p $(DIST_DIR)
	tar -C $(RELEASE_DIR) -czf $(DIST_DIR)/flux-linux-x86_64.tar.gz .
	cp scripts/install-latest.sh $(DIST_DIR)/install-latest.sh
	chmod +x $(DIST_DIR)/install-latest.sh
	@echo "Created: $(DIST_DIR)/flux-linux-x86_64.tar.gz"
	@echo "Created: $(DIST_DIR)/install-latest.sh"

install: package
	mkdir -p $(HOME)/.local/bin
	mkdir -p $(FLUX_SHARE_DIR)
	cp $(RELEASE_DIR)/bin/flux $(HOME)/.local/bin/flux
	cp $(RELEASE_DIR)/share/flux/flux0 $(FLUX_SHARE_DIR)/flux0
	rm -f $(HOME)/.local/bin/flux0
	rm -f $(FLUX_SHARE_DIR)/flux0.s
	chmod +x $(HOME)/.local/bin/flux
	chmod +x $(FLUX_SHARE_DIR)/flux0
	@echo "Installed: $(HOME)/.local/bin/flux"
	@echo "Installed hidden bootstrap: $(FLUX_SHARE_DIR)/flux0"
	@echo "If needed, add to PATH: export PATH=\"$$HOME/.local/bin:$$PATH\""

clean:
	rm -f flux0 flux0.o
	rm -rf build
	rm -rf $(RELEASE_DIR)
	rm -rf $(DIST_DIR)
	rm -f $(HOME)/.local/bin/flux
	rm -f $(HOME)/.local/bin/flux0
	rm -f $(FLUX_SHARE_DIR)/flux0
	rm -f $(FLUX_SHARE_DIR)/flux0.s
	rm -f $(FLUX_SHARE_DIR)/flux0.o
