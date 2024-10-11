//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    var volume:Float = 1
    
    // thse properties are for interfaceing with the API
    // the user can access these arrays at any time and plot them if they like
    var timeData:[Float]
    var fftData:[Float]
    lazy var samplingRate:Int = {
        return Int(self.audioManager!.samplingRate)
    }()
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
    }
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps:Double){
        // setup the microphone to copy to circualr buffer
        if let manager = self.audioManager{
            manager.inputBlock = self.handleMicrophone
//            manager.inputBlock = self.handleSpeakerQueryWithAudioFile
//            manager.outputBlock = self.handleSpeakerQueryWithAudioFile
            
            // repeat this fps times per second using the timer class
            //   every time this is called, we update the arrays "timeData" and "fftData"
            Timer.scheduledTimer(withTimeInterval: 1.0/withFps, repeats: true) { _ in
                self.runEveryInterval()
            }
            
        }
    }
    
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
//        if let manager = self.audioManager, let reader=self.fileReader{
//            manager.play()
//            reader.play()
//        }
        if let manager = self.audioManager{
            manager.play()
        }
    }
    
    func pause(){
//        if let manager = self.audioManager, let reader=self.fileReader{
//            manager.pause()
//            reader.pause()
//        }
        if let manager = self.audioManager{
            manager.pause()
        }
    }
    
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    private lazy var outputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    private lazy var fileReader: AudioFileReader? = {
        print("beats almost dropped")
        if let url = Bundle.main.url(forResource: "satisfaction", withExtension:"mp3"){
            var tmpFileReader:AudioFileReader? = AudioFileReader.init(audioFileURL: url, samplingRate: Float(audioManager!.samplingRate), numChannels: audioManager!.numOutputChannels)
            print("beats almost dropped")
            tmpFileReader!.currentTime = 0.0
            print("Audio file succesfully loaded for \(url)")
            return tmpFileReader
        }else{
            print("Could not initialize audio input file")
            return nil
        }
    }()
    
    
    
    //==========================================
    // MARK: Model Callback Methods
    private func runEveryInterval(){
        if inputBuffer != nil {
            // copy time data to swift array
            self.inputBuffer!.fetchFreshData(&timeData, // copied into this array
                                             withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData) // fft result is copied into fftData array
            
            // at this point, we have saved the data to the arrays:
            //   timeData: the raw audio samples
            //   fftData:  the FFT of those same samples
            // the user can now use these variables however they like
            
        }
    }
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    
    private func handleSpeakerQueryWithAudioFile(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
        if let file = self.fileReader{
            //read from file, loading into data (a float pointer)
            
            if let arrayData = data{
                file.retrieveFreshAudio(arrayData, numFrames: numFrames, numChannels: numChannels)
                
                if inputBuffer != nil {
                    self.inputBuffer?.addNewFloatData(arrayData, withNumSamples: Int64(numFrames))
                }
            }
            
        }
    }
    
    
    
    func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
            sineFrequency = withFreq
            if let manager = self.audioManager{
                // swift sine wave loop creation
                manager.outputBlock = self.handleSpeakerQueryWithSinusoid
            }
        }
    
    
    var sineFrequency:Float = 0.0 { // frequency in Hz (changeable by user)
            didSet{
                if let manager = self.audioManager {
                    // if using swift for generating the sine wave: when changed, we need to update our increment
                    phaseIncrement = Float(2*Double.pi*Double(sineFrequency)/manager.samplingRate)
                }
            }
        }
        
        // SWIFT SINE WAVE
        // everything below here is for the swift implementation
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
                vDSP_vsmul(arrayData, 1, &(self.volume), arrayData, 1, vDSP_Length(numFrames*numChannels))
                                
            }
        }

    
}



