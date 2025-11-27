import Flutter
import UIKit
import VisionKit
import Vision

/// Flutter plugin for document scanning using VisionKit and Vision framework.
@available(iOS 13.0, *)
public class DocscannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate {
    
    private var pendingResult: FlutterResult?
    private var performOcr: Bool = false
    private var scannedImages: [UIImage] = []
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "docscanner", binaryMessenger: registrar.messenger())
        let instance = DocscannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "scanDocument":
            let args = call.arguments as? [String: Any]
            performOcr = false
            startDocumentScanner(result: result, args: args)
            
        case "scanReceipt":
            let args = call.arguments as? [String: Any]
            performOcr = args?["performOcr"] as? Bool ?? true
            startDocumentScanner(result: result, args: args)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startDocumentScanner(result: @escaping FlutterResult, args: [String: Any]?) {
        guard VNDocumentCameraViewController.isSupported else {
            result(FlutterError(code: "NOT_SUPPORTED",
                               message: "Document scanning is not supported on this device",
                               details: nil))
            return
        }
        
        if pendingResult != nil {
            result(FlutterError(code: "ALREADY_SCANNING",
                               message: "A scan is already in progress",
                               details: nil))
            return
        }
        
        pendingResult = result
        scannedImages = []
        
        DispatchQueue.main.async {
            guard let viewController = UIApplication.shared.windows.first?.rootViewController else {
                self.pendingResult?(FlutterError(code: "NO_VIEW_CONTROLLER",
                                                 message: "Could not find root view controller",
                                                 details: nil))
                self.pendingResult = nil
                return
            }
            
            let documentCameraVC = VNDocumentCameraViewController()
            documentCameraVC.delegate = self
            
            viewController.present(documentCameraVC, animated: true, completion: nil)
        }
    }
    
    // MARK: - VNDocumentCameraViewControllerDelegate
    
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true) {
            self.processScanResult(scan)
        }
    }
    
    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true) {
            self.pendingResult?(nil) // User cancelled
            self.pendingResult = nil
        }
    }
    
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true) {
            self.pendingResult?(FlutterError(code: "SCAN_FAILED",
                                            message: error.localizedDescription,
                                            details: nil))
            self.pendingResult = nil
        }
    }
    
    // MARK: - Image Processing
    
    private func processScanResult(_ scan: VNDocumentCameraScan) {
        var imagePaths: [String] = []
        
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let docscannerDir = cacheDir.appendingPathComponent("docscanner", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: docscannerDir, withIntermediateDirectories: true, attributes: nil)
        
        // Save each scanned page
        for pageIndex in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: pageIndex)
            scannedImages.append(image)
            
            let fileName = "scan_\(Date().timeIntervalSince1970)_\(pageIndex).jpg"
            let filePath = docscannerDir.appendingPathComponent(fileName)
            
            if let jpegData = image.jpegData(compressionQuality: 0.9) {
                do {
                    try jpegData.write(to: filePath)
                    imagePaths.append(filePath.path)
                } catch {
                    print("Failed to save image: \(error)")
                }
            }
        }
        
        if performOcr {
            performOcrOnImages(images: scannedImages) { ocrText in
                let resultMap: [String: Any?] = [
                    "success": true,
                    "imagePaths": imagePaths,
                    "pdfPath": nil,
                    "pageCount": imagePaths.count,
                    "ocrText": ocrText
                ]
                self.pendingResult?(resultMap)
                self.pendingResult = nil
            }
        } else {
            let resultMap: [String: Any?] = [
                "success": true,
                "imagePaths": imagePaths,
                "pdfPath": nil,
                "pageCount": imagePaths.count
            ]
            pendingResult?(resultMap)
            pendingResult = nil
        }
    }
    
    // MARK: - OCR
    
    private func performOcrOnImages(images: [UIImage], completion: @escaping (String) -> Void) {
        var textResults: [String] = []
        let dispatchGroup = DispatchGroup()
        
        for (index, image) in images.enumerated() {
            dispatchGroup.enter()
            
            performOcr(on: image) { text in
                // Ensure thread-safe access
                DispatchQueue.main.async {
                    // Pad the array if needed
                    while textResults.count <= index {
                        textResults.append("")
                    }
                    textResults[index] = text ?? ""
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let combinedText = textResults.joined(separator: "\n\n---PAGE BREAK---\n\n")
            completion(combinedText)
        }
    }
    
    private func performOcr(on image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR error: \(error)")
                completion(nil)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            let text = recognizedStrings.joined(separator: "\n")
            completion(text)
        }
        
        // Configure for best accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Support Croatian and English
        if #available(iOS 16.0, *) {
            request.recognitionLanguages = ["hr-HR", "en-US"]
        } else {
            request.recognitionLanguages = ["en-US"]
        }
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform OCR: \(error)")
            completion(nil)
        }
    }
}
