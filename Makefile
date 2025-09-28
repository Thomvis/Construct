.PHONY: sourcery openapi test-ios test-constructapi test-server test-all

sourcery:
	sh scripts/sourcery-gen.sh

openapi:
	uv run --project Server python scripts/generate_openapi.py

test-ios:
	xcodebuild \
		-workspace App/Construct.xcodeproj/project.xcworkspace \
		-scheme UnitTests \
		-destination 'platform=iOS Simulator,name=iPhone 16' \
		test \
		| xcpretty

test-constructapi:
	xcodebuild \
		-workspace App/Construct.xcodeproj/project.xcworkspace \
		-scheme ConstructAPI \
		-destination 'platform=macOS,arch=arm64' \
		-skipPackagePluginValidation \
		-only-testing:ConstructAPITests \
		test \
		| xcpretty

test-server:
	uv run --project Server --extra dev pytest

test-all: test-constructapi test-ios test-server
