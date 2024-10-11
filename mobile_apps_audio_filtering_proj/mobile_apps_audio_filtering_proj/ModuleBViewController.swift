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
    
    private var previousFrequency: Float = 0.0
    private var currentFrequency: Float = 0.0
    
    
//    //adding this #6
//    private var frequencyBuffer: [Float] = []
//    private let bufferSize = 5
//    private var gestureThreshold: Float = 3.0
//    private var previousSmoothedFrequency: Float = 0.0
//    //end of #6
    
    
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
        
        //adding this #3
        
        startMicrophoneProcessing()
        audio.startMicrophoneProcessing(withFps: 20) // preferred number of FFT calculations per second
        
        audio.play()
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateGraph()
        }
        //end of #3
        
        hzSlider.addTarget(self,action:#selector(self.sliderValueChanged(_:)),for:UIControl.Event.valueChanged)
        
        //startProcessingSinewaveForPlayback()
        
        
        //audio.startMicrophoneProcessing()
                    
    }
    
    //adding this #4
//    func updateGraph(){
//        
//        if let graph = self.graph{
//            graph.updateGraph(
//                data: self.audio.fftData,
//                forKey: "fft"
//            )
//            
//            let zoomArray:[Float] = Array.init(self.audio.fftData[20...])
//            graph.updateGraph(
//                data: zoomArray,
//                forKey: "fftZoomed"
//            )
//        }
//    } //end of #4
//    func updateGraph() {
//        if let graph = self.graph {
//            // Update the main FFT graph (in dB)
//            graph.updateGraph(
//                data: self.audio.fftData,
//                forKey: "fft"
//            )
//
//            let zoomArray: [Float] = Array(self.audio.fftData[20...])
//            //let zoomArray: [Float] = Array(self.audio.fftData[20...80])
//            //let zoomArray: [Float] = Array(self.audio.fftData[20...150])
////            let startIdx:Int = 30 + AudioConstants.AUDIO_BUFFER_SIZE/audio.samplingRate
////            let subArray:[Float] = Array(self.audio.fftData[startIdx...startIdx+300])
//            graph.updateGraph(
//                data: zoomArray,
//                //data: subArray,
//                forKey: "fftZoomed"
//            )
//        }
//    } //end of #4
    
    func updateGraph() {
        if let graph = self.graph {
            // Update the main FFT graph (this is the full range graph)
            graph.updateGraph(
                data: self.audio.fftData,
                forKey: "fft"
            )

            // Find the peak in the FFT data for the zoomed-in graph
            let fftData = self.audio.fftData
            guard !fftData.isEmpty else { return }

            // Define the range to search for peaks (e.g., skip first 20 low frequencies)
            let searchRange = 20..<fftData.count
            
            // Find the index of the maximum peak in the FFT data within the search range
            let peakIndex = fftData[searchRange].enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
            let adjustedPeakIndex = peakIndex + searchRange.lowerBound // Adjust for offset

            // Define a window size to focus on around the peak
            let windowSize = 200 // Can be adjusted depending on how much data to show
            let halfWindowSize = windowSize / 2
            
            // Calculate the range around the peak, making sure it stays within bounds
            let startIdx = max(0, adjustedPeakIndex - halfWindowSize)
            let endIdx = min(fftData.count - 1, adjustedPeakIndex + halfWindowSize)
            let subArray = Array(fftData[startIdx...endIdx])

            // Update the zoomed-in graph (this should be the lower graph)
            graph.updateGraph(
                data: subArray,
                forKey: "fftZoomed" 
            )
        }
    }
    
    
    //adding this #5
    override func viewWillAppear(_ animated: Bool) {
        print("Audio playing/resumed")
        super.viewWillAppear(animated)
        self.audio.play() // Call play function here
    } //end of #5
    
    @IBAction func sliderValueChanged(_ sender: Any){
        let sineFrequency = 17000 + (3000 * hzSlider.value)
        startProcessingSinewaveForPlayback(withFreq: sineFrequency)
    }
    
    func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
        let sampleRate: Float = 44100.0
            phaseIncrement = (2.0 * .pi * withFreq) / sampleRate
    
            if let manager = self.audioManager{
                // swift sine wave loop creation
                manager.outputBlock = self.handleSpeakerQueryWithSinusoid
                manager.play()
            }
            
        }
    
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
                            
        }
    }
    
    private func startMicrophoneProcessing() {
            audioManager?.inputBlock = { [weak self] data, numFrames, numChannels in
                self?.processMicrophoneInput(data: data, numFrames: numFrames, numChannels: numChannels)
            }
        }
    
    private func processMicrophoneInput(data: UnsafeMutablePointer<Float>?, numFrames: UInt32, numChannels: UInt32) {
            guard let data = data else { return }
            
            // Perform FFT on the incoming audio data to get frequency spectrum
            let fftData = performFFT(on: data, with: numFrames)
            
            // Analyze the frequency data to detect shifts
            currentFrequency = analyzeFrequencyData(fftData)
        
//            //adding this #7
//            updateFrequencyBuffer(with: currentFrequency)
//            let smoothedFrequency = calculateSmoothedFrequency()
//            //end of #7
            
            // Use the detected frequency to determine gesture direction
            recognizeGesture(currentFrequency)
    }
                        /*private func recognizeGesture(_ frequency: Float) {
                                let frequencyDifference = frequency - previousFrequency

                                // Adjust the threshold to a smaller value for testing
                                let threshold: Float = 1.0 // Test with a smaller threshold
                                
                                // Print frequency values for debugging
                                print("Current Frequency: \(frequency), Previous Frequency: \(previousFrequency), Difference: \(frequencyDifference)")

                                // Use the adjusted threshold
                                if abs(frequencyDifference) < threshold {
                                    DispatchQueue.main.async {
                                        self.gestureLabel.text = "Gesture Detected: No Movement"
                                    }
                                    return // Ignore small changes
                                }

                                var gestureText = ""
                                if frequencyDifference > 0 {
                                    gestureText = "Gesture Detected: Moving Towards"
                                } else if frequencyDifference < 0 {
                                    gestureText = "Gesture Detected: Moving Away"
                                }

                                DispatchQueue.main.async {
                                    self.gestureLabel.text = gestureText
                                }

                                // Update previous frequency for next analysis
                                previousFrequency = frequency
                            }

                            // Update processMicrophoneInput to call recognizeGesture with smoothed frequency
                            private func processMicrophoneInput(data: UnsafeMutablePointer<Float>?, numFrames: UInt32, numChannels: UInt32) {
                                guard let data = data else { return }
                                
                                // Perform FFT on the incoming audio data to get frequency spectrum
                                let fftData = performFFT(on: data, with: numFrames)
                                
                                // Analyze the frequency data to detect shifts
                                currentFrequency = analyzeFrequencyData(fftData)
                                
                                // Update the frequency buffer and calculate the smoothed frequency
                                updateFrequencyBuffer(with: currentFrequency)
                                let smoothedFrequency = calculateSmoothedFrequency()
                                
                                // Use the detected frequency to determine gesture direction
                                recognizeGesture(smoothedFrequency) // Pass the smoothed frequency
                            }*/
    //hereeee
