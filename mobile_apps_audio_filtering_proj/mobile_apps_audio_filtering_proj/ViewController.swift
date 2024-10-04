//
//  ViewController.swift
//  mobile_apps_audio_filtering_proj
//
//  Created by Rick Lattin on 10/2/24.
//

import UIKit
import Metal
import Accelerate


// shivani test
class ViewController: UIViewController {
    
    //ALEX TEST

    @IBOutlet weak var userView: UIView!
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*4
    }
    
    // setup audio model
    let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(userView: self.userView)
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let graph = self.graph{
            graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
            
            // add in graphs for display
            // note that we need to normalize the scale of this graph
            // because the fft is returned in dB which has very large negative values and some large positive values
            
            
            graph.addGraph(withName: "fft",
                            shouldNormalizeForFFT: true,
                            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
            
            graph.addGraph(withName: "fft_zoomed",
                            shouldNormalizeForFFT: true,
                            numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/20)
            
            graph.addGraph(withName: "time",
                numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE)
            
            graph.addGraph(withName: "20 Pts Graph",
                           shouldNormalizeForFFT: true,
                           numPointsInGraph: 20)
            
            
            
            graph.makeGrids() // add grids to graph
        }
        
        // start up the audio model here, querying microphone
        audio.startMicrophoneProcessing(withFps: 20) // preferred number of FFT calculations per second

        audio.play()
        
        // run the loop for updating the graph peridocially
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
       
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        print("Paused lol")
        super.viewDidDisappear(animated)
        self.audio.pause()
    }
    
    // periodically, update the graph with refreshed FFT Data
    func updateGraph(){
        
        if let graph = self.graph{
            graph.updateGraph(
                data: self.audio.fftData,
                forKey: "fft"
            )
            
            let zoomedArray:[Float] = Array.init(self.audio.fftData[20...])
            graph.updateGraph(
                data: zoomedArray,
                forKey: "fft_zoomed"
            )
            
            graph.updateGraph(
                data: self.audio.timeData,
                forKey: "time"
            )

            var avgdArray: [Float] = Array.init()
            var chunkSize = self.audio.fftData.count/20
            for num in 0...(19){
                avgdArray.append(vDSP.maximum(self.audio.fftData[num*chunkSize...(num*chunkSize)+(chunkSize-1)]))
            }
            graph.updateGraph(
                data: avgdArray,
                forKey: "20 Pts Graph"
            )
            
        }
        
    }
    
    

}

