//
//  Websocket+WAMP.swift
//  Engine
//
//  Created by David Moeller on 10/10/2016.
//
//
// This Implementation is heavily inspired by https://github.com/iscriptology/swamp and obviously the WAMP-Protocol itself:
// https://tools.ietf.org/html/draft-oberstet-hybi-tavendo-wamp-02

import Foundation
import Jay
import Core

protocol WAMP {
	
	/// A combined connect method where: 1. the Websocket will establish a client connection and 2. the WAMP Protocol will send a Hello Message to the demanded realm
	
	static func connectWithWAMP(to uri: String, with realm: String, with role: WAMPRole.WAMPClientRole, with completionHandler: @escaping (Result<WebSocket>) -> Void, with errorHandler: @escaping (Error) -> Void)
	static func connectWithWAMP(with webSocket: WebSocket, with completionHandler: @escaping (Result<WebSocket>) -> Void)
	
	func send(wampMessage: WAMPMessage) throws
	func handle(text: String) throws
	func handle(wampMessage: WAMPMessage) throws
	
	func subscribe(topic: String, options: [String: Any], with eventHandler: @escaping (_ details: [String: Any], _ results: [Any]?, _ kwResults: [String: Any]?) -> Void) throws
	func disconnectWAMP() throws
	
}

enum WAMPError: Error {
	case roleNotAllowed
	case wrongSubProtocol
	case errorMessage(message: String)
}

enum WAMPRole {
	
	enum WAMPClientRole: String {
		// Client roles
		case caller = "caller"
		case callee = "callee"
		case subscriber = "subscriber"
		case publisher = "publisher"
		
		static func implemented() -> [WAMPClientRole] {
			return [.subscriber]
		}
	}
	
	enum WAMPRouterRole: String {
		// Route roles
		case broker = "broker"
		case dealer = "dealer"
		
		static func implemented() -> [WAMPRouterRole] {
			return [WAMPRouterRole]()
		}
	}

	case router(role: WAMPRouterRole)
	case client(role: WAMPClientRole)
	
	static func implemented() -> [WAMPRole] {
		
		var roles = [WAMPRole]()
		
		for clientRole in WAMPClientRole.implemented() {
			roles.append(.client(role: clientRole))
		}
		
		for routerRole in WAMPRouterRole.implemented() {
			roles.append(.router(role: routerRole))
		}
		
		return roles
		
	}
	
	static func isAllowed(role: WAMPRole) -> Bool {

		switch role {
		case .client(role: let clientRole):
			return WAMPRole.WAMPClientRole.implemented().contains(clientRole)
		case .router(role: let routerRole):
			return WAMPRole.WAMPRouterRole.implemented().contains(routerRole)
		}

	}
	
	func string() -> String {
		
		switch self {
		case .client(role: let clientRole):
			return clientRole.rawValue
		case .router(role: let routerRole):
			return routerRole.rawValue
		}
		
	}
}

class WAMPSession {
	
	// WAMP Properties
	
	let realm: String
	let authmethods: [String]?
	let authid: String?
	let authrole: String?
	let authextra: [String: Any]?
	let clientName: String = "Vapor 1.0"
	let role: WAMPRole
	
	var errorHandler: ((Error) -> Void)? = nil
	
	// Requests
	
	private var numberOfRequests: Int = 0
	
	var subscriptions = [Int: (details: [String: Any], results: [Any]?, kwResults: [String: Any]?) -> Void]()
	
	// Connection
	private var sessionID: Int?
	
	init(realm: String, sessionID: Int? = nil, authmethods: [String]? = nil, authid: String? = nil, authrole: String? = nil, authextra: [String: Any]? = nil, role: WAMPRole, errorHandler: ((Error) -> Void)? = nil) {
		self.realm = realm
		self.sessionID = sessionID
		self.authmethods = authmethods
		self.authid = authid
		self.authrole = authrole
		self.authextra = authextra
		self.role = role
		self.errorHandler = errorHandler
	}
	
	public func isConnected() -> Bool {
		return self.sessionID != nil
	}
	
	static func createMessage(json: [Any]) throws -> WAMPMessage {
		
		guard let typePayload = json[0] as? Int else { throw WAMPMessageError.wrongPayloadType }
			
		guard let messageType = WAMPMessageType(rawValue: typePayload) else { throw WAMPMessageError.wrongMessageType(payload: typePayload) }
		
		let messagePayload = Array(json[1..<json.count])
		
		switch messageType {
		case .error:
			return try ErrorMessage(payload: messagePayload)
		case .welcome:
			return try WelcomeMessage(payload: messagePayload)
		case .hello:
			return try HelloMessage(payload: messagePayload)
		case .goodbye:
			return try GoodbyeMessage(payload: messagePayload)
		case .subscribe:
			return try SubscribeMessage(payload: messagePayload)
		case .subscribed:
			return try SubscribedMessage(payload: messagePayload)
		case .unsubscribe:
			return try UnsubscribeMessage(payload: messagePayload)
		case .unsubscribed:
			return try UnsubscribedMessage(payload: messagePayload)
		case .event:
			return try EventMessage(payload: messagePayload)
		default:
			throw WAMPMessageError.messageTypeNotImplemented(type: messageType)
		}
		
	}
	
