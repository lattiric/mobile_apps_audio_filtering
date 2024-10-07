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
    
    @IBOutlet weak var hzSlider: UISlider!
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
    }
    
    private lazy var audioManager:Novocaine? = {
            return Novocaine.audioManager()
        }()
    
    /*
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    */
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        
        hzSlider.addTarget(self,action:#selector(self.sliderValueChanged(_:)),for:UIControl.Event.valueChanged)
                    
        
        // graph and audio processing (taken from original push, just moved to modules)
        //setupGraph()
        //audio.startMicrophoneProcessing(withFps: 20)
        //audio.play()

        /*
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
         */
    }
    
    
    
    @IBAction func sliderValueChanged(_ sender: Any){
        var sineFrequency = 17000 + (3000 * hzSlider.value)
        startProcessingSinewaveForPlayback(withFreq: sineFrequency)
    }
    
    func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
            var sineFrequency = withFreq
            if let manager = self.audioManager{
                // swift sine wave loop creation
                manager.outputBlock = self.handleSpeakerQueryWithSinusoid
            }
        }
 
    
    
    private var phase:Float = 0.0
    private var phaseIncrement:Float = 0.0
    private var sineWaveRepeatMax:Float = Float(2*Double.pi)
    
    private func handleSpeakerQueryWithSinusoid(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        // while pretty fast, this loop is still not quite as fast as
        // writing the code in c, so I placed a function in Novocaine to do it for you
        // use setOutputBlockToPlaySineWave() in Novocaine
        // EDIT: fixed in 2023
        if let arrayData = data{
            var i = 0
            let chan = Int(numChannels)
            let frame = Int(numFrames)
            if chan==1{
                while i<frame{
                    arrayData[i] = sin(phase)
                    phase += phaseIncrement
                    if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                    i+=1
                }
            }else if chan==2{
                let len = frame*chan
                while i<len{
                    arrayData[i] = sin(phase)
                    arrayData[i+1] = arrayData[i]
                    phase += phaseIncrement
                    if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                    i+=2
                }
            }
            // adjust volume of audio file output
            //vDSP_vsmul(arrayData, 1, (0.5), arrayData, 1, vDSP_Length(numFrames*numChannels))
                            
        }
    }

    
    
    
    
    
    /*
    
    
    func setupGraph() {
        if let graph = self.graph {
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)

            graph.addGraph(withName: "fft",
                           shouldNormalizeForFFT: true,
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE / 2)
            graph.addGraph(withName: "fft_zoomed",
                           shouldNormalizeForFFT: true,
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE / 20)
            graph.addGraph(withName: "time",
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
            graph.addGraph(withName: "20 Pts Graph",
                           shouldNormalizeForFFT: true,
                           numPointsInGraph: 20)

            graph.makeGrids()
        }
    }

    func updateGraph() {
        if let graph = self.graph {
            graph.updateGraph(data: audio.fftData, forKey: "fft")

            let zoomedArray: [Float] = Array(audio.fftData[20...])
            graph.updateGraph(data: zoomedArray, forKey: "fft_zoomed")

            graph.updateGraph(data: audio.timeData, forKey: "time")

            var avgdArray: [Float] = []
            let chunkSize = audio.fftData.count / 20
            for num in 0...(19) {
                avgdArray.append(vDSP.maximum(audio.fftData[num * chunkSize...(num * chunkSize) + (chunkSize - 1)]))
            }
            graph.updateGraph(data: avgdArray, forKey: "20 Pts Graph")
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        audio.pause() 
    }
    
    
    */
}
