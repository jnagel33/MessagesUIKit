//
//  AppDelegate.swift
//  MessagesUIKitHost
//
//  Created by Kevin Wooten on 5/16/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import UIKit
import JPSimulatorHacks
@testable import MessagesKit
@testable import MessagesUIKit


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  let docDir = NSFileManager.defaultManager()
    .URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!

  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    
    window = UIWindow()
    
    DDLog.addLogger(DDTTYLogger.sharedInstance())
    
    JPSimulatorHacks.grantAccessToAddressBook()
    
    NSUserDefaults.standardUserDefaults().setBool(true, forKey: "io.retxt.debug.RandomUniqueDeviceId")
    
    let index = AddressBookIndex(ready: nil)
    let provider = AddressBookContactsProvider(index: index)
    AliasDisplayManager.initialize(provider: provider)
    ContactsManager.initialize(provider: provider)
      
    MessageAPI.initialize(target: ServerTarget(scheme: .HTTPS, hostName: "master.dev.retxt.io"))
    
    let launchEnvironment = NSProcessInfo.processInfo().environment
    
    let dbName = launchEnvironment["testData"] ?? "test"
    let dbURL = NSBundle(forClass: AppDelegate.self).URLForResource(dbName, withExtension: "db")!

    switch launchEnvironment["testTarget"] ?? "chat" {
    case "chat":

      let cvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("Chat") as! TestChatController
      
      cvc.messageAPI = try! register()
      
      window?.rootViewController = UINavigationController(rootViewController: cvc)
      
      
    case "messages":
      
      let dbManager = try! DBManager(path: dbURL.path!, kind: "Messages", daoClasses: [MessageDAO.self, ChatDAO.self])

      let request = FetchRequest()
      request.resultClass = Message.self
      request.predicate = NSPredicate(value: true)
      request.includeSubentities = true
      request.sortDescriptors = [NSSortDescriptor(key: "sent", ascending: true)]
      request.fetchOffset = 0
      request.fetchLimit = 0
      request.fetchBatchSize = 0
      
      let messageResultsController = FetchedResultsController(DBManager: dbManager, request: request)
      
      try! messageResultsController.execute()
      
      let mvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("Messages") as! MessagesViewController
      mvc.messageResultsController = messageResultsController
      
      window?.rootViewController = UINavigationController(rootViewController: mvc)
      
    case "summaries":
      
      let dbManager = try! DBManager(path: dbURL.path!, kind: "Messages", daoClasses: [MessageDAO.self, ChatDAO.self])

      let request = FetchRequest()
      request.resultClass = Chat.self
      request.predicate = NSPredicate(value: true)
      request.includeSubentities = true
      request.sortDescriptors = []
      request.fetchOffset = 0
      request.fetchLimit = 0
      request.fetchBatchSize = 0
      
      let chatResultsController = FetchedResultsController(DBManager: dbManager, request: request)
      
      try! chatResultsController.execute()

      let csvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("RecentChats") as! ChatSummariesViewController
      csvc.chatResultsController = chatResultsController
      
      window?.rootViewController = UINavigationController(rootViewController: csvc)
      
    default:
      window?.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
    }

    window?.makeKeyAndVisible()

    return true
  }

  func register() throws -> MessageAPI {
  
    let alias = String(randomAlphaNumericOfLength: 8) + "@m.retxt.io"
    let password = String(randomAlphaNumericOfLength: 10)
    
    return try Promise<Void>()
      .then(on: GCD.backgroundQueue) {
        return MessageAPI.registerUserWithAliases([alias: "$#$#"], password: password)
      }
      .then(on: zalgo) { creds -> MessageAPI in
        
        DDLogError("##### Registered account: \(alias)")
        
        return try MessageAPI(credentials: creds, documentDirectoryURL: self.docDir)
      }
      .wait()
  }
  
}


class TestChatController : ChatController, ChatControllerDelegate {
  
  override func awakeFromNib() {
    delegate = self
  }
  
  func chatControllerRequestedPickContactOperation(chatController: ChatController) -> PickContactOperation {
    return PickAddressBookContactOperation(viewController: chatController)
  }
  
  func chatController(chatController: ChatController, wantsRecipientForContact contact: Contact) -> ChatRecipient? {
    
    //TODO: search for aliases already registered
    
    guard let contactAlias = contact.aliases.flatMap({ $0.kind == .Email ? $0 : nil }).first else {
      return nil
    }
    
    return ContactChatRecipient(contact: contact, alias: contactAlias.value)
  }
  
  func chatController(chatController: ChatController, wantsRecipientForProposedAlias proposedAlias: String) -> ChatRecipient? {
    
    //TODO: use libphonenumber to transform phone numbers into international format
    let alias = proposedAlias
    
    let chatRecipient : ChatRecipient
    
    if let contact = ContactsManager.sharedProvider.searchWithAliases([alias]).first {
      chatRecipient = ContactChatRecipient(contact: contact, alias: alias)
    }
    else {
      let aliasDisplay = AliasDisplayManager.sharedProvider.displayForAlias(alias)
      chatRecipient = AliasChatRecipient(alias: alias, title: aliasDisplay.fullName)
    }
    
    return chatRecipient
  }

}
