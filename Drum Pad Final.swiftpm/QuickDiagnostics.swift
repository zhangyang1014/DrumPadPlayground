import Foundation

// MARK: - Quick Diagnostics for Common Issues

func quickDiagnostics() {
    print("🔍 === QUICK DIAGNOSTICS ===")
    
    // Check Package.swift
    checkPackageSwift()
    
    // Check for duplicate files
    checkForDuplicates()
    
    // Check signing configuration
    checkSigningConfig()
    
    // Check resources
    checkResources()
    
    print("\n🔍 === DIAGNOSTICS COMPLETE ===")
    print("\n💡 Quick fixes available:")
    print("   - Run quickFix() to apply automatic fixes")
    print("   - Run ProjectCleaner.cleanProject() for deep clean")
}

private func checkPackageSwift() {
    print("\n📦 Package.swift Check:")
    
    do {
        let packageContent = try String(contentsOfFile: "Package.swift")
        
        // Check for problematic configurations
        if packageContent.contains("9W69ZP8S5F") {
            print("   ❌ Still contains Team ID")
        } else {
            print("   ✅ Team ID removed")
        }
        
        if packageContent.contains("Assets.xcassets") {
            print("   ❌ Still references Assets.xcassets in resources")
        } else {
            print("   ✅ Assets.xcassets not in resources (good)")
        }
        
        if packageContent.contains("from: \"0.1.5\"") {
            print("   ✅ AudioKit dependency format correct")
        } else {
            print("   ⚠️ AudioKit dependency format may need update")
        }
        
    } catch {
        print("   ❌ Could not read Package.swift: \(error)")
    }
}

private func checkForDuplicates() {
    print("\n🔄 Duplicate Files Check:")
    
    // Check if Assets.xcassets exists (it should)
    if FileManager.default.fileExists(atPath: "Assets.xcassets") {
        print("   ✅ Assets.xcassets directory exists")
    } else {
        print("   ❌ Assets.xcassets directory missing")
    }
    
    // Check for build artifacts that might cause conflicts
    let problematicPaths = [
        ".build",
        ".swiftpm/xcode/package.xcworkspace",
        "DerivedData"
    ]
    
    for path in problematicPaths {
        if FileManager.default.fileExists(atPath: path) {
            print("   ⚠️ Found build artifact: \(path) (may cause conflicts)")
        } else {
            print("   ✅ No build artifact: \(path)")
        }
    }
}

private func checkSigningConfig() {
    print("\n🔐 Signing Configuration Check:")
    
    do {
        let packageContent = try String(contentsOfFile: "Package.swift")
        
        if packageContent.contains("com.example.fingerdrumhero") {
            print("   ✅ Using generic bundle identifier")
        } else if packageContent.contains("com.bugelife.fingerdrumhero") {
            print("   ⚠️ Using specific bundle identifier (may cause signing issues)")
        }
        
        if packageContent.contains("teamIdentifier") {
            print("   ❌ Still contains teamIdentifier")
        } else {
            print("   ✅ No teamIdentifier specified")
        }
        
    } catch {
        print("   ❌ Could not check signing config: \(error)")
    }
}

private func checkResources() {
    print("\n📁 Resources Check:")
    
    let requiredResources = [
        ("Resources", "directory"),
        ("Assets.xcassets", "directory"),
        ("DrumTrainerModel.xcdatamodeld", "directory"),
        ("Resources/bass_drum_C1.wav", "file"),
        ("Resources/snare_D1.wav", "file")
    ]
    
    for (resource, type) in requiredResources {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: resource, isDirectory: &isDirectory)
        
        if exists {
            let actualType = isDirectory.boolValue ? "directory" : "file"
            if actualType == type {
                print("   ✅ \(resource) (\(type))")
            } else {
                print("   ⚠️ \(resource) exists but is \(actualType), expected \(type)")
            }
        } else {
            print("   ❌ Missing: \(resource) (\(type))")
        }
    }
}

// MARK: - Issue-Specific Fixes

func fixDuplicateAssetsIssue() {
    print("🎨 Fixing duplicate Assets.xcassets issue...")
    
    // The issue is that Xcode automatically includes Assets.xcassets
    // but we also had it in Package.swift resources
    print("✅ Solution: Assets.xcassets should NOT be in Package.swift resources")
    print("✅ Xcode handles Assets.xcassets automatically")
    print("💡 Clean build folder and rebuild")
}

func fixSigningIssues() {
    print("🔐 Fixing signing issues...")
    
    print("✅ Use generic bundle identifier")
    print("✅ Remove teamIdentifier from Package.swift")
    print("✅ Let Swift Playgrounds handle signing automatically")
    print("💡 For Xcode: Configure signing in project settings")
}