////
////  AudioModel.swift
////  AudioLabSwift
////
////  Created by Eric Larson 
////  Copyright © 2020 Eric Larson. All rights reserved.
////
//
//import Foundation
//import Accelerate
//
//class AudioModel {
//    
//    // MARK: Properties
//    private var BUFFER_SIZE:Int
//    var volume:Float = 1
//    
//    // thse properties are for interfaceing with the API
//    // the user can access these arrays at any time and plot them if they like
//    var timeData:[Float]
//    var fftData:[Float]
//    lazy var samplingRate:Int = {
//        return Int(self.audioManager!.samplingRate)
//    }()
//    
//    // MARK: Public Methods
//    init(buffer_size:Int) {
//        BUFFER_SIZE = buffer_size
//        // anything not lazily instatntiated should be allocated here
//        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
//        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
//    }
//    
//    // public function for starting processing of microphone data
//    func startMicrophoneProcessing(withFps:Double){
//        // setup the microphone to copy to circualr buffer
//        if let manager = self.audioManager{
//            manager.inputBlock = self.handleMicrophone
////            manager.inputBlock = self.handleSpeakerQueryWithAudioFile
////            manager.outputBlock = self.handleSpeakerQueryWithAudioFile
//            
//            // repeat this fps times per second using the timer class
//            //   every time this is called, we update the arrays "timeData" and "fftData"
//            Timer.scheduledTimer(withTimeInterval: 1.0/withFps, repeats: true) { _ in
//                self.runEveryInterval()
//            }
//            
//        }
//    }
//    
//    
//    // You must call this when you want the audio to start being handled by our model
//    func play(){
////        if let manager = self.audioManager, let reader=self.fileReader{
////            manager.play()
////            reader.play()
////        }
//        if let manager = self.audioManager{
//            manager.play()
//        }
//    }
//    
//    func pause(){
////        if let manager = self.audioManager, let reader=self.fileReader{
////            manager.pause()
////            reader.pause()
////        }
//        if let manager = self.audioManager{
//            manager.pause()
//        }
//    }
//    
//    
//    //==========================================
//    // MARK: Private Properties
//    private lazy var audioManager:Novocaine? = {
//        return Novocaine.audioManager()
//    }()
//    
//    private lazy var fftHelper:FFTHelper? = {
//        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
//    }()
//    
//    
//    private lazy var inputBuffer:CircularBuffer? = {
//        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
//                                   andBufferSize: Int64(BUFFER_SIZE))
//    }()
//    
//    private lazy var outputBuffer:CircularBuffer? = {
//        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
//                                   andBufferSize: Int64(BUFFER_SIZE))
//    }()
//    
//    
//    //==========================================
//    // MARK: Private Methods
//    private lazy var fileReader: AudioFileReader? = {
//        print("beats almost dropped")
//        if let url = Bundle.main.url(forResource: "satisfaction", withExtension:"mp3"){
//            var tmpFileReader:AudioFileReader? = AudioFileReader.init(audioFileURL: url, samplingRate: Float(audioManager!.samplingRate), numChannels: audioManager!.numOutputChannels)
//            print("beats almost dropped")
//            tmpFileReader!.currentTime = 0.0
//            print("Audio file succesfully loaded for \(url)")
//            return tmpFileReader
//        }else{
//            print("Could not initialize audio input file")
//            return nil
//        }
//    }()
//    
//    
//    
//    //==========================================
//    // MARK: Model Callback Methods
//    private func runEveryInterval(){
//        if inputBuffer != nil {
//            // copy time data to swift array
//            self.inputBuffer!.fetchFreshData(&timeData, // copied into this array
//                                             withNumSamples: Int64(BUFFER_SIZE))
//            
//            // now take FFT
//            fftHelper!.performForwardFFT(withData: &timeData,
//                                         andCopydBMagnitudeToBuffer: &fftData) // fft result is copied into fftData array
//            
//            // at this point, we have saved the data to the arrays:
//            //   timeData: the raw audio samples
//            //   fftData:  the FFT of those same samples
//            // the user can now use these variables however they like
//            
//        }
//    }
//    
//    //==========================================
//    // MARK: Audiocard Callbacks
//    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
//    // and in swift this translates to:
//    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
//        // copy samples from the microphone into circular buffer
//        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
//    }
//    
//    
//    private func handleSpeakerQueryWithAudioFile(data: Optional<UnsafeMutablePointer<Float>>, numFrames: UInt32, numChannels: UInt32) {
//        if let file = self.fileReader{
//            //read from file, loading into data (a float pointer)
//            
//            if let arrayData = data{
//                file.retrieveFreshAudio(arrayData, numFrames: numFrames, numChannels: numChannels)
//                
//                if inputBuffer != nil {
//                    self.inputBuffer?.addNewFloatData(arrayData, withNumSamples: Int64(numFrames))
//                }
//            }
//            
//        }
//    }
//    
//    
//    
//    func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
//            sineFrequency = withFreq
//            if let manager = self.audioManager{
//                // swift sine wave loop creation
//                manager.outputBlock = self.handleSpeakerQueryWithSinusoid
//            }
//        }
//    
//    
//    var sineFrequency:Float = 0.0 { // frequency in Hz (changeable by user)
//            didSet{
//                if let manager = self.audioManager {
//                    // if using swift for generating the sine wave: when changed, we need to update our increment
//                    phaseIncrement = Float(2*Double.pi*Double(sineFrequency)/manager.samplingRate)
//                }
//            }
//        }
//        
//        // SWIFT SINE WAVE
//        // everything below here is for the swift implementation
//        private var phase:Float = 0.0
//        private var phaseIncrement:Float = 0.0
//        private var sineWaveRepeatMax:Float = Float(2*Double.pi)
//    
//    private func handleSpeakerQueryWithSinusoid(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
//            // while pretty fast, this loop is still not quite as fast as
//            // writing the code in c, so I placed a function in Novocaine to do it for you
//            // use setOutputBlockToPlaySineWave() in Novocaine
//            // EDIT: fixed in 2023
//            if let arrayData = data{
//                var i = 0
//                let chan = Int(numChannels)
//                let frame = Int(numFrames)
//                if chan==1{
//                    while i<frame{
//                        arrayData[i] = sin(phase)
//                        phase += phaseIncrement
//                        if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
//                        i+=1
//                    }
//                }else if chan==2{
//                    let len = frame*chan
//                    while i<len{
//                        arrayData[i] = sin(phase)
//                        arrayData[i+1] = arrayData[i]
//                        phase += phaseIncrement
//                        if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
//                        i+=2
//                    }
//                }
//                // adjust volume of audio file output
//                vDSP_vsmul(arrayData, 1, &(self.volume), arrayData, 1, vDSP_Length(numFrames*numChannels))
//                                
//            }
//        }
//
//    
//}
