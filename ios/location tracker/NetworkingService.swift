//
//  NetworkService.swift
//  location tracker
//
//  Created by Alex Skondras on 09/02/2026.
//
import CoreLocation
class NetworkingService {
    static let shared = NetworkingService()
    private var lastPingTimes: [String: Date] = [:]
    private let throttleQueue = DispatchQueue(label: "NetworkingService.throttle")
    private let defaults = UserDefaults.standard
    private let manager = CLLocationManager()

    private static let retryDelays: [TimeInterval] = [60, 300, 900]
    private static let pendingPingsKey = "pendingPings"

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private struct PendingPing: Codable {
        let bodyData: Data
        let retryIndex: Int
    }

    var uid: String? {
        didSet {
            if uid == "" { uid = nil }
            if let uid {
                defaults.set(uid, forKey: ConfigurationKeys.uid)
            } else {
                defaults.removeObject(forKey: ConfigurationKeys.uid)
            }
        }
    }
    
    private init() {
        let defaultUid = defaults.string(forKey: ConfigurationKeys.uid)
        let legacyUid = defaults.string(forKey: ConfigurationKeys.legacyUid)

        // One-time migration: copy UID from Keychain to UserDefaults if needed
        if defaultUid == nil, let keychainUid = SecureStore.getString(for: .uid) {
            defaults.set(keychainUid, forKey: ConfigurationKeys.uid)
            self.uid = keychainUid
        } else {
            self.uid = defaultUid ?? legacyUid
        }

        if let uid = self.uid {
            defaults.set(uid, forKey: ConfigurationKeys.uid)
            defaults.removeObject(forKey: ConfigurationKeys.legacyUid)
        }
        processPendingPings()
    }

    static func throttleInterval(for activity: String) -> TimeInterval {
        switch activity {
        case "WALKING":    return 120
        case "RUNNING":    return 120
        case "CYCLING":    return 240
        case "AUTOMOTIVE": return 600
        case "STILL":      return 1200
        default:           return 300
        }
    }

    func sendLocation(_ location: CLLocation, activity: String, confidence: String, force: Bool = false) {
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            return
        }

        let capturedAt = Self.iso8601Formatter.string(from: Date())

