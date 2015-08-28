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
            println( NSString(data: data, encoding: NSUTF8StringEncoding))
            dispatch_async(dispatch_get_main_queue(), {
                self.ledText.backgroundColor = UIColor.whiteColor()
                self.ledText.textColor = UIColor.blackColor()
                })

        }
        task.resume()
    }
    
    func resolved(service: NSNetService) {
        mNetService = service
        println("resolved")
        if mNetService!.addresses?.count > 0 {
            println("have address")
            if let data: AnyObject? = mNetService!.addresses?.last {
                var storage = sockaddr_storage()
                data!.getBytes(&storage, length: sizeof(sockaddr_storage))
                println(data)
                println(Int32(storage.ss_family))
                println(AF_INET)
                if true || Int32(storage.ss_family) == AF_INET {
                    println("is AF_INET")
                    let addr4 = withUnsafePointer(&storage) { UnsafePointer<sockaddr_in>($0).memory }
                    
                    let sAddr = String(CString: inet_ntoa(addr4.sin_addr), encoding: NSASCIIStringEncoding)
                    println(sAddr)
                    
                    let sPort = String(mNetService!.port)
                    mServiceUrl = "http://" + sAddr! + ":" + sPort + "/button?k="
                    println("ServiceURL:" + mServiceUrl!)
                    
                    let configUrl = "http://" + sAddr! + ":" + sPort + "/config"
                    let url = NSURL(string: configUrl)
                    let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
                        println("config")
                        println( NSString(data: data, encoding: NSUTF8StringEncoding))
                        //self.ledText.backgroundColor = UIColor.whiteColor()
                        var parseError: NSError?
                        let parsedObject: AnyObject? = NSJSONSerialization.JSONObjectWithData(data,
                            options: NSJSONReadingOptions.AllowFragments,
                            error:&parseError)
                        if let apps = parsedObject as? NSArray {
                            for (index, value) in enumerate(apps) {
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
            println("netServiceDidFindDomain")
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser,
        didRemoveDomain domainName: String,
        moreComing moreDomainsComing: Bool) {
            println("netServiceDidRemoveDomain")
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser,
        didFindService netService: NSNetService,
        moreComing moreServicesComing: Bool) {
            println("netServiceDidFindService")
            mVC.mNetService = netService
            netService.delegate = self
            mVC.mNetService!.resolveWithTimeout(10)
            println("resolved?")
            println(netService.description)
            println(netService.addresses?.count)
            println(netService.hostName)
            println(netService.port)
            
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser,
        didRemoveService netService: NSNetService,
        moreComing moreServicesComing: Bool) {
            println("netServiceDidRemoveService")
    }
    
    func netServiceBrowserWillSearch(aNetServiceBrowser: NSNetServiceBrowser){
        println("netServiceBrowserWillSearch")
    }
    
    func netServiceBrowser(netServiceBrowser: NSNetServiceBrowser,
        didNotSearch errorInfo: [NSObject : AnyObject]) {
            println("netServiceDidNotSearch")
    }
    
    func netServiceBrowserDidStopSearch(netServiceBrowser: NSNetServiceBrowser) {
        println("netServiceDidStopSearch")
    }
    
    func netServiceDidResolveAddress(sender: NSNetService) {
        println("netServiceDidResolveAddress");
        mVC.resolved(sender)
    }
    
    /* Sent to the NSNetService instance's delegate when an error in resolving the instance occurs. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants).
    */
    func netService(sender: NSNetService, didNotResolve errorDict: [NSObject : AnyObject]) {
        println("netServiceDidNOTResolve:")
        for (key, val) in errorDict {
            println("err " + (key as! String) + " " + (val as! String))
        }
        
    }


}

