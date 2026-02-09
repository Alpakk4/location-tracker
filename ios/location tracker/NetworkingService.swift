//
//  NetworkService.swift
//  location tracker
//
//  Created by Alex Skondras on 09/02/2026.
//
import CoreLocation
class NetworkingService {
    static let shared = NetworkingService()
    var last: Date?
    
    var apikey: String? {
        didSet {
            if apikey == "" { apikey = nil }
        }
    }
    var endpoint: String? {
        didSet {
            if endpoint == "" { endpoint = nil }
        }
    }
    var uid: String? {
        didSet {
            if uid == "" { uid = nil }
        }
    }
    
    func sendLocation(_ location: CLLocation, activity: String, confidence: String) {
        print("sending location. Activity State \(activity) (\(confidence))")
        
        let interval: TimeInterval = {
            switch activity {
            case "WALKING":    return 120  // 2 mins
            case "CYCLING":    return 420  // 7 mins
            case "AUTOMOTIVE": return 600  // 10 mins
            case "STILL":      return 1800 // 30 mins
            default:           return 300  // 5 mins default
            }
                }()
        
        if let l: Date = last {
            if (l + interval) > Date.now {
                print("Cancelling: \(interval/60) minute limit for \(activity) not yet reached")
                return
            }
        }
        last = Date.now
        
        guard let url = URL(string: Environment.endpoint + "ping") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer "+(apikey ?? Environment.apikey), forHTTPHeaderField: "Authorization")
        req.setValue(apikey ?? Environment.apikey, forHTTPHeaderField: "apikey")
        print(location.coordinate.latitude, location.coordinate.longitude)
        do {
            req.httpBody = try JSONEncoder().encode(RequestPayload(uid: uid ?? "anonymous",
           lat: location.coordinate.latitude,
           long: location.coordinate.longitude,
           home_lat: UserDefaults.standard.double(forKey: "home_lat"),
           home_long: UserDefaults.standard.double(forKey: "home_long"),
           motion: MotionType(motion: activity, confidence: confidence)))
        } catch {
            print("json encoding failed", error)
            return
        }
        
        
        let task = URLSession.shared.dataTask(with: req) {(data, response, error) in
            guard let data = data else { return }
            if let http = response as? HTTPURLResponse {
                print("status", http.statusCode)
            }
            print(String(data: data, encoding: .utf8)!)
        }
        task.resume()
    }
}