        throttleQueue.async { [weak self] in
            guard let self = self else { return }
            #if DEBUG
            print("sending location. Activity State \(activity) (\(confidence))\(force ? " [FORCED]" : "")")
            #endif

            if !force {
                let interval = Self.throttleInterval(for: activity)
                if let lastPing = self.lastPingTimes[activity], (lastPing + interval) > Date.now {
                    #if DEBUG
                    print("Cancelling: \(interval/60) minute limit for \(activity) not yet reached")
                    #endif
                    return
                }
            }
            self.lastPingTimes[activity] = Date.now

            guard let url = self.endpointURL(path: "ping") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer "+Environment.apikey, forHTTPHeaderField: "Authorization")
            req.setValue(Environment.apikey, forHTTPHeaderField: "apikey")
            let isHomeSet = self.defaults.bool(forKey: ConfigurationKeys.isHomeSet)
            let homeLat = isHomeSet ? SecureStore.getDouble(for: .homeLatitude) : nil
            let homeLong = isHomeSet ? SecureStore.getDouble(for: .homeLongitude) : nil

            let bodyData: Data
            do {
                bodyData = try JSONEncoder().encode(RequestPayload(
                    uid: self.uid ?? ConfigurationDefaults.anonymousUid,
                    lat: location.coordinate.latitude,
                    long: location.coordinate.longitude,
                    home_lat: homeLat,
                    home_long: homeLong,
                    motion: MotionType(motion: activity, confidence: confidence),
                    horizontal_accuracy: location.horizontalAccuracy,
                    capturedAt: capturedAt))
                req.httpBody = bodyData
            } catch {
                #if DEBUG
                print("json encoding failed", error)
                #endif
                return
            }

            self.sendWithRetry(req, bodyData: bodyData, retryIndex: 0)
        }
    }

    func callBackfillReframeHome(homeLat: Double, homeLong: Double, completion: @escaping (Result<Int, Error>) -> Void) {
        guard let url = endpointURL(path: "backfill-reframe-home") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer " + Environment.apikey, forHTTPHeaderField: "Authorization")
        req.setValue(Environment.apikey, forHTTPHeaderField: "apikey")

        let body: [String: Any] = [
            "deviceId": uid ?? ConfigurationDefaults.anonymousUid,
            "user_home_lat": homeLat,
            "user_home_long": homeLong
        ]

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(URLError(.badServerResponse, userInfo: [
                    NSLocalizedDescriptionKey: "Backfill returned status \(code)"
                ])))
                return
            }

            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let updated = json["updated"] as? Int {
                completion(.success(updated))
            } else {
                completion(.success(0))
            }
        }.resume()
    }

    private func endpointURL(path: String) -> URL? {
        let endpoint = Environment.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpoint.isEmpty else { return nil }
        let base = endpoint.hasSuffix("/") ? endpoint : "\(endpoint)/"
        return URL(string: "\(base)\(path)")
    }

    // MARK: - Retry with exponential backoff

    private func sendWithRetry(_ request: URLRequest, bodyData: Data, retryIndex: Int) {
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            var failed = false
            if error != nil {
                failed = true
            } else if let http = response as? HTTPURLResponse, http.statusCode >= 500 {
                failed = true
            }

            #if DEBUG
            if let error {
                print("ping failed: \(error.localizedDescription)")
            }
            if let http = response as? HTTPURLResponse {
                print("status", http.statusCode)
            }
            #endif

            if failed {
                guard retryIndex < Self.retryDelays.count else {
                    self.removePendingPing(bodyData)
                    #if DEBUG
                    print("All \(Self.retryDelays.count) retries exhausted, dropping ping")
                    #endif
                    return
                }

                let delay = Self.retryDelays[retryIndex]
                #if DEBUG
                print("Scheduling retry \(retryIndex + 1)/\(Self.retryDelays.count) in \(Int(delay / 60))m")
                #endif
                self.persistPing(bodyData, nextRetryIndex: retryIndex + 1)

                DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self = self else { return }
                    self.removePendingPing(bodyData)
                    guard let url = self.endpointURL(path: "ping") else { return }
                    var retryReq = URLRequest(url: url)
                    retryReq.httpMethod = "POST"
                    retryReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    retryReq.setValue("Bearer " + Environment.apikey, forHTTPHeaderField: "Authorization")
                    retryReq.setValue(Environment.apikey, forHTTPHeaderField: "apikey")
                    retryReq.httpBody = bodyData
                    self.sendWithRetry(retryReq, bodyData: bodyData, retryIndex: retryIndex + 1)
                }
                return
            }

            self.removePendingPing(bodyData)
            #if DEBUG
            if let data, let body = String(data: data, encoding: .utf8) {
                print(body)
            }
            #endif
        }.resume()
    }

    // MARK: - Pending ping persistence

    private func persistPing(_ bodyData: Data, nextRetryIndex: Int) {
        var pending = loadPendingPings()
        pending.removeAll { $0.bodyData == bodyData }
        pending.append(PendingPing(bodyData: bodyData, retryIndex: nextRetryIndex))
        savePendingPings(pending)
    }

    private func removePendingPing(_ bodyData: Data) {
        var pending = loadPendingPings()
        let before = pending.count
        pending.removeAll { $0.bodyData == bodyData }
        if pending.count != before {
            savePendingPings(pending)
        }
    }

    private func loadPendingPings() -> [PendingPing] {
        guard let data = defaults.data(forKey: Self.pendingPingsKey) else { return [] }
        return (try? JSONDecoder().decode([PendingPing].self, from: data)) ?? []
    }

    private func savePendingPings(_ pings: [PendingPing]) {
        if pings.isEmpty {
            defaults.removeObject(forKey: Self.pendingPingsKey)
        } else if let data = try? JSONEncoder().encode(pings) {
            defaults.set(data, forKey: Self.pendingPingsKey)
        }
    }

    private func processPendingPings() {
        let pending = loadPendingPings()
        guard !pending.isEmpty else { return }
        savePendingPings([])

        #if DEBUG
        print("Processing \(pending.count) persisted pending ping(s)")
        #endif

        for ping in pending {
            guard let url = endpointURL(path: "ping") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer " + Environment.apikey, forHTTPHeaderField: "Authorization")
            req.setValue(Environment.apikey, forHTTPHeaderField: "apikey")
            req.httpBody = ping.bodyData
            sendWithRetry(req, bodyData: ping.bodyData, retryIndex: ping.retryIndex)
        }
    }
}
