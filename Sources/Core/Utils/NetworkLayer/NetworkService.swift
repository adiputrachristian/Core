//
//  NetworkService.swift
//  RAWG
//
//

import Foundation
import Combine

@available(iOS 13.0, *)
public protocol APIClient {
    associatedtype EndpointType: DataRequest
    func request<T: Decodable>(_ endpoint: EndpointType) -> AnyPublisher<T, Error>
}

public class URLSessionAPIClient<EndpointType: DataRequest>: APIClient {
    
    public init() {}
    
    @available(iOS 13.0, *)
    public func request<T: Decodable>(_ endpoint: EndpointType) -> AnyPublisher<T, Error> {
        // Create the URL
        var urlComponents = URLComponents(string: endpoint.baseURL.absoluteString)!
        urlComponents.path = endpoint.path
        
        // Encode query parameters as query items and add them to the URL
        if let queryParameters = endpoint.parameters {
            let queryItems: [URLQueryItem] = queryParameters.compactMap { key, value in
                guard let encodedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                    return nil
                }
                return URLQueryItem(name: key, value: encodedValue)
            }
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            return Fail(error: ErrorResponse.invalidEndpoint).eraseToAnyPublisher()
        }
        
        // Create the URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        // Set up any request headers here
        endpoint.headers?.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .subscribe(on: DispatchQueue.global(qos: .background))
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw ErrorResponse.invalidResponse
                }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    
    func convertDictionaryToData(dictionary: [String: Any]) -> Data? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            return jsonData
        } catch {
            print("Error converting dictionary to data: \(error.localizedDescription)")
            return nil
        }
    }
}


