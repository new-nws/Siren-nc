//
//  Siren.swift
//  Siren
//
//  Created by Arthur Sabintsev on 1/3/15.
//  Copyright (c) 2015 Sabintsev iOS Projects. All rights reserved.
//

import UIKit

// MARK: SirenDelegate Protocol
@objc public protocol SirenDelegate {
    @objc optional func sirenDidShowUpdateDialog()                            // User presented with update dialog
    @objc optional func sirenUserDidLaunchAppStore()                          // User did click on button that launched App Store.app
    @objc optional func sirenUserDidSkipVersion()                             // User did click on button that skips version update
    @objc optional func sirenUserDidCancel()                                  // User did click on button that cancels update dialog
    @objc optional func sirenDidDetectNewVersionWithoutAlert(_ message: String) // Siren performed version check and did not display alert
}

// MARK: Enumerations
/**
    Determines the type of alert to present after a successful version check has been performed.
    
    There are four options:

    - .Force: Forces user to update your app (1 button alert)
    - .Option: (DEFAULT) Presents user with option to update app now or at next launch (2 button alert)
    - .Skip: Presents user with option to update the app now, at next launch, or to skip this version all together (3 button alert)
    - .None: Doesn't show the alert, but instead returns a localized message for use in a custom UI within the sirenDidDetectNewVersionWithoutAlert() delegate method

*/
public enum SirenAlertType {
    case force        // Forces user to update your app (1 button alert)
    case option       // (DEFAULT) Presents user with option to update app now or at next launch (2 button alert)
    case skip         // Presents user with option to update the app now, at next launch, or to skip this version all together (3 button alert)
    case none         // Doesn't show the alert, but instead returns a localized message for use in a custom UI within the sirenDidDetectNewVersionWithoutAlert() delegate method
}

/**
    Determines the frequency in which the the version check/Alert show is performed
    
    - .Immediately: Version check/Alert show performed every time the app is launched
    - .Daily: Version check/Alert show performedonce a day
    - .Weekly: Version check/Alert show performed once a week

*/
public enum SirenFrequencyType: Int {
    case immediately = 0    // Version check/Alert show performed every time the app is launched
    case daily = 1          // Version check/Alert show performed once a day
    case weekly = 7         // Version check/Alert show performed once a week
}

/**
 Determines the type of version update it is. Supporting for 4 type of semantic version update.
 
 - .Major: A.b.c.d <- Major version update
 - .Minor: a.B.c.d <- Minor version update
 - .Patch: a.b.C.d <- Patch version update
 - .Revision: a.b.c.D <- Revision version update
 
 */
public enum SirenSemanticVersionFragment{
    case major              // A.b.c.d <- Major version update
    case minor              // a.B.c.d <- Minor version update
    case patch              // a.b.C.d <- Patch version update
    case revision           // a.b.c.D <- Revision version update
}

/**
    Determines the available languages in which the update message and alert button titles should appear.
    
    By default, the operating system's default lanuage setting is used. However, you can force a specific language
    by setting the forceLanguageLocalization property before calling checkVersion()

*/
public enum SirenLanguageType: String {
    case Arabic = "ar"
    case Armenian = "hy"
    case Basque = "eu"
    case ChineseSimplified = "zh-Hans"
    case ChineseTraditional = "zh-Hant"
    case Danish = "da"
    case Dutch = "nl"
    case English = "en"
    case Estonian = "et"
    case French = "fr"
    case Hebrew = "he"
    case Hungarian = "hu"
    case German = "de"
    case Italian = "it"
    case Japanese = "ja"
    case Korean = "ko"
    case Latvian = "lv"
    case Lithuanian = "lt"
    case Malay = "ms"
    case Polish = "pl"
    case PortugueseBrazil = "pt"
    case PortuguesePortugal = "pt-PT"
    case Russian = "ru"
    case Slovenian = "sl"
    case Spanish = "es"
    case Swedish = "sv"
    case Thai = "th"
    case Turkish = "tr"
}

