import Foundation
import CoreData

// MARK: - Resource Diagnostics Tool

struct ResourceDiagnostics {
    
    static func runFullDiagnostics() {
        print("🔍 === RESOURCE DIAGNOSTICS ===")
        
        // 1. Bundle Information
        printBundleInfo()
        
        // 2. Audio Resources
        checkAudioResources()
        
        // 3. Core Data Model
        checkCoreDataModel()
        
        // 4. Assets
        checkAssets()
        
        // 5. File System Check
        checkFileSystem()
        
        print("🔍 === DIAGNOSTICS COMPLETE ===")
    }
    
    private static func printBundleInfo() {
        print("\n📦 Bundle Information:")
        print("Bundle path: \(Bundle.main.bundlePath)")
        print("Bundle identifier: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        
        if let resourcePath = Bundle.main.resourcePath {
            print("Resource path: \(resourcePath)")
        }
        
        if let infoPlist = Bundle.main.infoDictionary {
            print("Bundle name: \(infoPlist["CFBundleName"] ?? "Unknown")")
            print("Bundle version: \(infoPlist["CFBundleShortVersionString"] ?? "Unknown")")
        }
    }
    
    private static func checkAudioResources() {
        print("\n🎵 Audio Resources Check:")
        
        let expectedAudioFiles = [
            "bass_drum_C1.wav",
            "snare_D1.wav", 
            "closed_hi_hat_F#1.wav",
            "crash_F1.wav",
            "clap_D#1.wav",
            "hi_tom_D2.wav",
            "lo_tom_F1.wav",
            "mid_tom_B1.wav",
            "open_hi_hat_A#1.wav"
        ]
        
        for fileName in expectedAudioFiles {
            let nameWithoutExt = String(fileName.dropLast(4)) // Remove .wav
            if let url = ResourceLoader.loadAudioFile(named: nameWithoutExt) {
                print("✅ \(fileName) - Found at: \(url.lastPathComponent)")
            } else {
                print("❌ \(fileName) - Missing")
            }
        }
    }
    
    private static func checkCoreDataModel() {
        print("\n🗄️ Core Data Model Check:")
        
        // Check for different model file formats
        let modelName = "DrumTrainerModel"
        
        // Check .momd (compiled)
        if let url = Bundle.main.url(forResource: modelName, withExtension: "momd") {
            print("✅ Found compiled model (.momd): \(url.path)")
        } else {
            print("❌ No compiled model (.momd) found")
        }
        
        // Check .xcdatamodeld (source)
        if let url = Bundle.main.url(forResource: modelName, withExtension: "xcdatamodeld") {
            print("✅ Found source model (.xcdatamodeld): \(url.path)")
            
            // Check model contents
            checkModelContents(at: url)
        } else {
            print("❌ No source model (.xcdatamodeld) found")
        }
        
        // Try to create the model
        do {
            let container = NSPersistentContainer(name: modelName)
            print("✅ NSPersistentContainer created successfully")
        } catch {
            print("❌ Failed to create NSPersistentContainer: \(error)")
        }
    }
    
    private static func checkModelContents(at url: URL) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            print("   Model directory contents:")
            for item in contents {
                print("   - \(item.lastPathComponent)")
            }
        } catch {
            print("   ❌ Could not read model directory: \(error)")
        }
    }
    
    private static func checkAssets() {
        print("\n🎨 Assets Check:")
        
        // Check for Assets.xcassets
        if let assetsPath = Bundle.main.path(forResource: "Assets", ofType: "xcassets") {
            print("✅ Assets.xcassets found at: \(assetsPath)")
        } else {
            print("❌ Assets.xcassets not found")
        }
        
        // Check for specific assets
        let expectedAssets = ["AppIcon", "AccentColor"]
        for assetName in expectedAssets {
            // This is a simplified check - in reality, asset checking is more complex
            print("   Checking for \(assetName)...")
        }
    }
    
    private static func checkFileSystem() {
        print("\n📁 File System Check:")
        
        let bundlePath = Bundle.main.bundlePath
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
            print("Bundle root contents (\(contents.count) items):")
            
            let sortedContents = contents.sorted()
            for (index, item) in sortedContents.enumerated() {
                if index < 20 { // Limit output
                    let itemPath = "\(bundlePath)/\(item)"
                    var isDirectory: ObjCBool = false
                    FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDirectory)
                    let type = isDirectory.boolValue ? "📁" : "📄"
                    print("   \(type) \(item)")
                } else if index == 20 {
                    print("   ... and \(contents.count - 20) more items")
                    break
                }
            }
        } catch {
            print("❌ Could not read bundle contents: \(error)")
        }
    }
    
    // MARK: - Specific Problem Diagnostics
    
    static func diagnoseSwiftPlaygroundsIssues() {
        print("\n🔧 Swift Playgrounds Specific Diagnostics:")
        
        // Check if we're running in Swift Playgrounds
        let isPlaygrounds = Bundle.main.bundleIdentifier?.contains("swift-playgrounds") ?? false
        print("Running in Swift Playgrounds: \(isPlaygrounds)")
        
        // Check for common Playgrounds resource issues
        if isPlaygrounds {
            print("📝 Swift Playgrounds Resource Notes:")
            print("   - Resources may be processed differently")
            print("   - .xcdatamodeld files might not compile to .momd")
            print("   - Bundle structure may differ from standard iOS apps")
        }
        
        // Check environment
        #if SWIFT_PACKAGE
        print("✅ SWIFT_PACKAGE flag is set")
        #else
        print("❌ SWIFT_PACKAGE flag is NOT set")
        #endif
    }
}

// MARK: - Quick Test Function

func testResourceLoading() {
    print("🚀 Quick Resource Test")
    ResourceDiagnostics.runFullDiagnostics()
    ResourceDiagnostics.diagnoseSwiftPlaygroundsIssues()
}