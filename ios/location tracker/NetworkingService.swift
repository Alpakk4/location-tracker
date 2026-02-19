//
//  NetworkService.swift
//  location tracker
//
//  Created by Alex Skondras on 09/02/2026.
//
import CoreLocation
class NetworkingService {
    static let shared = NetworkingService()
    private var last: Date?
    private let throttleQueue = DispatchQueue(label: "NetworkingService.throttle")
    private let defaults = UserDefaults.standard
    private let manager = CLLocationManager()
    
    var uid: String? {
        didSet {
            if uid == "" { uid = nil }
            if let uid {
                _ = SecureStore.setString(uid, for: .uid)
                defaults.set(uid, forKey: ConfigurationKeys.uid)
            } else {
                _ = SecureStore.remove(.uid)
                defaults.removeObject(forKey: ConfigurationKeys.uid)
            }
        }
    }
    
    private init() {
        let legacyUid = defaults.string(forKey: ConfigurationKeys.legacyUid)
        let defaultUid = defaults.string(forKey: ConfigurationKeys.uid)
        self.uid = SecureStore.getString(for: .uid) ?? defaultUid ?? legacyUid
        if let uid = self.uid {
            _ = SecureStore.setString(uid, for: .uid)
            defaults.set(uid, forKey: ConfigurationKeys.uid)
            defaults.removeObject(forKey: ConfigurationKeys.legacyUid)
        }
    }
    
    func sendLocation(_ location: CLLocation, activity: String, confidence: String, force: Bool = false) {
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            return
        }

        throttleQueue.async { [weak self] in
            guard let self = self else { return }
            #if DEBUG
            print("sending location. Activity State \(activity) (\(confidence))\(force ? " [FORCED]" : "")")
            #endif

            if !force {
                let interval: TimeInterval = {
                    switch activity {
                    case "WALKING":    return 120  // 2 mins
                    case "CYCLING":    return 420  // 7 mins
                    case "AUTOMOTIVE": return 600  // 10 mins
                    case "STILL":      return 1800 // 30 mins
                    default:           return 300  // 5 mins default
                    }
                }()

                if let l: Date = self.last {
                    if (l + interval) > Date.now {
                        #if DEBUG
                        print("Cancelling: \(interval/60) minute limit for \(activity) not yet reached")
                        #endif
                        return
                    }
                }
            }
            self.last = Date.now

            guard let url = self.endpointURL(path: "ping") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer "+Environment.apikey, forHTTPHeaderField: "Authorization")
            req.setValue(Environment.apikey, forHTTPHeaderField: "apikey")
            let isHomeSet = self.defaults.bool(forKey: ConfigurationKeys.isHomeSet)
            let homeLat = isHomeSet ? SecureStore.getDouble(for: .homeLatitude) : nil
            let homeLong = isHomeSet ? SecureStore.getDouble(for: .homeLongitude) : nil

            do {
                req.httpBody = try JSONEncoder().encode(RequestPayload(uid: self.uid ?? ConfigurationDefaults.anonymousUid,
                   lat: location.coordinate.latitude,
                   long: location.coordinate.longitude,
                   home_lat: homeLat,
                   home_long: homeLong,
                   motion: MotionType(motion: activity, confidence: confidence),
                   horizontal_accuracy: location.horizontalAccuracy))
            } catch {
                #if DEBUG
                print("json encoding failed", error)
                #endif
                return
            }

            self.send(req, retriesRemaining: 1)
        }
    }

    private func endpointURL(path: String) -> URL? {
        let endpoint = Environment.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpoint.isEmpty else { return nil }
        let base = endpoint.hasSuffix("/") ? endpoint : "\(endpoint)/"
        return URL(string: "\(base)\(path)")
    }

    private func send(_ request: URLRequest, retriesRemaining: Int) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                #if DEBUG
                print("ping failed: \(error.localizedDescription)")
                #endif
                if retriesRemaining > 0 {
                    self.send(request, retriesRemaining: retriesRemaining - 1)
                }
                return
            }

            if let http = response as? HTTPURLResponse {
                #if DEBUG
                print("status", http.statusCode)
                #endif
                if http.statusCode >= 500 && retriesRemaining > 0 {
                    self.send(request, retriesRemaining: retriesRemaining - 1)
                    return
                }
            }

            guard let data = data else { return }
            #if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                print(body)
            }
            #endif
        }.resume()
    }
}
