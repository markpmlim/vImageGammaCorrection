//
//  ViewController.swift
//  vImageGammaCorrection
//
// Adjusting the Brightness and Contrast of an Image
//
//  Created by Mark Lim Pak Mun on 29/05/2024.
//  Copyright © 2024 com.incremental.innovation. All rights reserved.
//

import Cocoa
import Accelerate.vImage

class ViewController: NSViewController
{
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var linearControl: NSSegmentedControl!
    @IBOutlet var exponentialControl: NSSegmentedControl!
    @IBOutlet var linearCheckBox: NSButton!

    var gammaCorrectionEngine: GammaCorrectionEngine!

    override func viewDidLoad() {
        super.viewDidLoad()
        let nsImage = NSImage(named: "Food_4.JPG")
        exponentialControl.isEnabled = false
        gammaCorrectionEngine = GammaCorrectionEngine(image: nsImage!)
        guard let cgImage = gammaCorrectionEngine.outputImage
        else {
            fatalError("CGImage cannot be instantiated")
        }
        display(cgImage)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    // The tag values for the 4 segments are: 0..3
    @IBAction func linearControlClick(_ control: NSSegmentedControl)
    {
        let value = control.tag(forSegment: control.selectedSegment)
        // This assignment will trigger a call to the function getGammaCorrectedImage
        gammaCorrectionEngine.responseCurvePreset = GammaCorrectionEngine.presets[value]
        guard let cgImage = gammaCorrectionEngine.outputImage
        else {
            print("CGImage cannot be instantiated")
            return
        }
        display(cgImage)
    }

    // The tag values for the 3 segments are: 4..6
    @IBAction func exponentialControlClick(_ control: NSSegmentedControl)
    {
        let value = control.tag(forSegment: control.selectedSegment)
        // This assignment will trigger a call to the function getGammaCorrectedImage
        gammaCorrectionEngine.responseCurvePreset = GammaCorrectionEngine.presets[value]
        guard let cgImage = gammaCorrectionEngine.outputImage
        else {
            print("CGImage cannot be instantiated")
            return
        }
        display(cgImage)
    }

    /*
     To make it simple, we don't save the current selectedSegment of
     either NSSegmentedControl.
     Whenever there is a click on the check box, either the L1 or E1
     segment will be selected. That means the L1 or E1 preset is used.
     The original image will be displayed.
     */
    @IBAction func linearCheckbox(_ control: NSButton)
    {
        var tagValue: Int
        if control.state == .on {
            linearControl.isEnabled = true
            tagValue = linearControl.tag(forSegment: 0)
            linearControl.setSelected(true, forSegment: 0)
            exponentialControl.isEnabled = false
        }
        else {
            exponentialControl.isEnabled = true
            tagValue = exponentialControl.tag(forSegment: 0)
            exponentialControl.setSelected(true, forSegment: 0)
            linearControl.isEnabled = false
        }
        // L1 or E1 preset is selected. The `tagValue` is 0 or 4
        // This assignment will trigger a call to the function getGammaCorrectedImage
        gammaCorrectionEngine.responseCurvePreset = GammaCorrectionEngine.presets[tagValue]
        guard let cgImage = gammaCorrectionEngine.outputImage
        else {
            print("CGImage cannot be instantiated")
            return
        }
        display(cgImage)
    }

    func display(_ cgImage: CGImage)
    {
        let nsImage = NSImage(cgImage: cgImage, size: NSZeroSize)
        DispatchQueue.main.async {
            self.imageView.image = nsImage
        }
    }
}