/** 
    Siren-specific NSUserDefault Keys
*/
private enum SirenUserDefaults: String {
    case StoredVersionCheckDate     // NSUserDefault key that stores the timestamp of the last version check
    case StoredSkippedVersion       // NSUserDefault key that stores the version that a user decided to skip
    case StoredVersionAlertShowDate     // NSUserDefault key that stores the timestamp of the last time alert was shown
}

// MARK: Siren
/**
    The Siren Class.
    
    A singleton that is initialized using the sharedInstance() method.
*/
open class Siren: NSObject {

    // MARK: Constants
    // Current installed version of your app
    let currentInstalledVersion = Bundle.main.currentInstalledVersion()
    
    // NSBundle path for localization
    let bundlePath = Bundle.main.path(forResource: "Siren", ofType: "Bundle")
    
    // MARK: Variables
    /**
        The SirenDelegate variable, which should be set if you'd like to be notified:
    
            - When a user views or interacts with the alert
                - sirenDidShowUpdateDialog()
                - sirenUserDidLaunchAppStore()
                - sirenUserDidSkipVersion()     
                - sirenUserDidCancel()
            - When a new version has been detected, and you would like to present a localized message in a custom UI
                - sirenDidDetectNewVersionWithoutAlert(message: String)
    
    */
    open weak var delegate: SirenDelegate?

    /**
        The debug flag, which is disabled by default.
    
        When enabled, a stream of println() statements are logged to your console when a version check is performed.
    */
    open lazy var debugEnabled = false
    
    // Alert Vars
    /**
        Determines the type of alert that should be shown.
    
        See the SirenAlertType enum for full details.
    */
    open var alertType = SirenAlertType.option
        {
        didSet {
            majorUpdateAlertType = alertType
            minorUpdateAlertType = alertType
            patchUpdateAlertType = alertType
            revisionUpdateAlertType = alertType
        }
    }
    
    /**
    Determines the type of alert that should be shown for major version updates: A.b.c
    
    Defaults to SirenAlertType.Option.
    
    See the SirenAlertType enum for full details.
    */
    open var majorUpdateAlertType = SirenAlertType.option
    
    /**
    Determines the type of alert that should be shown for minor version updates: a.B.c
    
    Defaults to SirenAlertType.Option.
    
    See the SirenAlertType enum for full details.
    */
    open var minorUpdateAlertType  = SirenAlertType.option
    
    /**
    Determines the type of alert that should be shown for minor patch updates: a.b.C
    
    Defaults to SirenAlertType.Option.
    
    See the SirenAlertType enum for full details.
    */
    open var patchUpdateAlertType = SirenAlertType.option
    
    /**
    Determines the type of alert that should be shown for revision updates: a.b.c.D
    
    Defaults to SirenAlertType.Option.
    
    See the SirenAlertType enum for full details.
    */
    open var revisionUpdateAlertType = SirenAlertType.option
    
    /**
     Determines the frequency of alert showing for major updates: A.b.c.d
     
     Defaults to SirenFrequencyType.Immediately.
     
     See the SirenFrequencyType enum for full details.
     */
    open var majorUpdateShowAlertFrequencyType = SirenFrequencyType.immediately
    
    /**
     Determines the frequency of alert showing for minor updates: a.B.c.d
     
     Defaults to SirenFrequencyType.Immediately.
     
     See the SirenFrequencyType enum for full details.
     */
    open var minorUpdateShowAlertFrequencyType  = SirenFrequencyType.immediately
    
    /**
     Determines the frequency of alert showing for patch updates: a.b.C.d
     
     Defaults to SirenFrequencyType.Immediately.
     
     See the SirenFrequencyType enum for full details.
     */
    open var patchUpdateShowAlertFrequencyType = SirenFrequencyType.immediately
    
    /**
     Determines the frequency of alert showing for revision updates: a.b.c.D
     
     Defaults to SirenFrequencyType.Immediately.
     
     See the SirenFrequencyType enum for full details.
     */
    open var revisionUpdateShowAlertFrequencyType = SirenFrequencyType.immediately
    
