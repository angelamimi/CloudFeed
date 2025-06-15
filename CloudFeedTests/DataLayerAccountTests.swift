//
//  DataLayerAccountTests.swift
//  CloudFeedTests
//
//  Created by Angela Jarosz on 6/9/25.
//

@testable import CloudFeed
import Testing

struct DataLayerAccountTests {

    private var databaseManager: DatabaseManager
    
    init() async throws {
        databaseManager = DatabaseManager(modelContainer: DatabaseManager.test)
    }

    @Test func addAccount() async throws {
        
        await databaseManager.addAccount("user1 https://123.com", urlBase: "https://123.com", user: "user1", userId: "user1")
        
        let savedAccounts = await databaseManager.getAccountsOrdered()
        
        #expect(savedAccounts.count == 1)
    }
    
    @Test func setActiveAccount() async throws {
        
        let accountId = "user3 https://123.com"
        
        await databaseManager.addAccount("user1 https://123.com", urlBase: "https://123.com", user: "user1", userId: "user1")
        await databaseManager.addAccount("user2 https://123.com", urlBase: "https://123.com", user: "user2", userId: "user2")
        await databaseManager.addAccount(accountId, urlBase: "https://123.com", user: "user3", userId: "user3")
        await databaseManager.addAccount("user4 https://123.com", urlBase: "https://123.com", user: "user4", userId: "user4")
        
        let activeAccount = await databaseManager.setActiveAccount(accountId)
        
        #expect(activeAccount != nil)
        #expect(activeAccount?.account == accountId)
        #expect(activeAccount?.active ?? false)
        
        let ordered = await databaseManager.getAccountsOrdered()
        
        #expect(ordered.count == 4)
        #expect(ordered[0].account == accountId)
        #expect(ordered[0].active == true)
        #expect(ordered[1].active == false)
        #expect(ordered[2].active == false)
        #expect(ordered[3].active == false)
    }
    
    @Test func getActiveAccount() async throws {
        
        let accountId = "user1 https://123.com"
        
        await databaseManager.addAccount("user2 https://123.com", urlBase: "https://123.com", user: "user2", userId: "user2")
        await databaseManager.addAccount("user3 https://123.com", urlBase: "https://123.com", user: "user3", userId: "user3")
        await databaseManager.addAccount("user4 https://123.com", urlBase: "https://123.com", user: "user4", userId: "user4")
        await databaseManager.addAccount(accountId, urlBase: "https://123.com", user: "user1", userId: "user1")
        
        let activeAccount = await databaseManager.setActiveAccount(accountId)
        
        #expect(activeAccount != nil)
        
        let account = await databaseManager.getActiveAccount()
        
        #expect(account != nil)
        #expect(account?.account == accountId)
    }

    @Test func deleteAccount() async throws {
        
        let accountId = "user3 https://123.com"
        
        await databaseManager.addAccount("user1 https://123.com", urlBase: "https://123.com", user: "user1", userId: "user1")
        await databaseManager.addAccount("user2 https://123.com", urlBase: "https://123.com", user: "user2", userId: "user2")
        await databaseManager.addAccount(accountId, urlBase: "https://123.com", user: "user3", userId: "user3")
        await databaseManager.addAccount("user4 https://123.com", urlBase: "https://123.com", user: "user4", userId: "user4")
        
        await databaseManager.deleteAccount(accountId)
        
        let count = await databaseManager.getAccountCount()
        
        #expect(count == 3)
    }
    
    @Test func getAccountCount() async throws {
        
        var count = await databaseManager.getAccountCount()
        
        #expect(count == 0)
        
        await databaseManager.addAccount("user1 https://123.com", urlBase: "https://123.com", user: "user1", userId: "user1")
        await databaseManager.addAccount("user2 https://123.com", urlBase: "https://123.com", user: "user2", userId: "user2")
        
        count = await databaseManager.getAccountCount()
        
        #expect(count == 2)
        
        await databaseManager.addAccount("user3 https://123.com", urlBase: "https://123.com", user: "user3", userId: "user3")
        
        count = await databaseManager.getAccountCount()
        
        #expect(count == 3)
    }
    
    @Test func getAccountsOrdered() async throws {
        
        let activeAccountId = "user3 https://123.com"
        
        await databaseManager.addAccount("user1 https://123.com", urlBase: "https://123.com", user: "user1", userId: "user1")
        await databaseManager.addAccount("user2 https://123.com", urlBase: "https://123.com", user: "user2", userId: "user2")
        await databaseManager.addAccount(activeAccountId, urlBase: "https://123.com", user: "user3", userId: "user3")
        await databaseManager.addAccount("user4 https://123.com", urlBase: "https://123.com", user: "user4", userId: "user4")
        
        let activeAccount = await databaseManager.setActiveAccount(activeAccountId)
        
        #expect(activeAccount != nil)
        
        let ordered = await databaseManager.getAccountsOrdered()
        
        #expect(ordered.count == 4)
        #expect(ordered[0].active == true)
        #expect(ordered[1].active == false)
        #expect(ordered[2].active == false)
        #expect(ordered[3].active == false)
    }
    
    @Test func updateAccount() async throws {
        
        let accountId = "user1 https://123.com"
        let displayName = "User 1 Display Name"
        
        await databaseManager.addAccount(accountId, urlBase: "https://123.com", user: "user1", userId: "user1")
        
        await databaseManager.updateAccount(account: accountId, displayName: displayName)
        
        let accounts = await databaseManager.getAccountsOrdered()
        
        #expect(accounts.count == 1)
        #expect(accounts[0].displayName == displayName)
    }
}
