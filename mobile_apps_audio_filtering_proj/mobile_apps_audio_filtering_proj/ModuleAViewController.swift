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
    
    @IBOutlet weak var vowelLabel: UILabel!
    
    var cur_hz_1: Double = 0.0
    var cur_hz_2: Double = 0.0
    var peak_1_index: Int = 0
    var vowelToggle: Int = 0
    
    var peak_sum: Float = 0.0
    var peak_count: Float = 0.0
    
    var harm_sum: Float = 0.0
    var harm_count: Float = 0.0
    
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph: MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    //toggles vowel recognition
    @IBAction func vowelToggle(_ sender: Any) {
        if(vowelToggle == 0){
            vowelToggle = 1
            self.vowelLabel.text = "Active"
        } else {
            vowelToggle = 0
            self.vowelLabel.text = "Inactive"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        var run_counter = 0
        
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
                if let label1 = self.freq1, let label2 = self.freq2, let label3 = self.vowelLabel {
                    label1.text = "Noise"
                    label2.text = "Noise"
                    if(self.vowelToggle == 1){
                        label3.text = "None Detected Yet (Noise)"
                    }
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

            graph.addGraph(withName: "time",
                           numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)

            graph.makeGrids()
        }
    }

    func updateGraph() {
        if let graph = self.graph {
            graph.updateGraph(data: audio.fftData, forKey: "fft")

            graph.updateGraph(data: audio.timeData, forKey: "time")
        }
    }
    
    func updateLabels() {
        if let label1 = self.freq1, let label2 = self.freq2 {
            self.calcTone(audio_data: audio.fftData)
            if(self.vowelToggle == 1){
                self.calcVowel(audio_data: audio.fftData, peak_index: peak_1_index)
            }
            let output_label_1 = String(Int(cur_hz_1))
            label1.text = output_label_1 + " Hz"
            let output_label_2 = String(Int(cur_hz_2))
            label2.text = output_label_2 + " Hz"
        }
    
    }
    

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        audio.pause()
    }
    
    func calcTone(audio_data: [Float]) {
        let data: [Float] = audio_data
        var window: [Float] = []
        var max_list: [Int: Int] = [:]
        var max_list_val: [Int: Float] = [:]
        let hz_per_index = 44100.0/Double(AudioConstants.AUDIO_BUFFER_SIZE)
        
        for i in 9...(data.count-6) {
            window = Array(data[(i)...(i)+5])

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
            if item.value >= 6{
                possible_peaks[item.key] = max_list_val[item.key]
            }
        }
        
        // Get first highest frequency from dict
        if let (key, _) = possible_peaks.max(by: { $0.value < $1.value }){
            cur_hz_1 = Double(key+1)*hz_per_index
            peak_1_index = key
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
    
    func calcVowel(audio_data: [Float], peak_index: Int) {
        let data: [Float] = audio_data
        let peak_value = data[peak_index]
        let harmonic_value = data[peak_index*2]
        let ratio_percent = harmonic_value/peak_value

        print("------------")
        self.peak_sum = self.peak_sum+peak_value
        self.peak_count = self.peak_count+1.0
        self.harm_sum = self.harm_sum+harmonic_value
        self.harm_count = self.harm_count+1.0
        print(peak_sum/peak_count)
        print(harm_sum/harm_count)
        
        
        
        
        print("Percent Ratio: "+String(ratio_percent)+" %")
//        if (ratio_percent > 0.10 && ratio_percent < 0.42) || (ratio_percent > 0.80 && ratio_percent < 1.00){
        if (ratio_percent > -1.2 && ratio_percent < 0.3){
//            print("OOOOOOOOOOO")
            vowelLabel.text = "OOOOOOOOOO"
        }
//        else if (ratio_percent > 0.42 && ratio_percent < 0.80) || (ratio_percent > 0.00 && ratio_percent < 0.10){
        else if (ratio_percent > 0.3 && ratio_percent < 1.2){
//            print("AAAAAAAAAA")
            vowelLabel.text = "AAAAAAAAAA"
        }
        
    }
    
}
