//
//  OrderViewController.swift
//  pizzarea
//
//  Created by Kirtankumar Patel,Hemal Patel on 09/08/2023.


import UIKit

class OrderViewController: UIViewController {
    
    var order: Order?
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var activityView: ActivityIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = order?.pizza.name
        
        status.text = order?.status.rawValue

        activityView.startLoading()
        
        switch order!.status {
        case .pending:
            status.text = "Processing Order"
        case .accepted:
            status.text = "Preparing Order"
        case .dispatched:
            status.text = "Order is on its way!"
        case .delivered:
            status.text = "Order delivered"
            activityView.strokeColor = UIColor.green
            activityView.completeLoading(success: true)
        }
    }
}
