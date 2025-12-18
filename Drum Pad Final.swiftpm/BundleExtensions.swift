import Foundation

// MARK: - Bundle Extensions for Swift Playgrounds Compatibility

extension Bundle {
    /// Safely loads a resource URL with fallback locations for Swift Playgrounds compatibility
    func safeURL(forResource name: String, withExtension ext: String?) -> URL? {
        // First try the standard Bundle.main approach
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        
        #if SWIFT_PACKAGE
        // Try Bundle.module for Swift Package Manager
        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return url
        }
        #endif
        
        // Try looking in Resources subdirectory
        if let url = Bundle.main.url(forResource: "Resources/\(name)", withExtension: ext) {
            return url
        }
        
        // Try without extension in case it's already included
        if let url = Bundle.main.url(forResource: name, withExtension: nil) {
            return url
        }
        
        // Last resort: try in the app bundle root
        if let bundlePath = Bundle.main.path(forResource: name, ofType: ext) {
            return URL(fileURLWithPath: bundlePath)
        }
        
        return nil
    }
    
    /// Logs available resources for debugging
    func logAvailableResources() {
        print("=== Bundle Resource Debug Info ===")
        print("Bundle path: \(self.bundlePath)")
        
        if let resourcePath = self.resourcePath {
            print("Resource path: \(resourcePath)")
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("Available resources:")
                for item in contents.sorted() {
                    print("  - \(item)")
                }
            } catch {
                print("Error reading resource directory: \(error)")
            }
        }
        
        // Check for Resources subdirectory
        if let resourcesPath = Bundle.main.path(forResource: "Resources", ofType: nil) {
            print("Resources subdirectory found at: \(resourcesPath)")
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcesPath)
                print("Resources subdirectory contents:")
                for item in contents.sorted() {
                    print("  - \(item)")
                }
            } catch {
                print("Error reading Resources subdirectory: \(error)")
            }
        }
        print("=== End Bundle Debug Info ===")
    }
}

// MARK: - Resource Loading Helpers

struct ResourceLoader {
    static func loadAudioFile(named fileName: String, withExtension ext: String = "wav") -> URL? {
        let url = Bundle.main.safeURL(forResource: fileName, withExtension: ext)
        
        if url == nil {
            print("⚠️ Could not find audio file: \(fileName).\(ext)")
            print("Available locations checked:")
            print("  - Bundle.main/\(fileName).\(ext)")
            #if SWIFT_PACKAGE
            print("  - Bundle.module/\(fileName).\(ext)")
            #endif
            print("  - Bundle.main/Resources/\(fileName).\(ext)")
            
            // Log available resources for debugging
            Bundle.main.logAvailableResources()
        }
        
        return url
    }
    
    static func loadCoreDataModel(named modelName: String) -> URL? {
        // In Swift Playgrounds, try different extensions and paths
        var url: URL?
        
        // Try .momd first (compiled model)
        url = Bundle.main.safeURL(forResource: modelName, withExtension: "momd")
        
        // If not found, try .xcdatamodeld (source model)
        if url == nil {
            url = Bundle.main.safeURL(forResource: modelName, withExtension: "xcdatamodeld")
        }
        
        // Try without extension
        if url == nil {
            url = Bundle.main.safeURL(forResource: modelName, withExtension: nil)
        }
        
        // Try looking for the model directory directly
        if url == nil {
            let bundlePath = Bundle.main.bundlePath
            let modelPath = "\(bundlePath)/\(modelName).xcdatamodeld"
            if FileManager.default.fileExists(atPath: modelPath) {
                url = URL(fileURLWithPath: modelPath)
            }
        }
        
        if url == nil {
            print("⚠️ Could not find Core Data model: \(modelName)")
            print("Tried extensions: .momd, .xcdatamodeld, (none)")
            Bundle.main.logAvailableResources()
        }
        
        return url
    }
}