    // Required Vars
    /**
        The App Store / iTunes Connect ID for your app.
    */
    open var appID: String?
    
    // Optional Vars
    /**
        The name of your app. 
    
        By default, it's set to the name of the app that's stored in your plist.
    */
    open lazy var appName: String = (Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String) ?? ""
    
    /**
        The region or country of an App Store in which your app is available.
        
        By default, all version checks are performed against the US App Store.
        If your app is not available in the US App Store, you should set it to the identifier 
        of at least one App Store within which it is available.
    */
    open var countryCode: String?
    
    /**
        The custom URL base to the json which contains version and mandatory_version.
     
     Example json:
     {
         "results":[{
             "version":"4.4.7.1",
             "mandatory_version":"4.4.7.0"
         }]
     }
     
     If customURL is provided then it will check for mandatory_version first. If that is fine it will look for version key. If that is not provided it will check version on itunes. the behaviour for "version" key is the same for itunes and custom URL.
     */
    open var customURLBase: String?
    
    /**
        Overrides the default localization of a user's device when presenting the update message and button titles in the alert.
    
        See the SirenLanguageType enum for more details.
    */
    open var forceLanguageLocalization: SirenLanguageType?
    
    /**
        Overrides the tint color for UIAlertController.
    */
    open var alertControllerTintColor: UIColor?
    
    // Private
    fileprivate var lastVersionCheckPerformedOnDate: Date?
    fileprivate var lastAlertShowPerformedOnDate: Date?
    fileprivate var currentAppStoreVersion: String?
    fileprivate var currentForceUpdateVersion: String?
    fileprivate var updaterWindow: UIWindow?
    
    // MARK: Initialization
    open class var sharedInstance: Siren {
        struct Singleton {
            static let instance = Siren()
        }
        
        return Singleton.instance
    }
    
    override init() {
        lastVersionCheckPerformedOnDate = UserDefaults.standard.object(forKey: SirenUserDefaults.StoredVersionCheckDate.rawValue) as? Date
        lastAlertShowPerformedOnDate = UserDefaults.standard.object(forKey: SirenUserDefaults.StoredVersionAlertShowDate.rawValue) as? Date
    }
    
    // MARK: Check Version
    /**
        Checks the currently installed version of your app against the App Store.
        The default check is against the US App Store, but if your app is not listed in the US,
        you should set the `countryCode` property before calling this method. Please refer to the countryCode property for more information.
    
        - parameter checkType: The frequency in days in which you want a check to be performed. Please refer to the SirenFrequencyType enum for more details.
    */
    open func checkVersion(_ checkType: SirenFrequencyType) {
        
        guard let _ = appID else {
            print("[Siren] Please make sure that you have set 'appID' before calling checkVersion.")
            return
        }

        if checkType == .immediately {
            performVersionCheck()
        } else {
            guard let lastVersionCheckPerformedOnDate = lastVersionCheckPerformedOnDate else {
                performVersionCheck()
                return
            }
            
            if daysSinceLastActionDate(lastVersionCheckPerformedOnDate) >= checkType.rawValue {
                performVersionCheck()
            }
        }
    }
    
