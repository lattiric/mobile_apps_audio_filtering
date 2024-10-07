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
    
    var cur_hz_1: Double = 0.0
    var cur_hz_2: Double = 0.0
    
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
        }
        Timer.scheduledTimer(withTimeInterval: 1.00, repeats: true) { _ in
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
        if let label1 = self.freq1, let label2 = self.freq2 {
            self.calcTone(audio_data: audio.fftData)
            var output_label_1 = String(cur_hz_1)
            label1.text = output_label_1 + " Hz"
            var output_label_2 = String(cur_hz_2)
            label2.text = output_label_2 + " Hz"
        }
    
    }
    

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        audio.pause()
    }
    
    func calcTone(audio_data: [Float]) {
        var data: [Float] = audio_data
        var window: [Float] = []
        
        var max_list: [Int: Int] = [:]
//        var one_max: Int = 0
        var num_runs: Int = data.count/50
        
        for i in 0...(data.count-50) {
            window = Array(data[(i)...(i)+49])

//            if let win_max = window.max(){
//                if !win_max.isNaN{
//                    print(win_max)
////                    one_max = Int(round(win_max))
//                } else {
//                    print("Max value is NaN for some reason????")
//                }
//            }
            //TODO: add these to dict to try and calc frequency
            var test_max = window.max()
            var test_index = data.firstIndex(of: test_max!)
            print("We find " + String(test_max!) + " at " + String(test_index!))
            
            
//            if let (index, winMax) = window.enumerated().max(by: { $0.element < $1.element}){
////                print(index)
//                if let max = max_list[index]{
//                               max_list[index] = max_list[index]!+1
//                           }else {
//                               max_list[index] = 1
//                           }
//                print("Max Ind count: " + String(max_list[index]!))
//            }
        }
        
        // Get first highest frequency from dict
        if let (key, value) = max_list.max(by: { $0.value < $1.value }){
            cur_hz_1 = Double(key)
            max_list[key] = 0
        } else {
            cur_hz_1 = Double(0.0)
        }
        
        // Get second highest frequency from dict
        if let (key, value) = max_list.max(by: { $0.value < $1.value }){
            cur_hz_2 = Double(key)
            max_list[key] = 0
        } else {
            cur_hz_2 = Double(0.0)
        }

      
        
    }
    
}
