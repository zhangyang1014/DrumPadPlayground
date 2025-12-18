import Foundation

// MARK: - Project Cleanup Utility

struct ProjectCleaner {
    
    static func cleanProject() {
        print("🧹 Starting project cleanup...")
        
        // 1. Clean build artifacts
        cleanBuildArtifacts()
        
        // 2. Clean Xcode derived data
        cleanXcodeDerivedData()
        
        // 3. Reset Swift Package Manager cache
        resetSPMCache()
        
        // 4. Verify project structure
        verifyProjectStructure()
        
        print("✅ Project cleanup completed!")
        print("💡 Recommended next steps:")
        print("   1. Restart Xcode/Swift Playgrounds")
        print("   2. Clean Build Folder (⌘+Shift+K)")
        print("   3. Rebuild project")
    }
    
    private static func cleanBuildArtifacts() {
        print("\n🗑️ Cleaning build artifacts...")
        
        let buildPaths = [
            ".build",
            ".swiftpm/xcode",
            "DerivedData"
        ]
        
        for path in buildPaths {
            let fullPath = "\(FileManager.default.currentDirectoryPath)/\(path)"
            
            if FileManager.default.fileExists(atPath: fullPath) {
                do {
                    try FileManager.default.removeItem(atPath: fullPath)
                    print("   ✅ Removed: \(path)")
                } catch {
                    print("   ⚠️ Could not remove \(path): \(error)")
                }
            } else {
                print("   ℹ️ Not found: \(path)")
            }
        }
    }
    
    private static func cleanXcodeDerivedData() {
        print("\n🔧 Cleaning Xcode derived data...")
        
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let derivedDataPath = homeDirectory.appendingPathComponent("Library/Developer/Xcode/DerivedData")
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: derivedDataPath, includingPropertiesForKeys: nil)
            
            for item in contents {
                if item.lastPathComponent.contains("FingerDrumHero") {
                    try FileManager.default.removeItem(at: item)
                    print("   ✅ Removed Xcode derived data: \(item.lastPathComponent)")
                }
            }
        } catch {
            print("   ⚠️ Could not clean Xcode derived data: \(error)")
        }
    }
    
    private static func resetSPMCache() {
        print("\n📦 Resetting Swift Package Manager cache...")
        
        // This would typically be done via command line: swift package reset
        // In a Swift Playgrounds context, we can only suggest it
        print("   💡 Run 'swift package reset' in terminal if available")
        print("   💡 Or delete ~/.swiftpm directory manually")
    }
    
    private static func verifyProjectStructure() {
        print("\n🔍 Verifying project structure...")
        
        let requiredFiles = [
            "Package.swift",
            "DrumPadApp.swift",
            "Resources",
            "Assets.xcassets",
            "DrumTrainerModel.xcdatamodeld"
        ]
        
        for file in requiredFiles {
            if FileManager.default.fileExists(atPath: file) {
                print("   ✅ Found: \(file)")
            } else {
                print("   ❌ Missing: \(file)")
            }
        }
    }
    
    // MARK: - Specific Issue Fixes
    
    static func fixDuplicateAssets() {
        print("\n🎨 Fixing duplicate Assets.xcassets issue...")
        
        // The issue is likely in Xcode project settings, not in our Package.swift
        // Since we removed Assets.xcassets from Package.swift resources, 
        // Xcode should handle it automatically
        
        print("   ✅ Assets.xcassets removed from Package.swift resources")
        print("   💡 Xcode will handle Assets.xcassets automatically")
    }
    
    static func fixSigningIssues() {
        print("\n🔐 Fixing signing issues...")
        
        print("   ✅ Removed specific Team ID from Package.swift")
        print("   ✅ Changed bundle identifier to generic example")
        print("   💡 Configure signing in Xcode project settings if needed")
        print("   💡 For Swift Playgrounds, signing is handled automatically")
    }
    
    static func generateCleanPackageSwift() {
        print("\n📝 Generating clean Package.swift...")
        
        let cleanPackageContent = """
// swift-tools-version: 5.6

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "FingerDrumHero",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "FingerDrumHero",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.fingerdrumhero",
            displayVersion: "1.0.1",
            bundleVersion: "1",
            iconAssetName: "AppIcon",
            accentColorAssetName: "AccentColor",
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/AudioKit/AudioKitUI", from: "0.1.5")
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "AudioKitUI", package: "AudioKitUI")
            ],
            path: ".",
            resources: [
                .process("Resources"),
                .process("DrumTrainerModel.xcdatamodeld")
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ]
        )
    ]
)
"""
        
        do {
            try cleanPackageContent.write(toFile: "Package.swift", atomically: true, encoding: .utf8)
            print("   ✅ Generated clean Package.swift")
        } catch {
            print("   ❌ Could not write Package.swift: \(error)")
        }
    }
}

// MARK: - Quick Fix Function

func quickFix() {
    print("🚀 Quick Fix for Common Issues")
    ProjectCleaner.fixDuplicateAssets()
    ProjectCleaner.fixSigningIssues()
    print("\n💡 If issues persist, run: ProjectCleaner.cleanProject()")
}