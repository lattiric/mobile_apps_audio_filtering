//
//  ModuleBViewController.swift
//  mobile_apps_audio_filtering_proj
//
//  Created by Cameron Tofani on 10/5/24.
//

import UIKit
import Metal
import Accelerate

class ModuleBViewController: UIViewController {
    @IBOutlet weak var userView: UIView!
    
    @IBOutlet weak var gestureLabel: UILabel!
    
    @IBOutlet weak var hzSlider: UISlider!
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
    }
    
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    
    private var phase:Float = 0.0
    private var phaseIncrement:Float = 0.0
    private var sineWaveRepeatMax:Float = Float(2*Double.pi)
    
    private var emittedFrequency: Float = 17000.0 // Default starting frequency
    
    
    //adding this #1
    lazy var graph:MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        
        //adding this #2
        if let graph = self.graph{
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            
            graph.addGraph(withName: "fft",
                           shouldNormalizeForFFT: true,
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
            
            graph.addGraph(withName: "fftZoomed",
                           shouldNormalizeForFFT: true,
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/20)
            
            
            
            graph.makeGrids()
            
        } //end of #2
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
            self.detectGesture(self.audio.fftData)
        }
        hzSlider.addTarget(self,action:#selector(self.sliderValueChanged(_:)),for:UIControl.Event.valueChanged)
        
        audio.startProcessingSinewaveForPlayback(withFreq: emittedFrequency)
        audio.startMicrophoneProcessing(withFps: 20) // preferred number of FFT calculations per second
        
        audio.play()
        
    }//end of viewdidload
    

    func updateGraph() {

       guard let maxIndex = self.audio.fftData.firstIndex(of: self.audio.fftData.max()!) else { return }

       let zoomRange: Int = 100 // Points to look back from the peak
       let totalPointsToZoom: Int = 300

       let startIdx = max(0, maxIndex - zoomRange)

       let endIdx = min(self.audio.fftData.count - 1, maxIndex + (totalPointsToZoom - zoomRange))



       let subArray: [Float] = Array(self.audio.fftData[startIdx...endIdx])

        //let zoomArrayFinal = subArray.map {20 * log10(abs($0)) }
        //let zoomArrayFinal = subArray.map {$0 + 1 }

           if let graph = self.graph {
               // Update the main FFT graph (in dB)
               graph.updateGraph(
                   data: self.audio.fftData,
                   forKey: "fft"
               )

               graph.updateGraph(
                           data: subArray,
                           forKey: "fftZoomed"
                       )


           }
       } //end of #4
    

    

    
    @IBAction func sliderValueChanged(_ sender: Any) {
        let emittedFrequency = 17000 + (3000 * hzSlider.value)
        audio.startProcessingSinewaveForPlayback(withFreq: emittedFrequency)
    }
    
    
    private func detectGesture(_ fftData: [Float]) {
        guard let maxIndex = fftData.firstIndex(of: fftData.max()!) else { return }
        
        let range = 20
        var lowerAvg = Float(0.0)
        var upperAvg = Float(0.0)
        
        if maxIndex > range{
            let lowerValsFft = Array(fftData[(maxIndex-range)..<maxIndex])
            let upperValsFft = Array(fftData[maxIndex..<(maxIndex+range)])
            
            lowerAvg = lowerValsFft.reduce(0, +) / Float(range)
            upperAvg = upperValsFft.reduce(0, +) / Float(range)
            
            //                    print("Lower: "+String(lowerAvg)+" Upper: "+String(upperAvg))
            print("Difference: " + String(lowerAvg-upperAvg))
        }
        
        if (lowerAvg-upperAvg) > 9.0{
            print("1")
            self.gestureLabel.text = "Gesture Detected: Moving Away"
        } else if(lowerAvg-upperAvg) < -9.0{
            print("2")
            self.gestureLabel.text = "Gesture Detected: Moving Towards"
        } else {
            print("3")
            self.gestureLabel.text = "No Gesture Detected"
        }
    }
    
    private func calculateAverageChange(currentMagnitudes: ArraySlice<Float>, baselineMagnitudes: [Float]) -> Float {
        let changes = zip(currentMagnitudes, baselineMagnitudes).map { (current, baseline) in
            return abs(current - baseline) / max(baseline, 0.1)
        }
        return changes.reduce(0, +) / Float(changes.count)
    }
    
    private func frequencyFromIndex(_ index: Int) -> Float {
        let nyquist = Float(audio.samplingRate) / 2.0
        return Float(index) * nyquist / Float(AudioConstants.AUDIO_BUFFER_SIZE / 2)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.audio.pause()
    }
    
}
