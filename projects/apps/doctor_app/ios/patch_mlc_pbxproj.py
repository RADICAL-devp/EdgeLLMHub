#!/usr/bin/env python3
"""Patch project.pbxproj to wire MLCSwift SPM + SmolLM model bundle.

This is idempotent: running it twice is a no-op after the first success.
"""
import os
import shutil
import sys

PBX = "/Users/devanshparashar/dev-playground/projects/apps/doctor_app/ios/Runner.xcodeproj/project.pbxproj"
MODEL_DIR = "mlc-llm/SmolLM-360M-Instruct-q4f16_1-MLC"
MODEL_NAME = "SmolLM-360M-Instruct-q4f16_1-MLC"
MLC_SWIFT_DIR = "mlc-llm/ios/MLCSwift"

# Stable 24-char hex IDs (uppercase, Xcode-style)
PKG_REF = "F2A1B3C4D5E6001122334455"   # XCLocalSwiftPackageReference
PROD_DEP = "F2A1B3C4D5E6001122334456"  # XCSwiftPackageProductDependency
FW_BUILD = "F2A1B3C4D5E6001122334457"  # PBXBuildFile (framework)
MODEL_REF = "F2A1B3C4D5E6001122334458" # PBXFileReference (model folder)
MODEL_BLD = "F2A1B3C4D5E6001122334459" # PBXBuildFile (model in resources)


def patch(content: str) -> str:
    if PKG_REF in content:
        print("Already patched — nothing to do.")
        return content

    # 1. XCLocalSwiftPackageReference section
    content = content.replace(
        "/* End XCLocalSwiftPackageReference section */",
        f'\t\t{PKG_REF} /* XCLocalSwiftPackageReference "{MLC_SWIFT_DIR}" */ = {{\n'
        f'\t\t\tisa = XCLocalSwiftPackageReference;\n'
        f'\t\t\trelativePath = {MLC_SWIFT_DIR};\n'
        f'\t\t}};\n'
        "/* End XCLocalSwiftPackageReference section */",
        1,
    )

    # 2. XCSwiftPackageProductDependency section
    content = content.replace(
        "/* End XCSwiftPackageProductDependency section */",
        f'\t\t{PROD_DEP} /* MLCSwift */ = {{\n'
        f'\t\t\tisa = XCSwiftPackageProductDependency;\n'
        f'\t\t\tpackage = {PKG_REF} /* XCLocalSwiftPackageReference "{MLC_SWIFT_DIR}" */;\n'
        f'\t\t\tproductName = MLCSwift;\n'
        f'\t\t}};\n'
        "/* End XCSwiftPackageProductDependency section */",
        1,
    )

    # 3. PBXBuildFile section (framework + model resource)
    content = content.replace(
        "/* End PBXBuildFile section */",
        f'\t\t{FW_BUILD} /* MLCSwift in Frameworks */ = {{isa = PBXBuildFile; productRef = {PROD_DEP} /* MLCSwift */; }};\n'
        f'\t\t{MODEL_BLD} /* {MODEL_NAME} in Resources */ = {{isa = PBXBuildFile; fileRef = {MODEL_REF} /* {MODEL_NAME} */; }};\n'
        "/* End PBXBuildFile section */",
        1,
    )

    # 4. PBXFileReference section (model folder reference)
    content = content.replace(
        "/* End PBXFileReference section */",
        f'\t\t{MODEL_REF} /* {MODEL_NAME} */ = {{isa = PBXFileReference; lastKnownFileType = folder; name = {MODEL_NAME}; path = {MODEL_DIR}; sourceTree = "<group>"; }};\n'
        "/* End PBXFileReference section */",
        1,
    )

    # 5. PBXProject packageReferences
    content = content.replace(
        "\t\t\tpackageReferences = (\n"
        "\t\t\t\t781AD8BC2B33823900A9FFBB /* XCLocalSwiftPackageReference "
        '"Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage" */,\n'
        "\t\t\t);",
        "\t\t\tpackageReferences = (\n"
        "\t\t\t\t781AD8BC2B33823900A9FFBB /* XCLocalSwiftPackageReference "
        '"Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage" */,\n'
        f"\t\t\t\t{PKG_REF} /* XCLocalSwiftPackageReference "
        f'"{MLC_SWIFT_DIR}" */,\n'
        "\t\t\t);",
        1,
    )

    # 6. Runner target packageProductDependencies
    content = content.replace(
        "\t\t\tpackageProductDependencies = (\n"
        "\t\t\t\t78A3181F2AECB46A00862997 /* FlutterGeneratedPluginSwiftPackage */,\n"
        "\t\t\t);",
        "\t\t\tpackageProductDependencies = (\n"
        "\t\t\t\t78A3181F2AECB46A00862997 /* FlutterGeneratedPluginSwiftPackage */,\n"
        f"\t\t\t\t{PROD_DEP} /* MLCSwift */,\n"
        "\t\t\t);",
        1,
    )

    # 7. Runner Frameworks build phase (97C146EB)
    content = content.replace(
        "\t\t\t\t78A318202AECB46A00862997 /* FlutterGeneratedPluginSwiftPackage in Frameworks */,\n"
        "\t\t\t\tEA8EECE1A58169AEEFDC561F /* libPods-Runner.a in Frameworks */,\n",
        "\t\t\t\t78A318202AECB46A00862997 /* FlutterGeneratedPluginSwiftPackage in Frameworks */,\n"
        "\t\t\t\tEA8EECE1A58169AEEFDC561F /* libPods-Runner.a in Frameworks */,\n"
        f"\t\t\t\t{FW_BUILD} /* MLCSwift in Frameworks */,\n",
        1,
    )

    # 8. Runner Resources build phase (97C146EC)
    content = content.replace(
        "\t\t\t\t97C146FC1CF9000F007C117D /* Main.storyboard in Resources */,\n"
        "\t\t\t);",
        f"\t\t\t\t97C146FC1CF9000F007C117D /* Main.storyboard in Resources */,\n"
        f"\t\t\t\t{MODEL_BLD} /* {MODEL_NAME} in Resources */,\n"
        "\t\t\t);",
        1,
    )

    return content


def main() -> int:
    if not os.path.exists(PBX):
        print(f"ERROR: {PBX} not found", file=sys.stderr)
        return 1
    backup = PBX + ".bak"
    shutil.copy2(PBX, backup)
    print(f"Backup written to {backup}")

    with open(PBX, "r") as f:
        original = f.read()

    patched = patch(original)

    if patched == original:
        print("No changes applied (already patched or anchor missing).")
        return 0

    # Sanity: ensure no anchor was left unmatched by checking both halves exist
    assert MODEL_NAME in patched, "model name missing after patch"
    assert PROD_DEP in patched, "product dependency missing after patch"

    with open(PBX, "w") as f:
        f.write(patched)
    print("Patched project.pbxproj successfully.")
    print("Next: open Runner.xcworkspace, add MLCSwift package if prompted, build & run.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
