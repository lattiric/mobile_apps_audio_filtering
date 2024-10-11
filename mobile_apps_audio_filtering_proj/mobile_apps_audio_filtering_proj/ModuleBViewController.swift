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
           private var baselineLowerMagnitudes: [Float] = []
           private var baselineUpperMagnitudes: [Float] = []
           private var isBaselineCaptured = false
           private var baselineCaptureTime: Double = 3.0 // Capture baseline for 3 seconds
           private var baselineCaptureStart: Date?
           private var sensitivityFactor: Float = 2.0 // Adjust based on testing
       
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
               
               baselineCaptureStart = Date()
               
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
               if let graph = self.graph {
                   // Update the main FFT graph (in dB)
                   graph.updateGraph(
                       data: self.audio.fftData,
                       forKey: "fft"
                   )

                   let zoomArray: [Float] = Array(self.audio.fftData[20...])
                   //let zoomArray: [Float] = Array(self.audio.fftData[20...80])
                   //let zoomArray: [Float] = Array(self.audio.fftData[20...150])
                   graph.updateGraph(
                       data: zoomArray,
                       forKey: "fftZoomed"
                   )
               }
           } //end of #4
               
   //            override func viewDidLoad() {
   //                super.viewDidLoad()
   //                self.view.backgroundColor = .white
   //
   //                hzSlider.addTarget(self, action: #selector(self.sliderValueChanged(_:)), for: .valueChanged)
   //
   //                startMicrophoneProcessing()
   //                startProcessingSinewaveForPlayback(withFreq: emittedFrequency)
   //
   //                // Start capturing baseline
   //                baselineCaptureStart = Date()
   //            }
               
               @IBAction func sliderValueChanged(_ sender: Any) {
                   let emittedFrequency = 17000 + (3000 * hzSlider.value)
                   audio.startProcessingSinewaveForPlayback(withFreq: emittedFrequency)
               }
               
   //            func startProcessingSinewaveForPlayback(withFreq: Float = 330.0) {
   //                let sampleRate: Float = 44100.0
   //                phaseIncrement = (2.0 * .pi * withFreq) / sampleRate
   //
   //                if let manager = self.audioManager {
   //                    manager.outputBlock = self.handleSpeakerQueryWithSinusoid
   //                    manager.play()
   //                }
   //            }
   //
   //            private func handleSpeakerQueryWithSinusoid(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
   //                if let arrayData = data {
   //                    var i = 0
   //                    let chan = Int(numChannels)
   //                    let frame = Int(numFrames)
   //                    if chan == 1 {
   //                        while i < frame {
   //                            arrayData[i] = sin(phase)
   //                            phase += phaseIncrement
   //                            if phase >= sineWaveRepeatMax { phase -= sineWaveRepeatMax }
   //                            i += 1
   //                        }
   //                    } else if chan == 2 {
   //                        let len = frame * chan
   //                        while i < len {
   //                            arrayData[i] = sin(phase)
   //                            arrayData[i + 1] = arrayData[i]
   //                            phase += phaseIncrement
   //                            if phase >= sineWaveRepeatMax { phase -= sineWaveRepeatMax }
   //                            i += 2
   //                        }
   //                    }
   //                }
   //            }
   //
   //            private func startMicrophoneProcessing() {
   //                audioManager?.inputBlock = { [weak self] data, numFrames, numChannels in
   //                    self?.processMicrophoneInput(data: data, numFrames: numFrames, numChannels: numChannels)
   //                }
   //            }
               
               private func processMicrophoneInput(data: UnsafeMutablePointer<Float>?, numFrames: UInt32, numChannels: UInt32) {
                   guard let data = data else { return }
                   
                   // Perform FFT on microphone input
                   let fftData = performFFT(on: data, with: numFrames)
                   
                   // Analyze frequency and detect gesture
                   print("calling detectGesture")
                   detectGesture(fftData)
               }
               
               private func performFFT(on data: UnsafeMutablePointer<Float>, with numFrames: UInt32) -> [Float] {
                   let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(numFrames))), FFTRadix(kFFTRadix2))
                   
                   let realp = UnsafeMutablePointer<Float>.allocate(capacity: Int(numFrames))
                   let imagp = UnsafeMutablePointer<Float>.allocate(capacity: Int(numFrames))
                   var splitComplex = DSPSplitComplex(realp: realp, imagp: imagp)
                   
                   vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(data)), 2, &splitComplex, 1, vDSP_Length(numFrames / 2))
                   vDSP_fft_zrip(fftSetup!, &splitComplex, 1, vDSP_Length(log2(Float(numFrames))), FFTDirection(FFT_FORWARD))
                   
                   var magnitudes = [Float](repeating: 0.0, count: Int(numFrames / 2))
                   vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(numFrames / 2))
                   
                   vDSP_destroy_fftsetup(fftSetup)
                   realp.deallocate()
                   imagp.deallocate()
                   
                   return magnitudes
               }
               
               private var previousFFTData: [Float] = []
               
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

                       if (lowerAvg-upperAvg) > 7.0{
                           print("1")
                               self.gestureLabel.text = "Gesture Detected: Moving Away"
                       } else if(lowerAvg-upperAvg) < -7.0{
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
