export BUILDTYPE ?= Debug
export IS_LOCAL_DEVELOPMENT ?= true
export TARGET_BRANCH ?= master

CMAKE ?= cmake
SIGNING_IDENTITY ?= 'Apple Development'

MACOS_BRANCH = $(shell git describe --tags --match=macos-v*.*.* --abbrev=0)
MACOS_VERSION = $(shell echo ${MACOS_BRANCH} | sed 's/^macos-v//')

all: framework documentation

build/macos/CMakeCache.txt:
	@$(CMAKE) -B $(@D) -S $(PWD) -G Ninja \
		-DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
		-DMACOS_FRAMEWORK_VERSION="$(MACOS_VERSION)" \
		-DMACOS_SIGNING_IDENTITY="$(SIGNING_IDENTITY)"

build/macos/Mapbox.framework: build/macos/CMakeCache.txt
	@$(CMAKE) --build $(@D) --target framework

.PHONY: framework
framework: build/macos/Mapbox.framework

build/Mapbox.xcframework: build/macos/Mapbox.framework
	@xcodebuild -create-xcframework -framework $< -output $@

build/Mapbox-v$(MACOS_VERSION).zip: build/Mapbox.xcframework
	@cd $(@D) && zip -r -q $(@F) $(^F) && echo "Package complete: $(@F)"

build/Package.swift: platform/macos/Package.swift.in build/Mapbox-v$(MACOS_VERSION).zip
	@sed -e '\
		s/{VERSION}/$(MACOS_VERSION)/g; \
		s/{SHASUM}/$(shell shasum -a 256 $(word 2,$^) | cut -f 1 -d " ")/g' \
	$< > $@

.PHONY: package
package: build/Package.swift

build/documentation:
	@jazzy \
		--config platform/macos/jazzy.yml \
		--sdk macosx \
		--github-file-prefix https://github.com/mapbox/mapbox-gl-native-ios/tree/$(MACOS_BRANCH) \
		--module-version $(MACOS_VERSION) \
		--readme platform/macos/docs/doc-README.md \
		--documentation="platform/{darwin,macos}/docs/guides/*.md" \
		--theme platform/darwin/docs/theme \
		--output $@ \
		--title "Maps SDK for macOS" \
		--module-version $(MACOS_VERSION)

.PHONY: documentation
documentation: build/documentation

ifeq ($(BUILDTYPE), Release)
else ifeq ($(BUILDTYPE), RelWithDebInfo)
else ifeq ($(BUILDTYPE), Sanitize)
else ifeq ($(BUILDTYPE), Debug)
else
  $(error BUILDTYPE must be Debug, Sanitize, Release or RelWithDebInfo)
endif

buildtype := $(shell echo "$(BUILDTYPE)" | tr "[A-Z]" "[a-z]")

ifeq ($(shell uname -s), Darwin)
  HOST_PLATFORM = macos
  HOST_PLATFORM_VERSION = $(shell uname -m)
  export NINJA = platform/macos/ninja
  export NCPU := $(shell sysctl -n hw.ncpu)
  export JOBS ?= $(shell expr $(NCPU) - 1)
else ifeq ($(shell uname -s), Linux)
  HOST_PLATFORM = linux
  HOST_PLATFORM_VERSION = $(shell uname -m)
  export NINJA = platform/linux/ninja
  export JOBS ?= $(shell grep --count processor /proc/cpuinfo)
else
  $(error Cannot determine host platform)
endif

ifeq ($(MASON_PLATFORM),)
  BUILD_PLATFORM = $(HOST_PLATFORM)
else
  BUILD_PLATFORM = $(MASON_PLATFORM)
endif

ifeq ($(MASON_PLATFORM_VERSION),)
  BUILD_PLATFORM_VERSION = $(HOST_PLATFORM_VERSION)
else
  BUILD_PLATFORM_VERSION = $(MASON_PLATFORM_VERSION)
