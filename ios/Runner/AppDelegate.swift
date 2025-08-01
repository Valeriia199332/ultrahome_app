//
//  AppDelegate.swift
//  ultrahome_app
//
//  Created by Valeriia on 08/01/2025.
//

import UIKit
import Flutter
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    // Channel для установки куки из Flutter
    private var cookieChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Получаем FlutterViewController
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        // Инициализируем канал для куки
        cookieChannel = FlutterMethodChannel(
            name: "net.ultrahomeservices/cookie",
            binaryMessenger: controller.binaryMessenger
        )
        cookieChannel?.setMethodCallHandler(handleMethodCall)

        // Регистрируем плагины Flutter
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func handleMethodCall(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "setCookies":
            guard let args = call.arguments as? [String: Any],
                  let cookies = args["cookies"] as? [[String: String]]
            else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Expected a list of cookies",
                    details: nil
                ))
                return
            }
            setCookies(cookies: cookies, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setCookies(
        cookies: [[String: String]],
        result: @escaping FlutterResult
    ) {
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        let dispatchGroup = DispatchGroup()

        for cookieData in cookies {
            guard let name = cookieData["name"],
                  let value = cookieData["value"],
                  var domain = cookieData["domain"],
                  let path = cookieData["path"]
            else { continue }

            // Убираем ведущую точку в домене (для iOS)
            if domain.hasPrefix(".") {
                domain.removeFirst()
            }

            // Свойства куки
            var properties: [HTTPCookiePropertyKey: Any] = [
                .name: name,
                .value: value,
                .domain: domain,
                .path: path,
                .secure: "TRUE",  // обязательно для https
                .version: "0"
            ]

            // Если есть expires, парсим ISO8601
            if let expires = cookieData["expires"],
               let date = ISO8601DateFormatter().date(from: expires) {
                properties[.expires] = date
            }

            if let cookie = HTTPCookie(properties: properties) {
                dispatchGroup.enter()
                cookieStore.setCookie(cookie) {
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            result(true)
        }
    }
}
