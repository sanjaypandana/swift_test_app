//
//  ViewController.swift
//  Trim.it
//
//  Created by Sanjay Pandana on 5/15/18.
//  Copyright © 2018 Sanjay Pandana. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices
import CoreMedia
import AssetsLibrary
import Photos
class ViewController: UIViewController {

    var isPlaying = true
    var isSliderEnd = true
    var playbackTimeCheckerTimer: Timer! = nil
    let playerObserver: Any? = nil
    
    let exportSession: AVAssetExportSession! = nil
    var player: AVPlayer!
    var playerItem: AVPlayerItem!
    var playerLayer: AVPlayerLayer!
    var asset: AVAsset!
    
    var url:NSURL! = nil
    var startTime: CGFloat = 0.0
    var stopTime: CGFloat  = 0.0
    var thumbTime: CMTime!
    var thumbtimeSeconds: Int!
    
    var videoPlaybackPosition: CGFloat = 0.0
    var cache:NSCache<AnyObject, AnyObject>!
    var rangeSlider: RangeSlider! = nil
    
    @IBOutlet weak var vidView: UIView!
    @IBOutlet weak var slideView: UIView!
    @IBOutlet weak var selectBut: UIButton!
    @IBOutlet weak var trimBut: UIButton!
    @IBOutlet weak var sTime: UITextField!
    @IBOutlet weak var eTime: UITextField!
    //Loading Views
    func loadViews()
    {
        player = AVPlayer()
        //Allocating NsCahe for temp storage
        self.cache = NSCache()
    }
    //Action for select Video
    @IBAction func selectVideoUrl(_ sender: Any)
    {
        //Selecting Video type
        let imgPick        = UIImagePickerController()
        imgPick.sourceType = .photoLibrary
        imgPick.mediaTypes = [(kUTTypeMovie) as String]
        imgPick.delegate   = self
        self.present(imgPick, animated: true, completion: nil)
    }
    //Action for crop video
    @IBAction func cropVideo(_ sender: Any)
    {
        let start = Float(sTime.text!)
        let end   = Float(eTime.text!)
        self.cropVideo(sourceURL1: url,startTime: start!,endTime: end!)
    }
}
extension ViewController:UIImagePickerControllerDelegate,UINavigationControllerDelegate,UITextFieldDelegate
{
    //Delegate method of image picker
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any])
    {
        picker.dismiss(animated: true, completion: nil)
        url = info[UIImagePickerControllerMediaURL] as! NSURL
        asset   = AVURLAsset.init(url: url as URL)
        
        thumbTime = asset.duration
        thumbtimeSeconds      = Int(CMTimeGetSeconds(thumbTime))
        
        self.viewAfterVideoIsPicked()
        
        let item:AVPlayerItem = AVPlayerItem(asset: asset)
        player                = AVPlayer(playerItem: item)
        playerLayer           = AVPlayerLayer(player: player)
        playerLayer.frame     = vidView.bounds
        
        playerLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        player.actionAtItemEnd   = AVPlayerActionAtItemEnd.none
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapOnvidView))
        self.vidView.addGestureRecognizer(tap)
        self.tapOnvidView(tap: tap)
        
        vidView.layer.addSublayer(playerLayer)
        player.play()
        
    }
    
    func viewAfterVideoIsPicked()
    {
        //Rmoving player if alredy exists
        if(playerLayer != nil)
        {
            playerLayer.removeFromSuperlayer()
        }
        
        self.createImageFrames()
        isSliderEnd = true
        sTime.text! = "\(0.0)"
        eTime.text   = "\(thumbtimeSeconds!)"
        self.createRangeSlider()
    }
    
    //Tap action on video player
    @objc func tapOnvidView(tap: UITapGestureRecognizer)
    {
        if isPlaying
        {
            self.player.play()
        }
        else
        {
            self.player.pause()
        }
        isPlaying = !isPlaying
    }
    
    
    
    //MARK: CreatingFrameImages
    func createImageFrames()
    {
        //creating assets
        let assetImgGenerate : AVAssetImageGenerator    = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        assetImgGenerate.requestedTimeToleranceAfter    = kCMTimeZero;
        assetImgGenerate.requestedTimeToleranceBefore   = kCMTimeZero;
        
        
        assetImgGenerate.appliesPreferredTrackTransform = true
        let thumbTime: CMTime = asset.duration
        let thumbtimeSeconds  = Int(CMTimeGetSeconds(thumbTime))
        let maxLength         = "\(thumbtimeSeconds)" as NSString
        
        let thumbAvg  = thumbtimeSeconds/6
        var startTime = 1
        var startXPosition:CGFloat = 0.0
        
        //loop for 6 number of frames
        for _ in 0...5
        {
            
            let imageButton = UIButton()
            let xPositionForEach = CGFloat(self.slideView.frame.width)/6
            imageButton.frame = CGRect(x: CGFloat(startXPosition), y: CGFloat(0), width: xPositionForEach, height: CGFloat(self.slideView.frame.height))
            do {
                let time:CMTime = CMTimeMakeWithSeconds(Float64(startTime),Int32(maxLength.length))
                let img = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
                let image = UIImage(cgImage: img)
                imageButton.setImage(image, for: .normal)
            }
            catch
                _ as NSError
            {
                print("Image generation failed with error (error)")
            }
            
            startXPosition = startXPosition + xPositionForEach
            startTime = startTime + thumbAvg
            imageButton.isUserInteractionEnabled = false
            slideView.addSubview(imageButton)
        }
        
    }
    //Create range slider
    func createRangeSlider()
    {
        //Remove slider if already present
        let subViews = self.slideView.subviews
        for subview in subViews{
            if subview.tag == 1000 {
                subview.removeFromSuperview()
            }
        }
        
        rangeSlider = RangeSlider(frame: slideView.bounds)
        slideView.addSubview(rangeSlider)
        rangeSlider.tag = 1000
        
        //Range slider action
        rangeSlider.addTarget(self, action: #selector(ViewController.rangeSliderValueChanged(_:)), for: .valueChanged)
        
        let time = DispatchTime.now() + Double(Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: time) {
            self.rangeSlider.trackHighlightTintColor = UIColor.clear
            self.rangeSlider.curvaceousness = 1.0
        }
        
    }
    //MARK: rangeSlider Delegate
    @objc func rangeSliderValueChanged(_ rangeSlider: RangeSlider) {
        self.player.pause()
        
        if(isSliderEnd == true)
        {
            rangeSlider.minimumValue = 0.0
            rangeSlider.maximumValue = Double(thumbtimeSeconds)
            
            rangeSlider.upperValue = Double(thumbtimeSeconds)
            isSliderEnd = !isSliderEnd
            
        }
        
        sTime.text = "\(rangeSlider.lowerValue)"
        eTime.text   = "\(rangeSlider.upperValue)"
        
        print(rangeSlider.lowerLayerSelected)
        if(rangeSlider.lowerLayerSelected)
        {
            self.seekVideo(toPos: CGFloat(rangeSlider.lowerValue))
            
        }
        else
        {
            self.seekVideo(toPos: CGFloat(rangeSlider.upperValue))
            
        }
        
        print(startTime)
    }
    //MARK: TextField Delegates
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool
    {
        let maxLength     = 3
        let currentString = sTime.text! as NSString
        let newString     = currentString.replacingCharacters(in: range, with: string) as NSString
        return newString.length <= maxLength
    }
    //Seek video when slide
    func seekVideo(toPos pos: CGFloat) {
        self.videoPlaybackPosition = pos
        let time: CMTime = CMTimeMakeWithSeconds(Float64(self.videoPlaybackPosition), self.player.currentTime().timescale)
        self.player.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        
        if(pos == CGFloat(thumbtimeSeconds))
        {
            self.player.pause()
        }
    }
    //Trim Video Function
    func cropVideo(sourceURL1: NSURL, startTime:Float, endTime:Float)
    {
        let manager                 = FileManager.default
        guard let documentDirectory = try? manager.url(for: .documentDirectory,in: .userDomainMask,appropriateFor: nil,create: true) else {return}
        guard let mediaType         = "mp4" as? String else {return}
        guard (sourceURL1 as? NSURL) != nil else {return}
        
        if mediaType == kUTTypeMovie as String || mediaType == "mp4" as String
        {
            let length = Float(asset.duration.value) / Float(asset.duration.timescale)
            print("video length: \(length) seconds")
            
            let start = startTime
            let end = endTime
            print(documentDirectory)
            var outputURL = documentDirectory.appendingPathComponent("output")
            do {
                try manager.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
                //let name = hostent.newName()
                outputURL = outputURL.appendingPathComponent("1.mp4")
            }catch let error {
                print(error)
            }
            _ = try? manager.removeItem(at: outputURL)
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {return}
            exportSession.outputURL = outputURL
            exportSession.outputFileType = AVFileType.mp4
            
            let startTime = CMTime(seconds: Double(start ), preferredTimescale: 1000)
            let endTime = CMTime(seconds: Double(end ), preferredTimescale: 1000)
            let timeRange = CMTimeRange(start: startTime, end: endTime)
            
            exportSession.timeRange = timeRange
            exportSession.exportAsynchronously{
                switch exportSession.status {
                case .completed:
                    print("exported at \(outputURL)")
                    self.saveToCameraRoll(URL: outputURL as NSURL!)
                case .failed:
                    print("failed \(String(describing: exportSession.error))")
                    
                case .cancelled:
                    print("cancelled \(String(describing: exportSession.error))")
                    
                default: break
                }}}}
    
    //Save Video to Photos Library
    func saveToCameraRoll(URL: NSURL!) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL as URL)
        }) { saved, error in
            if saved {
                let alertController = UIAlertController(title: "Cropped video was successfully saved", message: nil, preferredStyle: .alert)
                let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(defaultAction)
                self.present(alertController, animated: true, completion: nil)
            }}}
}