endif

ifeq ($(MASON_PLATFORM),macos)
	MASON_PLATFORM=osx
endif

ifeq ($(V), 1)
  export XCPRETTY
  NINJA_ARGS ?= -v
else
  export XCPRETTY ?= | tee '$(shell pwd)/build/xcodebuild-$(shell date +"%Y-%m-%d_%H%M%S").log' | xcpretty
  NINJA_ARGS ?=
endif

.PHONY: default
default: test

BUILD_DEPS += ./vendor/mapbox-gl-native/CMakeLists.txt

BUILD_DOCS ?= true

#### iOS targets ##############################################################

ifeq ($(HOST_PLATFORM), macos)

IOS_OUTPUT_PATH = build/ios
IOS_PROJ_PATH = $(IOS_OUTPUT_PATH)/Mapbox\ GL\ Native.xcodeproj
IOS_WORK_PATH = platform/ios/ios.xcworkspace
IOS_USER_DATA_PATH = $(IOS_WORK_PATH)/xcuserdata/$(USER).xcuserdatad

IOS_XCODEBUILD_SIM = xcodebuild \
	ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES \
	-derivedDataPath $(IOS_OUTPUT_PATH) \
	-configuration $(BUILDTYPE) -sdk iphonesimulator \
	-workspace $(IOS_WORK_PATH) \
	-jobs $(JOBS)

ifneq ($(MORE_SIMULATORS),)
	IOS_LATEST = true
	IOS_11 = true
	IOS_10 = true
	IOS_9 = true
endif

ifdef IOS_LATEST
	IOS_XCODEBUILD_SIM += \
	-destination 'platform=iOS Simulator,OS=latest,name=iPhone 8' \
	-destination 'platform=iOS Simulator,OS=latest,name=iPhone Xs Max' \
	-destination 'platform=iOS Simulator,OS=latest,name=iPhone Xr' \
	-destination 'platform=iOS Simulator,OS=latest,name=iPad Pro (11-inch)'
endif

ifdef IOS_11
	IOS_XCODEBUILD_SIM += \
	-destination 'platform=iOS Simulator,OS=11.4,name=iPhone 7' \
	-destination 'platform=iOS Simulator,OS=11.4,name=iPhone X' \
	-destination 'platform=iOS Simulator,OS=11.4,name=iPad (5th generation)'
endif

ifdef IOS_10
	IOS_XCODEBUILD_SIM += \
	-destination 'platform=iOS Simulator,OS=10.3.1,name=iPhone SE' \
	-destination 'platform=iOS Simulator,OS=10.3.1,name=iPhone 7 Plus' \
	-destination 'platform=iOS Simulator,OS=10.3.1,name=iPad Pro (9.7-inch)'
endif

ifdef IOS_9
	IOS_XCODEBUILD_SIM += \
	-destination 'platform=iOS Simulator,OS=9.3,name=iPhone 6s Plus' \
	-destination 'platform=iOS Simulator,OS=9.3,name=iPhone 6s' \
	-destination 'platform=iOS Simulator,OS=9.3,name=iPad Air 2'
endif

# If IOS_XCODEBUILD_SIM does not contain a simulator destination, add the default.
ifeq (, $(findstring destination, $(IOS_XCODEBUILD_SIM)))
	IOS_XCODEBUILD_SIM += \
	-destination 'platform=iOS Simulator,OS=latest,name=iPhone 8'
else
	IOS_XCODEBUILD_SIM += -parallel-testing-enabled YES
endif

ifneq ($(ONLY_TESTING),)
	IOS_XCODEBUILD_SIM += -only-testing:$(ONLY_TESTING)
endif

ifneq ($(SKIP_TESTING),)
	IOS_XCODEBUILD_SIM += -skip-testing:$(SKIP_TESTING)
endif

ifneq ($(CI),)
	IOS_XCODEBUILD_SIM += -xcconfig platform/darwin/ci.xcconfig
