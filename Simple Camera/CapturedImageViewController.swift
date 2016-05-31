//
//  CapturedImageViewController.swift
//  Simple Camera
//
//  Created by Jim Liang on 5/10/16.
//  Copyright © 2016 Jim. All rights reserved.
//

import UIKit

class CapturedImageViewController: UIViewController {

    
    @IBOutlet weak var capturedImageView: UIImageView!
    
    var capturedImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if capturedImage != nil {
            capturedImageView.image = capturedImage
        }

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
