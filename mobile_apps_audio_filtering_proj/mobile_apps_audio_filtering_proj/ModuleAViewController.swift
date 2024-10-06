//
//  ModuleAViewController.swift
//  mobile_apps_audio_filtering_proj
//
//  Created by Cameron Tofani on 10/5/24.
//

import UIKit
import Metal
import Accelerate

class ModuleAViewController: UIViewController {
    @IBOutlet weak var userView: UIView!
    
    struct AudioConstants {
        static let AUDIO_BUFFER_SIZE = 1024 * 4
    }
    @IBOutlet weak var freq1Label: UILabel!
    @IBOutlet weak var freq2Label: UILabel!
    
    @IBOutlet weak var freq1: UILabel!
    @IBOutlet weak var freq2: UILabel!
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        
        // graph and audio processing (taken from original push, just moved to modules)
        setupGraph()
        audio.startMicrophoneProcessing(withFps: 20)
        audio.play()

   
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
            self.updateLabels()
        }
    }

    func setupGraph() {
        if let graph = self.graph {
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)

            graph.addGraph(withName: "fft",
                           shouldNormalizeForFFT: true,
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE / 2)
//            graph.addGraph(withName: "fft_zoomed",
//                           shouldNormalizeForFFT: true,
//                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE / 20)
            graph.addGraph(withName: "time",
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
//            graph.addGraph(withName: "20 Pts Graph",
//                           shouldNormalizeForFFT: true,
//                           numPointsInGraph: 20)

            graph.makeGrids()
        }
    }

    func updateGraph() {
        if let graph = self.graph {
            graph.updateGraph(data: audio.fftData, forKey: "fft")

//            let zoomedArray: [Float] = Array(audio.fftData[20...])
//            graph.updateGraph(data: zoomedArray, forKey: "fft_zoomed")

            graph.updateGraph(data: audio.timeData, forKey: "time")

//            var avgdArray: [Float] = []
//            let chunkSize = audio.fftData.count / 20
//            for num in 0...(19) {
//                avgdArray.append(vDSP.maximum(audio.fftData[num * chunkSize...(num * chunkSize) + (chunkSize - 1)]))
//            }
//            graph.updateGraph(data: avgdArray, forKey: "20 Pts Graph")
        }
    }
    
    func updateLabels() {
        if let label1 = self.freq1 {
//            var output_label = calcTone(audio.fftData)
            var output_label = String(audio.fftData[0])
            label1.text = output_label + " Hz"
        }
        
        if let label2 = self.freq2 {
//            var output_label = calcTone(audio.fftData)
            var output_label = String(audio.fftData[0])
            label2.text = output_label + " Hz"
        }
    }
    

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        audio.pause()
    }
    
    func calcTone(audio_data: [Int]) {
        var data: [Int] = audio_data
    }
    
}