endif

$(IOS_PROJ_PATH): $(IOS_USER_DATA_PATH)/WorkspaceSettings.xcsettings $(BUILD_DEPS)
	mkdir -p $(IOS_OUTPUT_PATH)
	(cd $(IOS_OUTPUT_PATH) && $(CMAKE) -G Xcode ../../vendor/mapbox-gl-native \
		-DCMAKE_SYSTEM_NAME=iOS )

$(IOS_USER_DATA_PATH)/WorkspaceSettings.xcsettings: platform/ios/WorkspaceSettings.xcsettings
	mkdir -p "$(IOS_USER_DATA_PATH)"
	cp platform/ios/WorkspaceSettings.xcsettings "$@"

.PHONY: ios
ios: $(IOS_PROJ_PATH)
	set -o pipefail && $(IOS_XCODEBUILD_SIM) -scheme 'CI' build $(XCPRETTY)

.PHONY: iproj
iproj: $(IOS_PROJ_PATH)
	xed $(IOS_WORK_PATH)

.PHONY: ios-lint
ios-lint: ios-pod-lint
	find platform/ios/framework -type f -name '*.plist' | xargs plutil -lint
	find platform/ios/app -type f -name '*.plist' | xargs plutil -lint

.PHONY: ios-pod-lint
ios-pod-lint:
	./platform/ios/scripts/lint-podspecs.js

.PHONY: ios-test
ios-test: $(IOS_PROJ_PATH)
	set -o pipefail && $(IOS_XCODEBUILD_SIM) -scheme 'CI' test $(XCPRETTY)

.PHONY: ios-integration-test
ios-integration-test: $(IOS_PROJ_PATH)
	set -o pipefail && $(IOS_XCODEBUILD_SIM) -scheme 'Integration Test Harness' test $(XCPRETTY)

.PHONY: ios-sanitize
ios-sanitize: $(IOS_PROJ_PATH)
	set -o pipefail && $(IOS_XCODEBUILD_SIM) -scheme 'CI' -enableThreadSanitizer YES -enableUndefinedBehaviorSanitizer YES test $(XCPRETTY)

.PHONY: ios-sanitize-address
ios-sanitize-address: $(IOS_PROJ_PATH)
	set -o pipefail && $(IOS_XCODEBUILD_SIM) -scheme 'CI' -enableAddressSanitizer YES test $(XCPRETTY)

.PHONY: ios-static-analyzer
ios-static-analyzer: $(IOS_PROJ_PATH)
	set -o pipefail && $(IOS_XCODEBUILD_SIM) analyze -scheme 'CI' test $(XCPRETTY)

.PHONY: ios-install-simulators
ios-install-simulators:
	xcversion simulators --install="iOS 11.4" || true
	xcversion simulators --install="iOS 10.3.1" || true
	xcversion simulators --install="iOS 9.3" || true

.PHONY: ipackage
ipackage: ipackage*
ipackage%:
	@echo make ipackage is deprecated — use make iframework.

.PHONY: iframework
iframework: $(IOS_PROJ_PATH)
	FORMAT=$(FORMAT) BUILD_DEVICE=$(BUILD_DEVICE) SYMBOLS=$(SYMBOLS) BUILD_DOCS=$(BUILD_DOCS) \
	./platform/ios/scripts/package.sh

.PHONY: ideploy
ideploy:
	caffeinate -i ./platform/ios/scripts/deploy-packages.sh

.PHONY: idocument
idocument:
	OUTPUT=$(OUTPUT) ./platform/ios/scripts/document.sh

.PHONY: darwin-style-code
darwin-style-code:
	node platform/darwin/scripts/generate-style-code.js
	node platform/darwin/scripts/update-examples.js
style-code: darwin-style-code

.PHONY: darwin-update-examples
darwin-update-examples:
	node platform/darwin/scripts/update-examples.js

