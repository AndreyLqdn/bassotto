.PHONY: build run clean icon

# Build Bassotto.app into build/ (Command Line Tools only, no Xcode).
build:
	./scripts/bundle.sh

# Build, install to /Applications and launch.
run:
	./scripts/bundle.sh --install

# Regenerate Support/App/AppIcon.icns from the dog's line art.
icon:
	mkdir -p .build/icon
	swiftc -parse-as-library -o .build/icon/render scripts/AppIcon.swift Sources/Bassotto/Dog/DogArt.swift
	.build/icon/render .build/icon/AppIcon.iconset
	iconutil -c icns .build/icon/AppIcon.iconset -o Support/App/AppIcon.icns

clean:
	rm -rf .build build
