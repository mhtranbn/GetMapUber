//
//  ViewController.swift
//  GetMapUber
//
//  Created by Tran Manh Hoang on 2020/10/16.
//  Copyright © 2020 Tran Manh Hoang. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        getMapAdress()
    }
    
    func loadLastImageThumb(completion: @escaping (UIImage) -> ()) {
        let imgManager = PHImageManager.default()
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        fetchOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: fetchOptions)
        
        if let last = fetchResult.lastObject {
            let size = CGSize(width: Int(last.pixelWidth), height: Int(last.pixelHeight))
            print("size\(size)")
            let options = PHImageRequestOptions()

            imgManager.requestImage(for: last, targetSize: size, contentMode: PHImageContentMode.aspectFill, options: options, resultHandler: { (image, _) in
                if let image = image {
                    completion(image)
                }
            })
        }
        
    }
    
    func openGoogleMap(address: String) {
        let addressParam = "comgooglemaps://?saddr=&daddr=\(address)&directionsmode=walking"
        if let urlStr = URL(string:addressParam) {
            print("Load map")
            print(urlStr)
            UIApplication.shared.open(urlStr, options: [:]) { (bool) in}
        }
        showAleart()
    }
    
    func showAleart() {
        let dialogMessage = UIAlertController(title: "Can't find map", message: "Are you sure you want to try again?", preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "Try", style: .default, handler: { (action) -> Void in
            print("Ok button tapped")
            self.getMapAdress()
        })
        
        dialogMessage.addAction(ok)
        DispatchQueue.main.async {
            self.present(dialogMessage, animated: true, completion:nil)
        }
    }
    
    func getMapAdress() {
        _ = loadLastImageThumb { (image) in
            self.callOCRSpace(image)
        }
    }
    
    func callOCRSpace(_ image: UIImage) {
        // Create URL request
        let url = URL(string: "https://api.ocr.space/Parse/Image")
        var request: URLRequest? = nil
        if let url = url {
            request = URLRequest(url: url)
        }
        request?.httpMethod = "POST"
        let boundary = "randomString"
        request?.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession.shared
        
        // Image file and parameters
        let imageData = image.jpegData(compressionQuality: 0.6)
        let parametersDictionary = ["apikey" : "134212c55988957", "isOverlayRequired" : "True", "language" : "jpn"]
        
        // Create multipart form body
        let data = createBody(withBoundary: boundary, parameters: parametersDictionary, imageData: imageData, filename: "test.jpg")
        
        request?.httpBody = data
        
        // Start data session
        var task: URLSessionDataTask? = nil
        if let request = request {
            task = session.dataTask(with: request, completionHandler: { (data, response, error) in
                var address = ""
                var responseOCR: ResponseOCR?
                do {
                    if let data = data {
                        let decoder = JSONDecoder()
                        responseOCR = try decoder.decode(ResponseOCR.self, from: data)
                    }
                } catch let myError {
                    print(myError)
                }
                
                
                if let responseOCR = responseOCR,
                    let parsedResults = responseOCR.parsedResults,
                    parsedResults.count > 0,
                    let textOverlay = parsedResults.first?.textOverlay,
                    let lines = textOverlay.lines {
                    
                    lines.forEach { (line) in
                        if let words = line.words {
                            words.forEach { (word) in
                                if word.left == 129, let lineText = line.lineText {
                                    address += (lineText + "+")
                                }
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    ["Dropofforder", "ö"].forEach { (word) in
                        var character: String = "o"
                        if word == "Dropofforder" {
                            character = ""
                        }
                        address = address.replacingOccurrences(of: word, with: character, options: .literal, range: nil)
                        UIPasteboard.general.string = address.replacingOccurrences(of: "+", with: " ", options: .literal, range: nil)
                        print("address \(address)")
                    }
                    if !address.isEmpty {
                        self.openGoogleMap(address: address)
                    }
                }
            })
        }
        task?.resume()
    }
    
    func createBody(withBoundary boundary: String?, parameters: [AnyHashable : Any]?, imageData data: Data?, filename: String?) -> Data? {
        var body = Data()
        if data != nil {
            if let data1 = "--\(boundary ?? "")\r\n".data(using: .utf8) {
                body.append(data1)
            }
            if let data1 = "Content-Disposition: form-data; name=\"\("file")\"; filename=\"\(filename ?? "")\"\r\n".data(using: .utf8) {
                body.append(data1)
            }
            if let data1 = "Content-Type: image/jpeg\r\n\r\n".data(using: .utf8) {
                body.append(data1)
            }
            if let data = data {
                body.append(data)
            }
            if let data1 = "\r\n".data(using: .utf8) {
                body.append(data1)
            }
        }
        
        for key in parameters!.keys {
            if let data1 = "--\(boundary ?? "")\r\n".data(using: .utf8) {
                body.append(data1)
            }
            if let data1 = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8) {
                body.append(data1)
            }
            if let parameter = parameters?[key], let data1 = "\(parameter)\r\n".data(using: .utf8) {
                body.append(data1)
            }
        }
        
        if let data1 = "--\(boundary ?? "")--\r\n".data(using: .utf8) {
            body.append(data1)
        }
        
        return body
    }
    
    
}

