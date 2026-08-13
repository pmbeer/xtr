#!/usr/bin/env python3
"""Generate DartPredictor.xcodeproj/project.pbxproj with correct nested paths."""

import os
import uuid

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_DIR = "DartPredictor"

def uid():
    return uuid.uuid4().hex[:24].upper()

def collect_swift_files(root_name):
    root = os.path.join(PROJECT_DIR, root_name)
    files = []
    for dirpath, _, filenames in os.walk(root):
        for f in filenames:
            if f.endswith(".swift"):
                full = os.path.join(dirpath, f)
                rel = os.path.relpath(full, PROJECT_DIR).replace("\\", "/")
                files.append(rel)
    return sorted(files)

swift_files = collect_swift_files(APP_DIR)
test_files = collect_swift_files("DartPredictorTests")

file_refs = {f: uid() for f in swift_files + test_files}
build_app = {f: uid() for f in swift_files}
build_test = {f: uid() for f in test_files}

project_uid = "A10000000000000000000001"
main_target = "A10000000000000000000002"
test_target = "A10000000000000000000003"
main_product = "A10000000000000000000004"
test_product = "A10000000000000000000005"
app_group = "A10000000000000000000006"
test_group = "A10000000000000000000007"
sources_app = "A10000000000000000000008"
sources_test = "A10000000000000000000009"
resources_phase = "A10000000000000000000010"
frameworks_app = "A10000000000000000000011"
frameworks_test = "A10000000000000000000012"
root_group = "A10000000000000000000013"
products_group = "A10000000000000000000014"
config_proj = "A10000000000000000000015"
config_target = "A10000000000000000000016"
config_test = "A10000000000000000000017"
debug_proj = "A10000000000000000000018"
release_proj = "A10000000000000000000019"
debug_target = "A10000000000000000000020"
release_target = "A10000000000000000000021"
debug_test_cfg = "A10000000000000000000022"
release_test_cfg = "A10000000000000000000023"
assets_ref = uid()
assets_build = uid()
entitlements_ref = uid()
info_plist_ref = uid()

lines = []
lines.append("// !$*UTF8*$!")
lines.append("{")
lines.append("	archiveVersion = 1;")
lines.append("	classes = {};")
lines.append("	objectVersion = 56;")
lines.append("	objects = {")

lines.append("\n/* Begin PBXBuildFile section */")
for f in swift_files:
    bn = os.path.basename(f)
    lines.append(f"		{build_app[f]} /* {bn} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f]} /* {bn} */; }};")
for f in test_files:
    bn = os.path.basename(f)
    lines.append(f"		{build_test[f]} /* {bn} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f]} /* {bn} */; }};")
lines.append(f"		{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref} /* Assets.xcassets */; }};")
lines.append("/* End PBXBuildFile section */")