//    private func processMicrophoneInput(data: UnsafeMutablePointer<Float>?, numFrames: UInt32, numChannels: UInt32) {
//        guard let data = data else { return }
//        
//        // Perform FFT on the incoming audio data to get frequency spectrum
//        let fftData = performFFT(on: data, with: numFrames)
//        
//        // Analyze the frequency data to detect shifts
//        currentFrequency = analyzeFrequencyData(fftData)
//        
//        // Update the frequency buffer and calculate the smoothed frequency
//        updateFrequencyBuffer(with: currentFrequency)
//        let smoothedFrequency = calculateSmoothedFrequency()
//        
//        // Use the detected frequency to determine gesture direction
//        recognizeGesture(smoothedFrequency)
//    }
    
//    //adding this #8
//    private func updateFrequencyBuffer(with frequency: Float) {
//            frequencyBuffer.append(frequency)
//            
//            // Keep the buffer at a fixed size
//            if frequencyBuffer.count > bufferSize {
//                frequencyBuffer.removeFirst()
//            }
//    } //end of #8
//    
//    //adding this #9
//    private func calculateSmoothedFrequency() -> Float {
//            // Calculate the moving average of the buffer
//            let sum = frequencyBuffer.reduce(0, +)
//            let smoothedFrequency = sum / Float(frequencyBuffer.count)
//            
//            return smoothedFrequency
//    } //end of #9
    
    
    
    
    private func performFFT(on data: UnsafeMutablePointer<Float>, with numFrames: UInt32) -> [Float] {
        // Create an FFT setup
        let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(numFrames))), FFTRadix(kFFTRadix2))

        // Allocate memory for real and imaginary parts
        let realp = UnsafeMutablePointer<Float>.allocate(capacity: Int(numFrames))
        let imagp = UnsafeMutablePointer<Float>.allocate(capacity: Int(numFrames))

        var splitComplex = DSPSplitComplex(realp: realp, imagp: imagp)

        // Perform the FFT
        vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(data)), 2, &splitComplex, 1, vDSP_Length(numFrames / 2))
        vDSP_fft_zrip(fftSetup!, &splitComplex, 1, vDSP_Length(log2(Float(numFrames))), FFTDirection(FFT_FORWARD))

        // Calculate the magnitude
        var magnitudes = [Float](repeating: 0.0, count: Int(numFrames / 2))
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(numFrames / 2))

        // Convert magnitudes to dB scale
        var magnitudesInDB = [Float](repeating: 0.0, count: Int(numFrames / 2))
        var zeroDBReference: Float = 1.0 // reference value for converting to dB
        vDSP_vdbcon(magnitudes, 1, &zeroDBReference, &magnitudesInDB, 1, vDSP_Length(numFrames / 2), 1)

        // Clean up FFT setup and allocated memory
        vDSP_destroy_fftsetup(fftSetup)
        realp.deallocate()
        imagp.deallocate()

        return magnitudesInDB // Return the magnitudes in dB
    }
    