    fileprivate func performVersionCheck(forceiTunes:Bool = false) {
        
        var urlFromString:URL? = customURLFromString()
        
        if forceiTunes == true || urlFromString == nil {
            urlFromString = iTunesURLFromString()
        }
        
        // Create Request
        let request = NSMutableURLRequest(url:urlFromString!)
        request.httpMethod = "GET"
        
        // Perform Request
        let session = URLSession.shared
        
        let task = session.dataTask(with: request as URLRequest) { (data, response, error) in
            if let error = error {
                if self.debugEnabled {
                    print("[Siren] Error retrieving App Store data as an error was returned: \(error.localizedDescription)")
                }
            } else {
                guard let data = data else {
                    if self.debugEnabled {
                        print("[Siren] Error retrieving App Store data as no data was returned.")
                    }
                    return
                }
                
                // Convert JSON data to Swift Dictionary of type [String: AnyObject]
                do {
                    let jsonData = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)
                    
                    guard let appData = jsonData as? [String: AnyObject] else {
                        if self.debugEnabled {
                            print("[Siren] Error parsing App Store JSON data.")
                        }
                        return
                    }
                    
                    DispatchQueue.main.async(execute: { () -> Void in
                        
                        // Print iTunesLookup results from appData
                        if self.debugEnabled {
                            print("[Siren] JSON results: \(appData)")
                        }
                        
                        // Process Results (e.g., extract current version on the AppStore)
                        self.processVersionCheckResults(appData, forceiTunes:forceiTunes)
                        
                    })
                    
                } catch let error as NSError {
                    if self.debugEnabled {
                        print("[Siren] Error retrieving App Store data as data was nil: \(error.localizedDescription)")
                    }
                    //in case we were trying to parse json file from the customURL and it threw an exception
                    //let us go ahead and fetch the itunes store json
                    if forceiTunes == false {
                        self.performVersionCheck(forceiTunes:true)
                    }
                }
            }
            
        }
        
        task.resume()
    }
    
    fileprivate func processVersionCheckResults(_ lookupResults: [String: AnyObject], forceiTunes:Bool) {
        
        // Store version comparison date
        storeVersionCheckDate()

        guard let results = lookupResults["results"] as? [[String: AnyObject]] else {
            if debugEnabled {
                print("[Siren] Error retrieving App Store verson number as there was no data returned")
            }
            return
        }
        
        if results.isEmpty == false { // Conditional that avoids crash when app not in App Store or appID mistyped
            currentAppStoreVersion = results[0]["version"] as? String
            currentForceUpdateVersion = results[0]["mandatory_version"] as? String
            
            // We break the flow if mandatory_version is supplied in order to first check for mandatory updates from custom URLs
            if currentForceUpdateVersion != nil {
                showAlertIfMandatoryUpdateAvailable(forceiTunes: forceiTunes)
                return
            }
            guard let _ = currentAppStoreVersion else {
                if debugEnabled {
                    print("[Siren] Error retrieving App Store verson number as results[0] does not contain a 'version' key")
                }
                if forceiTunes == false {
                    performVersionCheck(forceiTunes: true)
                }
                return
            }
            
            if isAppStoreVersionNewer() {
                showAlertIfCurrentAppStoreVersionNotSkipped()
            } else {
                if debugEnabled {
                    print("[Siren] App Store version of app is not newer")
                }
            }
           
        } else { // lookupResults does not contain any data as the returned array is empty
            if debugEnabled {
                print("[Siren] Error retrieving App Store verson number as results returns an empty array")
            }
        }
    }
}

// MARK: Alert
private extension Siren {
    
    func showAlertIfSatisfiesFrequencyRequirments() {

        guard let lastAlertShowPerformedOnDate = lastAlertShowPerformedOnDate else {
            //In case this is the first time we want to show the alert
            showAlert()
            return
        }

        guard let versionComponent = getSemanticVersionComponent() else {
            return
        }
        
        switch versionComponent {
            
        case .major:
            if majorUpdateShowAlertFrequencyType == .immediately {
                showAlert()
            }else if daysSinceLastActionDate(lastAlertShowPerformedOnDate) >= majorUpdateShowAlertFrequencyType.rawValue {
                showAlert()
            }
        case .minor:
            if minorUpdateShowAlertFrequencyType == .immediately {
                showAlert()
            }else if daysSinceLastActionDate(lastAlertShowPerformedOnDate) >= minorUpdateShowAlertFrequencyType.rawValue {
                showAlert()
            }
        case .patch:
            if patchUpdateShowAlertFrequencyType == .immediately {
                showAlert()
            }else if daysSinceLastActionDate(lastAlertShowPerformedOnDate) >= patchUpdateShowAlertFrequencyType.rawValue {
                showAlert()
            }
        case .revision:
            if revisionUpdateShowAlertFrequencyType == .immediately {
                showAlert()
            }else if daysSinceLastActionDate(lastAlertShowPerformedOnDate) >= revisionUpdateShowAlertFrequencyType.rawValue {
                showAlert()
            }
        }
        
    }
    
