//
//  ViewController.swift
//  GarageOpener
//
//  Copyright (c) 2015 Mihai Pora. All rights reserved.
//

import UIKit
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


class ViewController: UIViewController {
    var nsb:NetServiceBrowser?
    var nsbdel:BMBrowserDelegate?
    var mNetService:NetService?
    var mResolved:Bool?
    var mServiceUrl: String?
    var mButtons = [UIButton]()
    
    @IBOutlet weak var button0: UIButton!
    
    @IBOutlet weak var button1: UIButton!
    
    @IBOutlet weak var button2: UIButton!
    
    @IBOutlet weak var button3: UIButton!
    
    @IBOutlet weak var ledText: UITextField!
    
    @IBAction func button0Click(_ sender: AnyObject) {
        remoteClick("0")
    }
    
    @IBAction func button1Click(_ sender: AnyObject) {
        remoteClick("1")
    }
    
    @IBAction func button2Click(_ sender: AnyObject) {
        remoteClick("2")
    }
    
    @IBAction func button3Click(_ sender: AnyObject) {
        remoteClick("3")
    }
    
    func remoteClick(_ button: String) {
        DispatchQueue.main.async(execute: {
            self.ledText.backgroundColor = UIColor.red
            self.ledText.textColor = UIColor.red
            })
        let url = URL(string: mServiceUrl! + button)
        
        let task = URLSession.shared.dataTask(with: url!, completionHandler: {(data, response, error) in
            print( NSString(data: data!, encoding: String.Encoding.utf8.rawValue)!)
            DispatchQueue.main.async(execute: {
                self.ledText.backgroundColor = UIColor.white
                self.ledText.textColor = UIColor.black
                })

        }) 
        task.resume()
    }
    
    func resolved(_ service: NetService) {
        mNetService = service
        print("resolved")
        if mNetService!.addresses?.count > 0 {
            print("have address")
            if let data: AnyObject = mNetService!.addresses?.last as AnyObject {
                var storage = sockaddr_storage()
                data.getBytes(&storage, length: MemoryLayout<sockaddr_storage>.size)
                print(data)
                print(Int32(storage.ss_family))
                print(AF_INET)
                if true || Int32(storage.ss_family) == AF_INET {
                    print("is AF_INET")
                    let addr4 = withUnsafePointer(to: &storage) { UnsafeRawPointer($0).load(as: sockaddr_in.self) }
                    
                    let sAddr = String(cString: inet_ntoa(addr4.sin_addr), encoding: .ascii)
                    print(sAddr)
                    
                    let sPort = String(mNetService!.port)
                    mServiceUrl = "http://" + sAddr! + ":" + sPort + "/button?k="
                    print("ServiceURL:" + mServiceUrl!)
                    
                    let configUrl = "http://" + sAddr! + ":" + sPort + "/config"
                    let url = URL(string: configUrl)
                    let task = URLSession.shared.dataTask(with: url!, completionHandler: {(data, response, error) in
                        print("config")
                        print( NSString(data: data!, encoding: String.Encoding.utf8.rawValue)!)
                        //self.ledText.backgroundColor = UIColor.whiteColor()
                        let parsedObject: AnyObject? = try? JSONSerialization.jsonObject(with: data!,
                            options: JSONSerialization.ReadingOptions.allowFragments) as AnyObject
                        if let apps = parsedObject as? NSArray {
                            for (index, value) in apps.enumerated() {
                                if let label = value as? NSString {
                                    DispatchQueue.main.async(execute: {
                                        self.mButtons[index].setTitle( String(label), for: UIControlState())
                                        self.mButtons[index].isEnabled = true
                                    });
                                }
                            }
                        }
                    }) 
                    
                    task.resume()

                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mButtons.append(button0)
        mButtons.append(button1)
        mButtons.append(button2)
        mButtons.append(button3)
        for button in mButtons {
            button.setTitle( "", for: UIControlState())
        }
        // Do any additional setup after loading the view, typically from a nib.
        /// Net service browser.
        nsb = NetServiceBrowser()
        nsbdel = BMBrowserDelegate(viewController: self) //see bellow
        nsb!.delegate = nsbdel
        nsb!.searchForServices(ofType: "_gateservice._tcp.", inDomain: "local")
//        nsb!.searchForServicesOfType("_http._tcp", inDomain: "local")
        

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

class BMBrowserDelegate : NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    var mVC:ViewController
    init(viewController vc:ViewController) {
        mVC = vc
    }
    
    func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser,
        didFindDomain domainName: String,
        moreComing moreDomainsComing: Bool) {
            print("netServiceDidFindDomain")
    }
    
    func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser,
        didRemoveDomain domainName: String,
        moreComing moreDomainsComing: Bool) {
            print("netServiceDidRemoveDomain")
    }
    
    func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser,
        didFind netService: NetService,
        moreComing moreServicesComing: Bool) {
            print("netServiceDidFindService")
            mVC.mNetService = netService
            netService.delegate = self
            mVC.mNetService!.resolve(withTimeout: 10)
            print("resolved?")
            print(netService.description)
            print(netService.addresses?.count)
            print(netService.hostName)
            print(netService.port)
            
    }
    
    func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser,
        didRemove netService: NetService,
        moreComing moreServicesComing: Bool) {
            print("netServiceDidRemoveService")
    }
    
    func netServiceBrowserWillSearch(_ aNetServiceBrowser: NetServiceBrowser){
        print("netServiceBrowserWillSearch")
    }
    
//    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser,
//        didNotSearch errorInfo: [NSObject : AnyObject]) {
//            print("netServiceDidNotSearch")
//    }
    
    func netServiceBrowserDidStopSearch(_ netServiceBrowser: NetServiceBrowser) {
        print("netServiceDidStopSearch")
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        print("netServiceDidResolveAddress");
        mVC.resolved(sender)
    }
    
    /* Sent to the NSNetService instance's delegate when an error in resolving the instance occurs. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants).
    */
//    func netService(sender: NSNetService, didNotResolve errorDict: [NSObject : AnyObject]) {
//        print("netServiceDidNOTResolve:")
//        for (key, val) in errorDict {
//            print("err " + (key as! String) + " " + (val as! String))
//        }
//    }


}