//    private func performFFT(on data: UnsafeMutablePointer<Float>, with numFrames: UInt32) -> [Float] {
//        // Create an FFT setup
//        let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(numFrames))), FFTRadix(kFFTRadix2))
//        
//        // Allocate memory for real and imaginary parts
//        let realp = UnsafeMutablePointer<Float>.allocate(capacity: Int(numFrames))
//        let imagp = UnsafeMutablePointer<Float>.allocate(capacity: Int(numFrames))
//        
//        var splitComplex = DSPSplitComplex(realp: realp, imagp: imagp)
//        
//        // Perform the FFT
//        vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(data)), 2, &splitComplex, 1, vDSP_Length(numFrames / 2))
//        vDSP_fft_zrip(fftSetup!, &splitComplex, 1, vDSP_Length(log2(Float(numFrames))), FFTDirection(FFT_FORWARD))
//        
//        // Calculate the magnitude
//        var magnitudes = [Float](repeating: 0.0, count: Int(numFrames / 2))
//        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(numFrames / 2))
//        
//        // Clean up FFT setup and allocated memory
//        vDSP_destroy_fftsetup(fftSetup)
//        realp.deallocate()  // Free the allocated memory for realp
//        imagp.deallocate()  // Free the allocated memory for imagp
//        
//        return magnitudes
//    } COMMENTED THIS OUTTTTTTTT

    private func analyzeFrequencyData(_ fftData: [Float]) -> Float {
        // Find the index of the peak magnitude
        guard let peakIndex = fftData.enumerated().max(by: { $0.element < $1.element })?.offset else {
            return 0.0
        }
        
        // Calculate the corresponding frequency
        let sampleRate: Float = 44100.0 // Your sample rate
        let frequency = Float(peakIndex) * (sampleRate / Float(fftData.count))
        
        return frequency
    }
    
    
    //added here