	func generateRequestNumber() -> Int {
		self.numberOfRequests += 1
		return self.numberOfRequests
	}
	
}

extension WebSocket: WAMP {
	
	/// A combined connect method where: 1. the Websocket will establish a client connection and 2. the WAMP Protocol will send a Hello Message to the demanded realm
	internal static func connectWithWAMP(to uri: String, with realm: String, with role: WAMPRole.WAMPClientRole, with completionHandler: @escaping (Result<WebSocket>) -> Void, with errorHandler: @escaping (Swift.Error) -> Void) {
		
		do {
			try WebSocket.connect(to: uri, onConnect: { webSocket in
				
				// Initialize Session
				let session = WAMPSession(realm: realm, role: WAMPRole.client(role: role), errorHandler: errorHandler)
				
				webSocket.subProtocol = .wamp(session: session)
				
				WebSocket.connectWithWAMP(with: webSocket, with: completionHandler)
			})
		} catch {
			completionHandler(.failure(error))
		}
		
	}
	
	static func connectWithWAMP(with webSocket: WebSocket, with completionHandler: @escaping (Result<WebSocket>) -> Void) {
		
		// Check that the Websocket has the correct Subprotocol
		
		guard let session = webSocket.wampSession() else { completionHandler(.failure(WAMPError.wrongSubProtocol)); return }
		
		// Check if Role is available
		
		guard WAMPRole.isAllowed(role: session.role) else { completionHandler(.failure(WAMPError.roleNotAllowed)); return }
		
		// Send Welcome Message
		
		var details: [String: Any] = [:]
		
		if let authmethods = session.authmethods {
			details["authmethods"] = authmethods
		}
		if let authid = session.authid {
			details["authid"] = authid
		}
		if let authrole = session.authrole {
			details["authrole"] = authrole
		}
		if let authextra = session.authextra {
			details["authextra"] = authextra
		}
		
		details["agent"] = session.clientName
		details["roles"] = [session.role.string(): [String: Any]()]

		let message = HelloMessage(realm: session.realm, details: details)
		do {
			try webSocket.send(wampMessage: message)
			
			webSocket.onText = { ws, text in
				do {
					try ws.handle(text: text)
				} catch {
					completionHandler(.failure(error))
				}
			}
			
			completionHandler(.success(webSocket))
			return
		} catch {
			completionHandler(.failure(error))
			return
		}
		
	}
	
	public func send(wampMessage: WAMPMessage) throws {
		
		// Check that the Websocket has the correct Subprotocol
		
		guard let _ = self.wampSession() else { throw WAMPError.wrongSubProtocol }
		
		let marshalledMessage = wampMessage.marshal()
		let data = try Jay(formatting: .minified).dataFromJson(any: marshalledMessage)
		try self.send(data)
		
	}
	
	internal func handle(text: String) throws {
		
		guard let _ = self.wampSession() else { throw WAMPError.wrongSubProtocol }
		
		guard let json = try Jay().anyJsonFromData(Array(text.utf8)) as? [Any] else { throw WAMPMessageError.noPayloadArrayFound }
		
		let message = try WAMPSession.createMessage(json: json)
		
		try self.handle(wampMessage: message)
		
	}
	
	internal func handle(wampMessage: WAMPMessage) throws {
		
		guard let session = self.wampSession() else { throw WAMPError.wrongSubProtocol }
		
		switch wampMessage {
		case let message as ErrorMessage:
			session.errorHandler?(WAMPError.errorMessage(message: message.error))
		default:
			return
		}
		
	}
	
	func disconnectWAMP() throws {
		
		guard let _ = self.wampSession() else { throw WAMPError.wrongSubProtocol }
		
		return
	}
	
	func subscribe(topic: String, options: [String: Any] = [:], with eventHandler: @escaping (_ details: [String: Any], _ results: [Any]?, _ kwResults: [String: Any]?) -> Void) throws {
		
		guard let session = self.wampSession() else { throw WAMPError.wrongSubProtocol }
		
		let requestID = session.generateRequestNumber()
		
		let subscribeMessage = SubscribeMessage(requestId: requestID, options: options, topic: topic)
		
		session.subscriptions[requestID] = eventHandler
		
		try send(wampMessage: subscribeMessage)
	}
	
	/// Return a WAMPSession if the Websocket uses the correct Subprotocol. Return nil if not.
	
	private func wampSession() -> WAMPSession? {
		
		switch self.subProtocol {
		case .wamp(session: let session):
			return session
		default:
			return nil
		}
	}
	
}
