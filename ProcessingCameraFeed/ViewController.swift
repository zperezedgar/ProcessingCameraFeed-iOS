//
//  ViewController.swift
//  ProcessingCameraFeed
//
//  Created by Edgar Zuniga on 20/05/22.
//  See: https://anuragajwani.medium.com/how-to-process-images-real-time-from-the-ios-camera-9c416c531749
//  See: https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutputsamplebufferdelegate
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let captureSession = AVCaptureSession()
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
        preview.videoGravity = .resizeAspect
        return preview
    }()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    @IBOutlet weak var photoView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.addCameraInput()
        //self.addPreviewLayer()
        self.addVideoOutput()
        self.captureSession.startRunning()
    }

    private func addCameraInput() {
        let device = AVCaptureDevice.default(for: .video)!
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        self.captureSession.addInput(cameraInput)
    }
    
    private func addPreviewLayer() {
        self.view.layer.addSublayer(self.previewLayer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.bounds
    }
    
    private func addVideoOutput() {
        self.videoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "my.image.handling.queue"))
        self.captureSession.addOutput(self.videoOutput)
    }
    
    // Inherited from AVCaptureVideoDataOutputSampleBufferDelegate
    // Note: it seems that only the last frame is kept so there may be dropped frames if the processing is to intensive
    // see: https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutputsamplebufferdelegate/1385775-captureoutput
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("unable to get image from sample buffer")
            return
        }
        print("did recieve image frame")
        
        // process image here
        let cgImage = CreateCGImageFromCVPixelBuffer(pixelBuffer: frame)
        let image = UIImage(cgImage: cgImage!)
        
        DispatchQueue.main.sync {
            // update main thread
            photoView.image = image
        }
        
        
    }
    
    // MARK: Extra Utilities
    func DegreesToRadians(_ degrees: CGFloat) -> CGFloat { return CGFloat( (degrees * .pi) / 180 ) }

    func CreateCGImageFromCVPixelBuffer(pixelBuffer: CVPixelBuffer) -> CGImage? {
        let bitmapInfo: CGBitmapInfo
        let sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        if kCVPixelFormatType_32ARGB == sourcePixelFormat {
            bitmapInfo = [.byteOrder32Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)]
        } else
        if kCVPixelFormatType_32BGRA == sourcePixelFormat {
            bitmapInfo = [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)]
        } else {
            return nil
        }

        // only uncompressed pixel formats
        let sourceRowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        print("Buffer image size \(width) height \(height)")

        let val: CVReturn = CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        if  val == kCVReturnSuccess,
            let sourceBaseAddr = CVPixelBufferGetBaseAddress(pixelBuffer),
            let provider = CGDataProvider(dataInfo: nil, data: sourceBaseAddr, size: sourceRowBytes * height, releaseData: {_,_,_ in })
        {
            let colorspace = CGColorSpaceCreateDeviceRGB()
            let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: sourceRowBytes,
                            space: colorspace, bitmapInfo: bitmapInfo, provider: provider, decode: nil,
                            shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            return image
        } else {
            return nil
        }
    }
    // utility used by newSquareOverlayedImageForFeatures for
    static func CreateCGBitmapContextForSize(_ size: CGSize) -> CGContext? {
        let bitmapBytesPerRow = Int(size.width * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                        bytesPerRow: bitmapBytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setAllowsAntialiasing(false)
        return context
    }
}