//    private func processMicrophoneInput(data: UnsafeMutablePointer<Float>?, numFrames: UInt32, numChannels: UInt32) {
//        guard let data = data else { return }
//
//        print("Number of frames: \(numFrames)")
//        
//        // Perform FFT on microphone input
//        let fftData = performFFT(on: data, with: numFrames)
//
//        // Use the more sophisticated gesture detection from ModuleB
//        detectGesture(fftData)
//    }
//
//    // This is your new gesture detection function
//    private func detectGesture(_ fftData: [Float]) {
//        // Find the index of the peak magnitude
//        guard let maxIndex = fftData.firstIndex(of: fftData.max()!) else { return }
//        
//        // Calculate the corresponding frequency of the peak
//        let peakFrequency = frequencyFromIndex(maxIndex)
//
//        // Define the range for the band-pass filter
//        let bandWidth: Float = 1000.0 // Adjust as needed
//        let lowerFrequencyBound = max(0, peakFrequency - bandWidth / 2)
//        let upperFrequencyBound = min(Float(audio.samplingRate) / 2, peakFrequency + bandWidth / 2)
//
//        // Create a filtered magnitudes array
//        var filteredMagnitudes = [Float](repeating: 0.0, count: fftData.count)
//
//        // Apply the band-pass filter
//        for index in 0..<fftData.count {
//            let frequency = frequencyFromIndex(index)
//            if frequency >= lowerFrequencyBound && frequency <= upperFrequencyBound {
//                filteredMagnitudes[index] = fftData[index]
//            } else {
//                filteredMagnitudes[index] = 0.0 // Zero out frequencies outside the range
//            }
//        }
//
//        // Repeat peak detection on filtered magnitudes
//        guard let filteredMaxIndex = filteredMagnitudes.firstIndex(of: filteredMagnitudes.max()!) else { return }
//
//        // Define how many surrounding frequencies to check
//        let range: Int = 20
//        let filteredLowerBound = max(0, filteredMaxIndex - range)
//        let filteredUpperBound = min(filteredMagnitudes.count - 1, filteredMaxIndex + range)
//
//        // Get magnitudes for peak and surrounding frequencies
//        let peakMagnitude = filteredMagnitudes[filteredMaxIndex]
//
//        // Calculate average magnitudes for better sensitivity
//        let lowerMagnitudes = filteredMagnitudes[filteredLowerBound..<filteredMaxIndex]
//        let upperMagnitudes = filteredMagnitudes[(filteredMaxIndex + 1)...filteredUpperBound]
//
//        let averageLowerMagnitude = lowerMagnitudes.isEmpty ? 0 : lowerMagnitudes.reduce(0, +) / Float(lowerMagnitudes.count)
//        let averageUpperMagnitude = upperMagnitudes.isEmpty ? 0 : upperMagnitudes.reduce(0, +) / Float(upperMagnitudes.count)
//
//        let sensitivityFactor: Float = 10.0 // Adjust this to increase sensitivity
//
//        if averageLowerMagnitude > averageUpperMagnitude + sensitivityFactor {
//            DispatchQueue.main.async {
//                self.gestureLabel.text = "Gesture Detected: Moving Away"
//            }
//        } else if averageUpperMagnitude > averageLowerMagnitude + sensitivityFactor {
//            DispatchQueue.main.async {
//                self.gestureLabel.text = "Gesture Detected: Moving Towards"
//            }
//        } else {
//            DispatchQueue.main.async {
//                self.gestureLabel.text = "No Gesture Detected"
//            }
//        }
//    }
//
//    // Convert FFT index to actual frequency in Hz
//    private func frequencyFromIndex(_ index: Int) -> Float {
//        let nyquist = Float(audio.samplingRate) / 2.0 // Calculate Nyquist frequency
//        return Float(index) * nyquist / Float(AudioConstants.AUDIO_BUFFER_SIZE / 2) // Convert index to frequency
//    }

    private func recognizeGesture(_ frequency: Float) {
       let frequencyDifference = frequency - previousFrequency //frequency is smoothed frequency
       // let frequencyDifference = frequency - previousSmoothedFrequency
        
       // let threshold: Float = 0.5 // Set this value based on your needs
        let threshold: Float = 1.0

            // Ignore changes smaller than the threshold
            if abs(frequencyDifference) < threshold {
                return // Ignore small changes
            }

            var gestureText = ""
            if frequencyDifference > 0 {
                gestureText = "Gesture Detected: Moving Towards"
            } else if frequencyDifference < 0 {
                gestureText = "Gesture Detected: Moving Away"
            } else {
                gestureText = "Gesture Detected: No Movement"
            }

            DispatchQueue.main.async {
                self.gestureLabel.text = gestureText
            }

            // Update previous frequency for next analysis
            previousFrequency = frequency
        
//        // Ignore changes smaller than the gesture threshold
//                if abs(frequencyDifference) < gestureThreshold {
//                    DispatchQueue.main.async {
//                        self.gestureLabel.text = "Gesture Detected: No Movement"
//                    }
//                    return // No significant movement
//                }
//                
//                // Determine gesture direction based on frequency shift
//                var gestureText = ""
//                if frequencyDifference > 0 {
//                    gestureText = "Gesture Detected: Moving Towards"
//                } else if frequencyDifference < 0 {
//                    gestureText = "Gesture Detected: Moving Away"
//                }
//                
//                // Update the UI with detected gesture
//                DispatchQueue.main.async {
//                    self.gestureLabel.text = gestureText
//                }
//                
//                // Update the previous frequency for the next comparison
//                previousSmoothedFrequency = frequency
    }
    
    //HEREEEEE
