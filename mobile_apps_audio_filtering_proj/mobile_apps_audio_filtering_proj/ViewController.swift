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
    
    override func viewDidLoad() {
            super.viewDidLoad()
            self.view.backgroundColor = .white
            
        }

    @IBAction func goToModuleA(_ sender: UIButton) {
        performSegue(withIdentifier: "showModuleA", sender: self)
    }
    @IBAction func goToModuleB(_ sender: UIButton) {
        performSegue(withIdentifier: "showModuleB", sender: self)
    }
    
    @IBOutlet weak var userView: UIView!
    struct AudioConstants{
        static let AUDIO_BUFFER_SIZE = 1024*4
    }
    
   

}

