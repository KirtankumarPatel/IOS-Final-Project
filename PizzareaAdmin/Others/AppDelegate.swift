//
//  AppDelegate.swift
//  Pizzarea Admin
//
//  Created by Kirtankumar Patel /Hemal Patel on 10/08/2023.

//

import UIKit
import PushNotifications

class AppConstants {
    static let APIURL = "http://127.0.0.1:4000"
}


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    let pushNotifications = PushNotifications.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        self.pushNotifications.start(instanceId: "PUSH_NOTIFICATIONS_INSTANCE_ID")
        self.pushNotifications.registerForRemoteNotifications()
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        self.pushNotifications.registerDeviceToken(deviceToken) {
            try? self.pushNotifications.subscribe(interest: "orders")
        }
    }
}

