.PHONY: build run clean

# Build Bassotto.app into build/ (Command Line Tools only, no Xcode).
build:
	./scripts/bundle.sh

# Build, install to ~/Applications, register the widget and launch.
run:
	./scripts/bundle.sh --install

clean:
	rm -rf .build build