lines.append("\n/* Begin PBXFileReference section */")
lines.append(f"		{main_product} /* DartPredictor.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = DartPredictor.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
lines.append(f"		{test_product} /* DartPredictorTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = DartPredictorTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
for f in swift_files + test_files:
    bn = os.path.basename(f)
    lines.append(f"		{file_refs[f]} /* {bn} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {bn}; path = {f}; sourceTree = SOURCE_ROOT; }};")
lines.append(f"		{assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = DartPredictor/Resources/Assets.xcassets; sourceTree = SOURCE_ROOT; }};")
lines.append(f"		{entitlements_ref} /* DartPredictor.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = DartPredictor/DartPredictor.entitlements; sourceTree = SOURCE_ROOT; }};")
lines.append(f"		{info_plist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = DartPredictor/Info.plist; sourceTree = SOURCE_ROOT; }};")
lines.append("/* End PBXFileReference section */")

lines.append("\n/* Begin PBXFrameworksBuildPhase section */")
lines.append(f"		{frameworks_app} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
lines.append(f"		{frameworks_test} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")
lines.append("/* End PBXFrameworksBuildPhase section */")

lines.append("\n/* Begin PBXGroup section */")
lines.append(f"		{app_group} = {{isa = PBXGroup; children = (")
for f in swift_files:
    bn = os.path.basename(f)
    lines.append(f"			{file_refs[f]} /* {bn} */,")
lines.append(f"			{assets_ref} /* Assets.xcassets */,")
lines.append(f"			{entitlements_ref} /* DartPredictor.entitlements */,")
lines.append(f"			{info_plist_ref} /* Info.plist */,")
lines.append("		); name = DartPredictor; sourceTree = \"<group>\"; };")

lines.append(f"		{test_group} = {{isa = PBXGroup; children = (")
for f in test_files:
    bn = os.path.basename(f)
    lines.append(f"			{file_refs[f]} /* {bn} */,")
lines.append("		); path = DartPredictorTests; sourceTree = \"<group>\"; };")

lines.append(f"		{products_group} = {{isa = PBXGroup; children = (")
lines.append(f"			{main_product} /* DartPredictor.app */,")
lines.append(f"			{test_product} /* DartPredictorTests.xctest */,")
lines.append("		); name = Products; sourceTree = \"<group>\"; };")

lines.append(f"		{root_group} = {{isa = PBXGroup; children = (")
lines.append(f"			{app_group},")
lines.append(f"			{test_group},")
lines.append(f"			{products_group},")
lines.append("		); sourceTree = \"<group>\"; };")
lines.append("/* End PBXGroup section */")

lines.append("\n/* Begin PBXNativeTarget section */")
lines.append(f"		{main_target} /* DartPredictor */ = {{")
lines.append(f"			isa = PBXNativeTarget;")
lines.append(f"			buildConfigurationList = {config_target};")
lines.append(f"			buildPhases = ({sources_app} /* Sources */, {frameworks_app} /* Frameworks */, {resources_phase} /* Resources */);")
lines.append("			buildRules = (); dependencies = ();")
lines.append("			name = DartPredictor; productName = DartPredictor;")
lines.append(f"			productReference = {main_product}; productType = \"com.apple.product-type.application\";")
lines.append("		};")
lines.append(f"		{test_target} /* DartPredictorTests */ = {{")
lines.append(f"			isa = PBXNativeTarget;")
lines.append(f"			buildConfigurationList = {config_test};")
lines.append(f"			buildPhases = ({sources_test} /* Sources */, {frameworks_test} /* Frameworks */);")
lines.append("			buildRules = (); dependencies = ();")
lines.append("			name = DartPredictorTests; productName = DartPredictorTests;")
lines.append(f"			productReference = {test_product}; productType = \"com.apple.product-type.bundle.unit-test\";")
lines.append("		};")
lines.append("/* End PBXNativeTarget section */")

lines.append("\n/* Begin PBXProject section */")
lines.append(f"		{project_uid} /* Project object */ = {{")
lines.append("			isa = PBXProject;")
lines.append(f"			buildConfigurationList = {config_proj};")
lines.append("			compatibilityVersion = \"Xcode 14.0\"; developmentRegion = ru;")
lines.append("			hasScannedForEncodings = 0; knownRegions = (ru, Base);")
lines.append(f"			mainGroup = {root_group}; productRefGroup = {products_group};")
lines.append("			projectDirPath = \"\"; projectRoot = \"\";")
lines.append(f"			targets = ({main_target}, {test_target});")
lines.append("		};")
lines.append("/* End PBXProject section */")

lines.append("\n/* Begin PBXResourcesBuildPhase section */")
lines.append(f"		{resources_phase} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({assets_build}); runOnlyForDeploymentPostprocessing = 0; }};")
lines.append("/* End PBXResourcesBuildPhase section */")

lines.append("\n/* Begin PBXSourcesBuildPhase section */")
lines.append(f"		{sources_app} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (")
for f in swift_files:
    bn = os.path.basename(f)
    lines.append(f"			{build_app[f]} /* {bn} in Sources */,")
lines.append("		); runOnlyForDeploymentPostprocessing = 0; };")
lines.append(f"		{sources_test} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (")
for f in test_files:
    bn = os.path.basename(f)
    lines.append(f"			{build_test[f]} /* {bn} in Sources */,")
lines.append("		); runOnlyForDeploymentPostprocessing = 0; };")
lines.append("/* End PBXSourcesBuildPhase section */")

lines.append("\n/* Begin XCBuildConfiguration section */")
lines.append(f"		{debug_proj} /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {{ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; COPY_PHASE_STRIP = NO; DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_TESTABILITY = YES; GCC_OPTIMIZATION_LEVEL = 0; MACOSX_DEPLOYMENT_TARGET = 14.0; ONLY_ACTIVE_ARCH = YES; SDKROOT = macosx; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; SWIFT_OPTIMIZATION_LEVEL = \"-Onone\"; }}; name = Debug; }};")
lines.append(f"		{release_proj} /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {{ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; COPY_PHASE_STRIP = NO; DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\"; MACOSX_DEPLOYMENT_TARGET = 14.0; SDKROOT = macosx; SWIFT_COMPILATION_MODE = wholemodule; SWIFT_OPTIMIZATION_LEVEL = \"-O\"; }}; name = Release; }};")

target_settings = """
			CODE_SIGN_ENTITLEMENTS = DartPredictor/DartPredictor.entitlements;
			CODE_SIGN_STYLE = Automatic;
			COMBINE_HIDPI_IMAGES = YES;
			CURRENT_PROJECT_VERSION = 1;
			ENABLE_HARDENED_RUNTIME = YES;
			GENERATE_INFOPLIST_FILE = NO;
			INFOPLIST_FILE = DartPredictor/Info.plist;
			LD_RUNPATH_SEARCH_PATHS = \"$(inherited) @executable_path/../Frameworks\";
			MARKETING_VERSION = 1.0.0;
			PRODUCT_BUNDLE_IDENTIFIER = com.dartpredictor.app;
			PRODUCT_NAME = \"$(TARGET_NAME)\";
			SWIFT_EMIT_LOC_STRINGS = YES;
			SWIFT_VERSION = 5.0;
"""
lines.append(f"		{debug_target} /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {{{target_settings}}}; name = Debug; }};")
lines.append(f"		{release_target} /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {{{target_settings}}}; name = Release; }};")

test_settings = """
			BUNDLE_LOADER = \"$(TEST_HOST)\";
			CODE_SIGN_STYLE = Automatic;
			GENERATE_INFOPLIST_FILE = YES;
			MACOSX_DEPLOYMENT_TARGET = 14.0;
			PRODUCT_BUNDLE_IDENTIFIER = com.dartpredictor.app.tests;
			PRODUCT_NAME = \"$(TARGET_NAME)\";
			SWIFT_VERSION = 5.0;
			TEST_HOST = \"$(BUILT_PRODUCTS_DIR)/DartPredictor.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/DartPredictor\";
"""
lines.append(f"		{debug_test_cfg} /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {{{test_settings}}}; name = Debug; }};")
lines.append(f"		{release_test_cfg} /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {{{test_settings}}}; name = Release; }};")
lines.append("/* End XCBuildConfiguration section */")

lines.append("\n/* Begin XCConfigurationList section */")
lines.append(f"		{config_proj} = {{isa = XCConfigurationList; buildConfigurations = ({debug_proj}, {release_proj}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};")
lines.append(f"		{config_target} = {{isa = XCConfigurationList; buildConfigurations = ({debug_target}, {release_target}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};")
lines.append(f"		{config_test} = {{isa = XCConfigurationList; buildConfigurations = ({debug_test_cfg}, {release_test_cfg}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};")
lines.append("/* End XCConfigurationList section */")

lines.append("	};")
lines.append(f"	rootObject = {project_uid} /* Project object */;")
lines.append("}")

out = os.path.join(PROJECT_DIR, "DartPredictor.xcodeproj", "project.pbxproj")
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w") as fh:
    fh.write("\n".join(lines))

print(f"Generated {out} ({len(swift_files)} app sources, {len(test_files)} test sources)")
