//
//  Order.swift
//  PizzareaAdmin
//
//  Created by KirtanKumar Patel, Hemal Patel on 11/08/20123.

//

import Foundation

struct Order {
    let id: String
    let pizza: Pizza
    var status: OrderStatus
}

enum OrderStatus: String {
    case pending = "Pending"
    case accepted = "Accepted"
    case dispatched = "Dispatched"
    case delivered = "Delivered"
}