    func showAlertIfMandatoryUpdateAvailable(forceiTunes:Bool) {
        
        if let shouldForceMandatoryUpdate = checkMandatoryUpdate() , shouldForceMandatoryUpdate == true {
            alertType = .force
            showAlert()
            return
        }
        
        guard let _ = currentAppStoreVersion else {
            if debugEnabled {
                print("[Siren] Error retrieving App Store verson number as results[0] does not contain a 'version' key")
            }
            if forceiTunes == false {
                performVersionCheck(forceiTunes: true)
            }
            return
        }
        
        if isAppStoreVersionNewer() {
            showAlertIfCurrentAppStoreVersionNotSkipped()
        } else {
            if debugEnabled {
                print("[Siren] App Store version of app is not newer")
            }
        }
    }
    
    func showAlertIfCurrentAppStoreVersionNotSkipped() {
        
        guard let alertTypeCheck = setAlertType() else {
            return
        }
        alertType = alertTypeCheck
        
        guard let previouslySkippedVersion = UserDefaults.standard.object(forKey: SirenUserDefaults.StoredSkippedVersion.rawValue) as? String else {
            showAlertIfSatisfiesFrequencyRequirments()
            return
        }
        
        if let currentAppStoreVersion = currentAppStoreVersion {
            if currentAppStoreVersion != previouslySkippedVersion {
                showAlertIfSatisfiesFrequencyRequirments()
            }
        }
    }
    
    func showAlert() {
        
        // Store alert shown date
        storeAlertShowDate()
        
        let updateAvailableMessage = Bundle().localizedString("Update Available", forceLanguageLocalization: forceLanguageLocalization)
        let newVersionMessage = localizedNewVersionMessage()

        if (useAlertController) { // iOS 8

            if #available(iOS 8.0, *) {
                let alertController = UIAlertController(title: updateAvailableMessage, message: newVersionMessage, preferredStyle: .alert)
                
                if let alertControllerTintColor = alertControllerTintColor {
                    alertController.view.tintColor = alertControllerTintColor
                }
                
                switch alertType {
                case .force:
                    alertController.addAction(updateAlertAction())
                case .option:
                    alertController.addAction(nextTimeAlertAction())
                    alertController.addAction(updateAlertAction())
                case .skip:
                    alertController.addAction(nextTimeAlertAction())
                    alertController.addAction(updateAlertAction())
                    alertController.addAction(skipAlertAction())
                case .none:
                    delegate?.sirenDidDetectNewVersionWithoutAlert?(newVersionMessage)
                }
                
                if alertType != .none {
                    alertController.show()
                    delegate?.sirenDidShowUpdateDialog?()
                }
            }
            
        } else { // iOS 7

            var alertView: UIAlertView?
            let updateButtonTitle = localizedUpdateButtonTitle()
            let nextTimeButtonTitle = localizedNextTimeButtonTitle()
            let skipButtonTitle = localizedSkipButtonTitle()
            switch alertType {
            case .force:
                alertView = UIAlertView(title: updateAvailableMessage, message: newVersionMessage, delegate: self, cancelButtonTitle: updateButtonTitle)
            case .option:
                alertView = UIAlertView(title: updateAvailableMessage, message: newVersionMessage, delegate: self, cancelButtonTitle: nextTimeButtonTitle)
                alertView!.addButton(withTitle: updateButtonTitle)
            case .skip:
                alertView = UIAlertView(title: updateAvailableMessage, message: newVersionMessage, delegate: self, cancelButtonTitle: skipButtonTitle)
                alertView!.addButton(withTitle: updateButtonTitle)
                alertView!.addButton(withTitle: nextTimeButtonTitle)
            case .none:
                delegate?.sirenDidDetectNewVersionWithoutAlert?(newVersionMessage)
            }
            
            if let alertView = alertView {
                alertView.show()
                delegate?.sirenDidShowUpdateDialog?()
            }
        }
    }
    
    @available(iOS 8.0, *)
    func updateAlertAction() -> UIAlertAction {
        let title = localizedUpdateButtonTitle()
        let action = UIAlertAction(title: title, style: .default) { (alert: UIAlertAction) -> Void in
            self.hideWindow()
            self.launchAppStore()
            self.delegate?.sirenUserDidLaunchAppStore?()
            return
        }
        
        return action
    }
    
    @available(iOS 8.0, *)
    func nextTimeAlertAction() -> UIAlertAction {
        let title = localizedNextTimeButtonTitle()
        let action = UIAlertAction(title: title, style: .default) { (alert: UIAlertAction) -> Void in
            self.hideWindow()
            self.delegate?.sirenUserDidCancel?()
            return
        }
        
        return action
    }
    
    @available(iOS 8.0, *)
    func skipAlertAction() -> UIAlertAction {
        let title = localizedSkipButtonTitle()
        let action = UIAlertAction(title: title, style: .default) { (alert: UIAlertAction) -> Void in
            if let currentAppStoreVersion = self.currentAppStoreVersion {
                UserDefaults.standard.set(currentAppStoreVersion, forKey: SirenUserDefaults.StoredSkippedVersion.rawValue)
                UserDefaults.standard.synchronize()
            }
            self.hideWindow()
            self.delegate?.sirenUserDidSkipVersion?()
            return
        }
        
        return action
    }
}

