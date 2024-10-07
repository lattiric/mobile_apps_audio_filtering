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
        var run_counter = 0
        
        // graph and audio processing (taken from original push, just moved to modules)
        setupGraph()
        audio.startMicrophoneProcessing(withFps: 20)
        audio.play()

   
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
        Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { _ in
//            if(self.audio.timeData[0] > 0.037){
//                print(self.audio.timeData[0])
//            }
            if(self.audio.timeData[0] > 0.037){
                self.updateLabels()
                run_counter = 0
            } else if run_counter > 40{
                if let label1 = self.freq1, let label2 = self.freq2 {
                    label1.text = "Noise"
                    label2.text = "Noise"
                }
            } else {
                run_counter = run_counter+1
            }
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
            var output_label_1 = String(Int(cur_hz_1))
            label1.text = output_label_1 + " Hz"
            var output_label_2 = String(Int(cur_hz_2))
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
        var max_list_val: [Int: Float] = [:]
        var hz_per_index = 44100.0/Double(AudioConstants.AUDIO_BUFFER_SIZE)
        
        for i in 1...(data.count-5) {
            window = Array(data[(i)...(i)+4])

            if let win_max = window.max(){
                if let win_index = data.firstIndex(of: win_max){
                    
                    if let _ = max_list[win_index]{
                        max_list[win_index] = max_list[win_index]!+1
                        max_list_val[win_index] = win_max
                    }else {
                        max_list[win_index] = 1
                        max_list_val[win_index] = win_max
                    }
                }
            }
        }
        
        //populates all possible peaks
        var possible_peaks: [Int: Float] = [:]
        for item in max_list{
            if item.value >= 5{
                possible_peaks[item.key] = max_list_val[item.key]
            }
        }
        
//        print(max_list)
//        print("break")
//        print(possible_peaks)
        
        // Get first highest frequency from dict
        if let (key, _) = possible_peaks.max(by: { $0.value < $1.value }){
            cur_hz_1 = Double(key)*hz_per_index
//            print(String(key) + " " + String(cur_hz_1))
            possible_peaks.removeValue(forKey: key)
        } else {
            cur_hz_1 = Double(0.0)
        }
                
        // Get second highest frequency from dict
        if let (key, _) = possible_peaks.max(by: {  $0.value < $1.value }){
            cur_hz_2 = Double(key)*hz_per_index
//            print(key)
            
        } else {
            cur_hz_2 = Double(0.0)
        }

      
        
    }
    
}
