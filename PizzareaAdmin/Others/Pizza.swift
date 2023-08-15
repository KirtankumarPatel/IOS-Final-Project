//
//  Pizza.swift
//  PizzareaAdmin
//
//  Created by Kirtankumar Patel, Hemal Patel on 11/08/2023.

// 

import UIKit

struct Pizza {
    let id: String
    let name: String
    let description: String
    let amount: Float
    let image: UIImage
    
    init(data: [String: Any]) {
        self.id = data["id"] as! String
        self.name = data["name"] as! String
        self.amount = data["amount"] as! Float
        self.description = data["description"] as! String
        self.image = data["image"] as! UIImage
    }
}