// MARK: Helpers
private extension Siren {
    func iTunesURLFromString() -> URL {
        
        var storeURLString = "https://itunes.apple.com/lookup?id=\(appID!)"
        
        if let countryCode = countryCode {
            storeURLString += "&country=\(countryCode)"
        }
        
        if debugEnabled {
            print("[Siren] iTunes Lookup URL: \(storeURLString)")
        }
        
        return URL(string: storeURLString)!
    }
    
    func customURLFromString() -> URL? {
        
        guard let customURLBase = customURLBase else {
            return nil
        }
        
        var storeURLString = "\(customURLBase)\(appID!)?id=\(appID!)"
        
        if let countryCode = countryCode {
            storeURLString += "&country=\(countryCode)"
        }
        
        if debugEnabled {
            print("[Siren] iTunes Lookup URL: \(storeURLString)")
        }
        
        return URL(string: storeURLString)!
    }
    
    func daysSinceLastActionDate(_ lastActionPerformedOnDate: Date) -> Int {
        let calendar = Calendar.current
        let components = (calendar as NSCalendar).components(.day, from: lastActionPerformedOnDate, to: Date(), options: [])
        if components.day! < 0 {
            //In case the user set the date manually in the Settings to a date in the future and then switched back to correct date
            //we would get a negative number.
            //this return assures that if an edge scenario like that happens we return the highest number available (.Weekly)
            return SirenFrequencyType.weekly.rawValue
        }
        return components.day!
    }
    
    func isAppStoreVersionNewer() -> Bool {
        
        var newVersionExists = false
        
        if let currentInstalledVersion = currentInstalledVersion, let currentAppStoreVersion = currentAppStoreVersion {
            if (currentInstalledVersion.compare(currentAppStoreVersion, options: .numeric) == ComparisonResult.orderedAscending) {
                newVersionExists = true
            }
        }
        
        return newVersionExists
    }
    
