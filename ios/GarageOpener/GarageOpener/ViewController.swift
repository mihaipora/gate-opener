//
//  ViewController.swift
//  GarageOpener
//
//  Copyright (c) 2015 Mihai Pora. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var nsb:NSNetServiceBrowser?
    var nsbdel:BMBrowserDelegate?
    var mNetService:NSNetService?
    var mResolved:Bool?
    var mServiceUrl: String?
    var mButtons = [UIButton]()
    
    @IBOutlet weak var button0: UIButton!
    
    @IBOutlet weak var button1: UIButton!
    
    @IBOutlet weak var button2: UIButton!
    
    @IBOutlet weak var button3: UIButton!
    
    @IBOutlet weak var ledText: UITextField!
    
    @IBAction func button0Click(sender: AnyObject) {
        remoteClick("0")
    }
    
    @IBAction func button1Click(sender: AnyObject) {
        remoteClick("1")
    }
    
    @IBAction func button2Click(sender: AnyObject) {
        remoteClick("2")
    }
    
    @IBAction func button3Click(sender: AnyObject) {
        remoteClick("3")
    }
    
    func remoteClick(button: String) {
        dispatch_async(dispatch_get_main_queue(), {
            self.ledText.backgroundColor = UIColor.redColor()
            self.ledText.textColor = UIColor.redColor()
            })
        let url = NSURL(string: mServiceUrl! + button)
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            print( NSString(data: data!, encoding: NSUTF8StringEncoding))
            dispatch_async(dispatch_get_main_queue(), {
                self.ledText.backgroundColor = UIColor.whiteColor()
                self.ledText.textColor = UIColor.blackColor()
                })

        }
        task.resume()
    }
    
    func resolved(service: NSNetService) {
        mNetService = service
        print("resolved")
        if mNetService!.addresses?.count > 0 {
            print("have address")
            if let data: AnyObject? = mNetService!.addresses?.last {
                var storage = sockaddr_storage()
                data!.getBytes(&storage, length: sizeof(sockaddr_storage))
                print(data)
                print(Int32(storage.ss_family))
                print(AF_INET)
                if true || Int32(storage.ss_family) == AF_INET {
                    print("is AF_INET")
                    let addr4 = withUnsafePointer(&storage) { UnsafePointer<sockaddr_in>($0).memory }
                    
                    let sAddr = String(CString: inet_ntoa(addr4.sin_addr), encoding: NSASCIIStringEncoding)
                    print(sAddr)
                    
                    let sPort = String(mNetService!.port)
                    mServiceUrl = "http://" + sAddr! + ":" + sPort + "/button?k="
                    print("ServiceURL:" + mServiceUrl!)
                    
                    let configUrl = "http://" + sAddr! + ":" + sPort + "/config"
                    let url = NSURL(string: configUrl)
                    let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
                        print("config")
                        print( NSString(data: data!, encoding: NSUTF8StringEncoding))
                        //self.ledText.backgroundColor = UIColor.whiteColor()
                        let parsedObject: AnyObject? = try? NSJSONSerialization.JSONObjectWithData(data!,
                            options: NSJSONReadingOptions.AllowFragments)
                        if let apps = parsedObject as? NSArray {
                            for (index, value) in apps.enumerate() {
                                if let label = value as? NSString {
                                    dispatch_async(dispatch_get_main_queue(), {
                                        self.mButtons[index].setTitle( String(label), forState: .Normal)
                                        self.mButtons[index].enabled = true
                                    });
                                }
                            }
                        }
                    }
                    
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
            button.setTitle( "", forState: .Normal)
        }
        // Do any additional setup after loading the view, typically from a nib.
        /// Net service browser.
        nsb = NSNetServiceBrowser()
        nsbdel = BMBrowserDelegate(viewController: self) //see bellow
        nsb!.delegate = nsbdel
        nsb!.searchForServicesOfType("_gateservice._tcp.", inDomain: "local")
//        nsb!.searchForServicesOfType("_http._tcp", inDomain: "local")
        

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

class BMBrowserDelegate : NSObject, NSNetServiceBrowserDelegate, NSNetServiceDelegate {
    var mVC:ViewController
    init(viewController vc:ViewController) {
        mVC = vc
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser,
        didFindDomain domainName: String,
        moreComing moreDomainsComing: Bool) {
            print("netServiceDidFindDomain")
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser,
        didRemoveDomain domainName: String,
        moreComing moreDomainsComing: Bool) {
            print("netServiceDidRemoveDomain")
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser,
        didFindService netService: NSNetService,
        moreComing moreServicesComing: Bool) {
            print("netServiceDidFindService")
            mVC.mNetService = netService
            netService.delegate = self
            mVC.mNetService!.resolveWithTimeout(10)
            print("resolved?")
            print(netService.description)
            print(netService.addresses?.count)
            print(netService.hostName)
            print(netService.port)
            
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser,
        didRemoveService netService: NSNetService,
        moreComing moreServicesComing: Bool) {
            print("netServiceDidRemoveService")
    }
    
    func netServiceBrowserWillSearch(aNetServiceBrowser: NSNetServiceBrowser){
        print("netServiceBrowserWillSearch")
    }
    
//    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser,
//        didNotSearch errorInfo: [NSObject : AnyObject]) {
//            print("netServiceDidNotSearch")
//    }
    
    func netServiceBrowserDidStopSearch(netServiceBrowser: NSNetServiceBrowser) {
        print("netServiceDidStopSearch")
    }
    
    func netServiceDidResolveAddress(sender: NSNetService) {
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

