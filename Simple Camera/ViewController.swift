//
//  ViewController.swift
//  Simple Camera
//
//  Created by Jim Liang on 4/27/16.
//  Copyright © 2016 Jim. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVAudioRecorderDelegate {

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var takePhotoBtn: UIButton!
    @IBOutlet weak var startListeningBtn: UIButton!
    
    var captureSession: AVCaptureSession?
    var stillImageOutput: AVCaptureStillImageOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var capturedImage: UIImage? {
        didSet {
            if capturedImage != nil {
                performSegueWithIdentifier("takePhotoTapped", sender: self)
            }
        }
    }
    
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var meterTimer: NSTimer!
    var averagePower: Float?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        captureSession = AVCaptureSession()
        captureSession!.sessionPreset = AVCaptureSessionPresetPhoto
        
        let cameras = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        var captureDevice: AVCaptureDevice?
        
        for device in cameras {
            if device.position == AVCaptureDevicePosition.Front {
                captureDevice = device as? AVCaptureDevice
            }
        }
        
        var error: NSError?
        var input: AVCaptureDeviceInput!
        do {
            input = try AVCaptureDeviceInput(device: captureDevice)
        } catch let error1 as NSError {
            error = error1
            input = nil
        }
        
        if error == nil && captureSession!.canAddInput(input) {
            captureSession!.addInput(input)
            
            stillImageOutput = AVCaptureStillImageOutput()
            stillImageOutput!.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
            if captureSession!.canAddOutput(stillImageOutput) {
                captureSession!.addOutput(stillImageOutput)
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer!.videoGravity = AVLayerVideoGravityResizeAspect
                previewLayer!.connection?.videoOrientation = AVCaptureVideoOrientation.Portrait
                previewView.layer.addSublayer(previewLayer!)
                
                captureSession!.startRunning()
                print("device ready to take photo")
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer!.frame = previewView.bounds
    }
    
    @IBAction func takePhotoBtnPressed(sender: UIButton) {
        takePhoto()
    }
    
    func takePhoto() {
        if let videoConnection = stillImageOutput!.connectionWithMediaType(AVMediaTypeVideo) {
            videoConnection.videoOrientation = AVCaptureVideoOrientation.Portrait
            stillImageOutput?.captureStillImageAsynchronouslyFromConnection(videoConnection, completionHandler: {(sampleBuffer, error) in
                if (sampleBuffer != nil) {
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                    let dataProvider = CGDataProviderCreateWithCFData(imageData)
                    let cgImageRef = CGImageCreateWithJPEGDataProvider(dataProvider, nil, true, CGColorRenderingIntent.RenderingIntentDefault)
                    self.capturedImage = UIImage(CGImage: cgImageRef!, scale: 1.0, orientation: UIImageOrientation.Right)
                }
            })
        }
    }

    @IBAction func startListeningBtnTapped(sender: UIButton) {
        if audioRecorder == nil {
            recordingSession = AVAudioSession.sharedInstance()
            var builtinMicInput: AVAudioSessionPortDescription?
            var micDataSource: AVAudioSessionDataSourceDescription?
            for input in recordingSession.availableInputs! {
                if input.portType == AVAudioSessionPortBuiltInMic {
                    print("found built-in mic")
                    builtinMicInput = input
                    for dataSource in input.dataSources! {
                        if dataSource.orientation == AVAudioSessionOrientationFront {
                            micDataSource = dataSource
                        }
                    }
                    if micDataSource == nil {
                        for dataSource in input.dataSources! {
                            if dataSource.orientation == AVAudioSessionOrientationTop {
                                micDataSource = dataSource
                            }
                        }
                    }
                }
            }
            
            do {
                try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
                try builtinMicInput!.setPreferredDataSource(micDataSource)
                try recordingSession.setPreferredInput(builtinMicInput)
                print("\(recordingSession.availableInputs![0])")
                try recordingSession.setActive(true)
                
                recordingSession.requestRecordPermission() { [unowned self] (allowed: Bool) -> Void in
                    dispatch_async(dispatch_get_main_queue()) {
                        if allowed {
                            self.startRecording()
                        } else {
                            print("failed to record")
                        }
                    }
                }
            } catch {
                print("failed to record")
            }
        }
        else {
            finishRecording(success: true)
        }

    }
    
    func startRecording() {
        let audioFilename = getDocumentsDirectory().stringByAppendingPathComponent("recording.m4a")
        let audioURL = NSURL(fileURLWithPath: audioFilename)
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000.0,
            AVNumberOfChannelsKey: 1 as NSNumber,
            AVEncoderAudioQualityKey: AVAudioQuality.High.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(URL: audioURL, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.record()
            audioRecorder.meteringEnabled = true
            
            meterTimer = NSTimer.scheduledTimerWithTimeInterval(0.5, target:self, selector:#selector(ViewController.checkAudioMeter), userInfo:nil, repeats:true)
            
            startListeningBtn.setTitle("Tap to Stop", forState: .Normal)
            print("start recording")
        } catch {
            finishRecording(success: false)
        }
    }
    
    func getDocumentsDirectory() -> NSString {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    func finishRecording(success success: Bool) {
        audioRecorder.stop()
        print("stop recording")
        audioRecorder.deleteRecording()
        audioRecorder = nil
        
        meterTimer.invalidate()
        averagePower = nil
        
        if success {
            startListeningBtn.setTitle("Start Listening", forState: .Normal)
        } else {
            startListeningBtn.setTitle("Start Listening", forState: .Normal)
        }
    }
    
    func checkAudioMeter() {
        if audioRecorder.recording {
            audioRecorder.updateMeters()
            if averagePower == nil {
                averagePower = audioRecorder.averagePowerForChannel(0)
                print("Initial averagePower is \(averagePower)")
            } else {
                print("New averagePower is \(audioRecorder.averagePowerForChannel(0))")
                if audioRecorder.averagePowerForChannel(0) > -30 {
                    finishRecording(success: true)
                    takePhoto()
                }
            }
        }
    }
    
    func audioRecorderDidFinishRecording(recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    

    @IBAction func unwindToMainView(sender: UIStoryboardSegue) {
        capturedImage = nil
        captureSession!.startRunning()
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "takePhotoTapped" {
            let navController = segue.destinationViewController as! UINavigationController
            let capturedImageViewController = navController.topViewController as! CapturedImageViewController
            if capturedImage != nil {
                capturedImageViewController.capturedImage = capturedImage
            }
        }
    }

}