.PHONY: darwin-check-public-symbols
darwin-check-public-symbols:
	node platform/darwin/scripts/check-public-symbols.js macOS iOS

endif

#### macOS targets ############################################################

ifeq ($(HOST_PLATFORM), macos)

MACOS_OUTPUT_PATH = build/macos
MACOS_PROJ_PATH = $(MACOS_OUTPUT_PATH)/Mapbox\ GL\ Native.xcodeproj
MACOS_WORK_PATH = platform/macos/macos.xcworkspace
MACOS_USER_DATA_PATH = $(MACOS_WORK_PATH)/xcuserdata/$(USER).xcuserdatad

MACOS_XCODEBUILD = xcodebuild \
	-derivedDataPath $(MACOS_OUTPUT_PATH) \
	-configuration $(BUILDTYPE) \
	-workspace $(MACOS_WORK_PATH) \
	-jobs $(JOBS)

ifneq ($(CI),)
	MACOS_XCODEBUILD += -xcconfig platform/darwin/ci.xcconfig
endif

$(MACOS_PROJ_PATH): $(MACOS_USER_DATA_PATH)/WorkspaceSettings.xcsettings $(BUILD_DEPS)
	mkdir -p $(MACOS_OUTPUT_PATH)
	(cd $(MACOS_OUTPUT_PATH) && $(CMAKE) -G Xcode ../../vendor/mapbox-gl-native \
		-DCMAKE_SYSTEM_NAME=Darwin )

$(MACOS_USER_DATA_PATH)/WorkspaceSettings.xcsettings: platform/macos/WorkspaceSettings.xcsettings
	mkdir -p "$(MACOS_USER_DATA_PATH)"
	cp platform/macos/WorkspaceSettings.xcsettings "$@"

.PHONY: macos
macos: $(MACOS_PROJ_PATH)
	set -o pipefail && $(MACOS_XCODEBUILD) -scheme 'CI' build $(XCPRETTY)

.PHONY: xproj
xproj: $(MACOS_PROJ_PATH)
	xed $(MACOS_WORK_PATH)

.PHONY: macos-test
macos-test: $(MACOS_PROJ_PATH)
	set -o pipefail && $(MACOS_XCODEBUILD) -scheme 'CI' test $(XCPRETTY)

.PHONY: macos-lint
macos-lint:
	find platform/macos -type f -name '*.plist' | xargs plutil -lint

.PHONY: xpackage
xpackage: $(MACOS_PROJ_PATH)
	SYMBOLS=$(SYMBOLS) ./platform/macos/scripts/package.sh

.PHONY: xdeploy
xdeploy:
	caffeinate -i ./platform/macos/scripts/deploy-packages.sh

.PHONY: xdocument
xdocument:
	OUTPUT=$(OUTPUT) ./platform/macos/scripts/document.sh

.PHONY: genstrings
genstrings:
	genstrings -u -o platform/macos/sdk/Base.lproj platform/darwin/src/*.{m,mm}
	genstrings -u -o platform/macos/sdk/Base.lproj platform/macos/src/*.{m,mm}
	genstrings -u -o platform/ios/resources/Base.lproj platform/ios/src/*.{m,mm}
	-find platform/ios/resources platform/macos/sdk -path '*/Base.lproj/*.strings' -exec \
		textutil -convert txt -extension strings -inputencoding UTF-16 -encoding UTF-8 {} \;
	mv platform/macos/sdk/Base.lproj/Foundation.strings platform/darwin/resources/Base.lproj/

endif

#### Miscellaneous targets #####################################################

.PHONY: style-code
style-code:
	node scripts/generate-style-code.js
	node scripts/generate-shaders.js

.PHONY: codestyle
codestyle:
	scripts/codestyle.sh

.PHONY: clean
clean:
	-rm -rf ./build \
	        ./lib/*.node 

.PHONY: distclean
distclean: clean
	-rm -rf ./mason_packages
	-rm -rf ./node_modules
