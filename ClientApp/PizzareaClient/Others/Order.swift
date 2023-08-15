//
//  Order.swift
//  pizzarea
//
//  Created by Kirtankumar Patel, Hemal Patel on 10/08/2023.


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