//    private func recognizeGesture(_ frequency: Float) {
//        let frequencyDifference = frequency - previousFrequency
//
//        let threshold: Float = 50.0
//        
//        // Use the adjusted threshold
//        if abs(frequencyDifference) < threshold {
//            DispatchQueue.main.async {
//                self.gestureLabel.text = "Gesture Detected: No Movement"
//            }
//            return // Ignore small changes
//        }
//
//        var gestureText = ""
//        if frequencyDifference > 0 {
//            gestureText = "Gesture Detected: Moving Towards"
//        } else if frequencyDifference < 0 {
//            gestureText = "Gesture Detected: Moving Away"
//        }
//
//        DispatchQueue.main.async {
//            self.gestureLabel.text = gestureText
//        }
//
//        // Update previous frequency for next analysis
//        previousFrequency = frequency
//    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        audio.pause()
    }

//    private var frequencyBuffer: [Float] = []
//    private let bufferSize = 5
//
//    private func updateFrequencyBuffer(with frequency: Float) {
//        frequencyBuffer.append(frequency)
//        
//        // Keep the buffer at a fixed size
//        if frequencyBuffer.count > bufferSize {
//            frequencyBuffer.removeFirst()
//        }
//    }
//
//    private func calculateSmoothedFrequency() -> Float {
//        // Calculate the moving average of the buffer
//        let sum = frequencyBuffer.reduce(0, +)
//        let smoothedFrequency = sum / Float(frequencyBuffer.count)
//        
//        return smoothedFrequency
//    }
    
    
    
    
    /*
    
   

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


//ENDS HEREEEEEEEE




/*
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
     
     private let audio = AudioModel(buffer_size: AudioConstants.AUDIO_BUFFER_SIZE)
    
     private lazy var graph: MetalGraph? = {
             return MetalGraph(userView: self.userView)
         }()
     
     override func viewDidLoad() {
         super.viewDidLoad()
         self.view.backgroundColor = .white
         
         hzSlider.addTarget(self,action:#selector(self.sliderValueChanged(_:)),for:UIControl.Event.valueChanged)
                     
         if let graph = self.graph{
             graph.setBackgroundColor(r: 0, g: 0, b: 0, a: 1)
             
             // add in graphs for display
             // note that we need to normalize the scale of this graph
             // because the fft is returned in dB which has very large negative values and some large positive values
             
             // BONUS: lets also display a version of the FFT that is zoomed in
             graph.addGraph(withName: "fftZoomed",
                             shouldNormalizeForFFT: true,
                             numPointsInGraph: 300) // 300 points to display
             
             
             graph.addGraph(withName: "fft",
                             shouldNormalizeForFFT: true,
                             numPointsInGraph: AudioConstants.AUDIO_BUFFER_SIZE/2)
     
             
             graph.makeGrids() // add grids to graph
         }
         audio.startMicrophoneProcessing(withFps: 20)
         startProcessingSinewaveForPlayback(withFreq: 330.0) //need to set an initial frequency
         audio.play()

         
         Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
 //            DispatchQueue.main.async {
 //                    self.updateGraph()
 //                }
             self.updateGraph()
         }
          
     }
     
     @IBAction func sliderValueChanged(_ sender: Any){
         var sineFrequency = 17000 + (3000 * hzSlider.value)
         startProcessingSinewaveForPlayback(withFreq: sineFrequency)
     }
     
     func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
             var sineFrequency = withFreq
             phaseIncrement = (sineFrequency * 2 * Float.pi) / Float(audioManager?.samplingRate ?? 44100)
             if let manager = self.audioManager{
                 // swift sine wave loop creation
                 manager.outputBlock = self.handleSpeakerQueryWithSinusoid
             }
         }
  
     private var phase:Float = 0.0
     private var phaseIncrement:Float = 0.0
     private var sineWaveRepeatMax:Float = Float(2*Double.pi)
     private var previousFrequency: Float = 0.0 // added for gesture recognition
     
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


     func updateGraph() {
         print("FFT Data: \(audio.fftData)")
         
         if let graph = self.graph {
             graph.updateGraph(
                 data: self.audio.fftData,
                 forKey: "fft"
             )
             // BONUS: show the zoomed FFT
             // we can start at about 150Hz and show the next 300 points
             // actual Hz = f_0 * N/F_s
             let startIdx:Int = 150 * AudioConstants.AUDIO_BUFFER_SIZE/audio.samplingRate
             let subArray:[Float] = Array(self.audio.fftData[startIdx...startIdx+300])
             graph.updateGraph(
                 data: subArray,
                 forKey: "fftZoomed"
             )

             // Detect Doppler Shift
             let gesture = detectDopplerShift(fftData: audio.fftData)
             print("Detected gesture: \(gesture)")
         }
     }
     
     func detectDopplerShift(fftData: [Float]) -> String {
             let peakFrequency = findPeakFrequency(in: fftData)
             let gesture: String
             
             if peakFrequency > previousFrequency {
                 gesture = "Gesture Toward"
             } else if peakFrequency < previousFrequency {
                 gesture = "Gesture Away"
             } else {
                 gesture = "No Gesture"
             }
             
             previousFrequency = peakFrequency
             return gesture
         }
         
         func findPeakFrequency(in fftData: [Float]) -> Float {
             // Ensure there are enough data points for processing
                guard fftData.count > 0 else { return 0.0 }

                // Variable to hold the peak magnitude
                var maxMagnitude: Float = 0
                
                // Use vDSP_maxv to find the maximum value in fftData
                vDSP_maxv(fftData, 1, &maxMagnitude, vDSP_Length(fftData.count))
                
                // Find the index of the peak magnitude
                guard let maxIndex = fftData.firstIndex(of: maxMagnitude) else { return 0.0 }
                
                // Calculate the corresponding frequency
                let peakFrequency = Float(maxIndex) * Float(audioManager?.samplingRate ?? 44100.0) / Float(AudioConstants.AUDIO_BUFFER_SIZE)
                return peakFrequency
         }

     override func viewDidDisappear(_ animated: Bool) {
         super.viewDidDisappear(animated)
         audio.pause()
         //stop microphone processing? how?
     }
     
     
     
 }
 */