    func storeVersionCheckDate() {
        lastVersionCheckPerformedOnDate = Date()
        if let lastVersionCheckPerformedOnDate = lastVersionCheckPerformedOnDate {
            UserDefaults.standard.set(lastVersionCheckPerformedOnDate, forKey: SirenUserDefaults.StoredVersionCheckDate.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    func storeAlertShowDate() {
        lastAlertShowPerformedOnDate = Date()
        if let lastAlertShowPerformedOnDate = lastAlertShowPerformedOnDate {
            UserDefaults.standard.set(lastAlertShowPerformedOnDate, forKey: SirenUserDefaults.StoredVersionAlertShowDate.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
    
    func setAlertType() -> SirenAlertType? {
        
        guard let versionComponent = getSemanticVersionComponent() else {
            return nil
        }
        
        switch versionComponent {
            
        case .major:
            alertType = majorUpdateAlertType
        case .minor:
            alertType = minorUpdateAlertType
        case .patch:
            alertType = patchUpdateAlertType
        case .revision:
            alertType = revisionUpdateAlertType
        }
        
        return alertType
    }
    
    func getSemanticVersionComponent() -> SirenSemanticVersionFragment? {
        
        guard let currentInstalledVersion = currentInstalledVersion, let currentAppStoreVersion = currentAppStoreVersion else {
            //Erroneous scenario. Returning nil
            return nil
        }

        var oldVersion = (currentInstalledVersion).characters.split {$0 == "."}.map { String($0) }.map {Int($0) ?? 0}
        var newVersion = (currentAppStoreVersion).characters.split {$0 == "."}.map { String($0) }.map {Int($0) ?? 0}
        
        
        //Let's make sure that both currentInstalled and currentAppstore version have all 4 components set.
        while oldVersion.count < 4 {
            oldVersion.append(0)
        }
        while newVersion.count < 4 {
            newVersion.append(0)
        }
        
        if 2...4 ~= oldVersion.count && oldVersion.count == newVersion.count {
            if newVersion[0] > oldVersion[0] { // A.b.c.d
                return .major
            }else if newVersion[0] < oldVersion[0] { // A.b.c.d
                return nil
            }else if newVersion[1] > oldVersion[1] { // a.B.c.d
                return .minor
            }else if newVersion[1] < oldVersion[1] { // a.B.c.d
                return nil
            }else if newVersion[2] > oldVersion[2] { // a.b.C.d
                return .patch
            }else if newVersion[2] < oldVersion[2] { // a.b.C.d
                return nil
            }else if newVersion[3] > oldVersion[3] { // a.b.c.D
                return .revision
            }else if newVersion[3] < oldVersion[3] { // a.b.c.D
                return nil
            }
        }
        
        //Case not handled. Returning nil
        return nil
    }
    
    func checkMandatoryUpdate() -> Bool? {
        
        guard let currentInstalledVersion = currentInstalledVersion, let currentForceUpdateVersion = currentForceUpdateVersion else {
            //Erroneous scenario. Returning nil
            return nil
        }
        
        var oldVersion = (currentInstalledVersion).characters.split {$0 == "."}.map { String($0) }.map {Int($0) ?? 0}
        var newVersion = (currentForceUpdateVersion).characters.split {$0 == "."}.map { String($0) }.map {Int($0) ?? 0}
        
        
        //Let's make sure that both currentInstalled and currentAppstore version have all 4 components set.
        while oldVersion.count < 4 {
            oldVersion.append(0)
        }
        while newVersion.count < 4 {
            newVersion.append(0)
        }
        
        if 2...4 ~= oldVersion.count && oldVersion.count == newVersion.count {
            if newVersion[0] > oldVersion[0] { // A.b.c.d
                return true
            }else if newVersion[0] < oldVersion[0] { // A.b.c.d
                return false
            } else if newVersion[1] > oldVersion[1] { // a.B.c.d
                return true
            } else if newVersion[1] < oldVersion[1] { // a.B.c.d
                return false
            } else if newVersion[2] > oldVersion[2] { // a.b.C.d
                return true
            } else if newVersion[2] < oldVersion[2] { // a.b.C.d
                return false
            } else if newVersion[3] > oldVersion[3] { // a.b.c.D
                return true
            } else if newVersion[3] < oldVersion[3] { // a.b.c.D
                return false
            }
        }
        
        //Case not handled. Returning nil
        return nil
    }
    
    func hideWindow() {
        if let updaterWindow = updaterWindow {
            updaterWindow.isHidden = true
            self.updaterWindow = nil
        }
    }
    
    // iOS 8 Compatibility Check
    var useAlertController: Bool { // iOS 8 check
        return objc_getClass("UIAlertController") != nil
    }
    
    // Actions
    func launchAppStore() {
        let iTunesString =  "https://itunes.apple.com/app/id\(appID!)"
        let iTunesURL = URL(string: iTunesString)
        UIApplication.shared.openURL(iTunesURL!)
    }
}

// MARK: UIAlertViewDelegate
extension Siren: UIAlertViewDelegate {
    public func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {

        switch alertType {

        case .force:
            launchAppStore()
        case .option:
            if buttonIndex == 1 { // Launch App Store.app
                launchAppStore()
                delegate?.sirenUserDidLaunchAppStore?()
            } else { // Ask user on next launch
                delegate?.sirenUserDidCancel?()
            }
        case .skip:
            if buttonIndex == 0 { // Launch App Store.app
                if let currentAppStoreVersion = currentAppStoreVersion {
                    UserDefaults.standard.set(currentAppStoreVersion, forKey: SirenUserDefaults.StoredSkippedVersion.rawValue)
                    UserDefaults.standard.synchronize()
                }
                delegate?.sirenUserDidSkipVersion?()
            } else if buttonIndex == 1 {
                launchAppStore()
                delegate?.sirenUserDidLaunchAppStore?()
            } else if buttonIndex == 2 { // Ask user on next launch
                delegate?.sirenUserDidCancel?()
            }
        case .none:
            if debugEnabled {
                 print("[Siren] No alert presented due to alertType == .None")
            }
        }
    }
}

// MARK: UIAlertController
@available(iOS 8.0, *)
private extension UIAlertController {
    func show() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.windowLevel = UIWindowLevelAlert + 1
        
        Siren.sharedInstance.updaterWindow = window
        
        window.makeKeyAndVisible()
        window.rootViewController!.present(self, animated: true, completion: nil)
    }
}

// MARK: String Localization
private extension Siren {
    func localizedNewVersionMessage() -> String {
        
        let newVersionMessageToLocalize = "A new version of %@ is available. Please update to version %@ now."
        let newVersionMessage = Bundle().localizedString(newVersionMessageToLocalize, forceLanguageLocalization: forceLanguageLocalization)
        
        guard let currentAppStoreVersion = currentAppStoreVersion else {
            return String(format: newVersionMessage, appName, "Unknown")
        }
        
        return String(format: newVersionMessage, appName, currentAppStoreVersion)
    }
    
    func localizedUpdateButtonTitle() -> String {
        return Bundle().localizedString("Update", forceLanguageLocalization: forceLanguageLocalization)
    }
    
    func localizedNextTimeButtonTitle() -> String {
        return Bundle().localizedString("Next time", forceLanguageLocalization: forceLanguageLocalization)
    }
    
    func localizedSkipButtonTitle() -> String {
        return Bundle().localizedString("Skip this version", forceLanguageLocalization: forceLanguageLocalization)
    }
}

// MARK: NSBundle Extension
private extension Bundle {
    func currentInstalledVersion() -> String? {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    func sirenBundlePath() -> String {
        return Bundle(for: Siren.self).path(forResource: "Siren", ofType: "bundle") as String!
    }

    func sirenForcedBundlePath(_ forceLanguageLocalization: SirenLanguageType) -> String {
        let path = sirenBundlePath()
        let name = forceLanguageLocalization.rawValue
        return Bundle(path: path)!.path(forResource: name, ofType: "lproj")!
    }

    func localizedString(_ stringKey: String, forceLanguageLocalization: SirenLanguageType?) -> String {
        var path: String
        let table = "SirenLocalizable"
        if let forceLanguageLocalization = forceLanguageLocalization {
            path = sirenForcedBundlePath(forceLanguageLocalization)
        } else {
            path = sirenBundlePath()
        }
        
        return Bundle(path: path)!.localizedString(forKey: stringKey, value: stringKey, table: table)
    }
}
